const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

const GIFT_REDEEM_USER_COOLDOWN_MS = 10 * 1000;
const GIFT_REDEEM_USER_DAILY_LIMIT = 25;
const GIFT_REDEEM_DEVICE_COOLDOWN_MS = 8 * 1000;
const GIFT_REDEEM_DEVICE_DAILY_LIMIT = 40;
const GIFT_REDEEM_IP_COOLDOWN_MS = 3 * 1000;
const GIFT_REDEEM_IP_DAILY_LIMIT = 120;
const GIFT_BRUTE_FORCE_WINDOW_MS = 15 * 60 * 1000;
const GIFT_BRUTE_FORCE_USER_THRESHOLD = 6;
const GIFT_BRUTE_FORCE_DEVICE_THRESHOLD = 8;
const GIFT_BRUTE_FORCE_IP_THRESHOLD = 12;
const GIFT_BRUTE_FORCE_BLOCK_MS = 6 * 60 * 60 * 1000;
const GIFT_ALERT_COOLDOWN_MS = 60 * 60 * 1000;
const GIFT_MAX_DAYS = 3650;
const GIFT_MAX_USES = 100000;
const GIFT_CODE_PATTERN = /^[A-Z0-9_-]{4,32}$/;

function asObject(value) {
  return value && typeof value === 'object' ? value : {};
}

function normalizeText(value) {
  return String(value ?? '').trim();
}

function normalizeEmail(value) {
  return normalizeText(value).toLowerCase().slice(0, 200);
}

function toTimestamp(value) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? Math.trunc(normalized) : 0;
}

function dayKey(nowMs) {
  return new Date(nowMs).toISOString().slice(0, 10);
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value ?? '')).digest('hex');
}

function sanitizeKey(value) {
  return normalizeText(value).replace(/[.#$/\[\]]/g, '_').slice(0, 120);
}

function normalizeDeviceId(value) {
  return normalizeText(value)
    .replace(/[.#$/\[\]\s]/g, '_')
    .replace(/[^A-Za-z0-9_:-]/g, '')
    .slice(0, 128);
}

function isValidGiftcodeFormat(value) {
  return GIFT_CODE_PATTERN.test(normalizeText(value));
}

function getRequestIpFromContext(context) {
  const req = context?.rawRequest;
  const forwarded = normalizeText(req?.headers?.['x-forwarded-for']);
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }

  return normalizeText(
    req?.ip ||
      req?.connection?.remoteAddress ||
      req?.socket?.remoteAddress ||
      req?.headers?.['fastly-client-ip'],
  );
}

function resolveRequestMeta(context, data) {
  const ip = getRequestIpFromContext(context);
  const appId = normalizeText(context?.app?.appId).slice(0, 120);
  const userAgent = normalizeText(context?.rawRequest?.headers?.['user-agent']).slice(0, 300);
  const instanceIdToken = normalizeText(context?.instanceIdToken);
  let deviceId = normalizeDeviceId(data?.deviceId || data?.device_id);

  if (!deviceId && instanceIdToken) {
    deviceId = `iid_${sha256(`iid:${instanceIdToken}`).slice(0, 40)}`;
  }

  if (!deviceId && (appId || userAgent)) {
    deviceId = `fp_${sha256(`fp:${appId}|${userAgent}`).slice(0, 40)}`;
  }

  if (!deviceId) {
    deviceId = 'unknown_device';
  }

  return {
    ip,
    ipKey: ip ? sha256(`giftcode_ip:${ip}`) : '',
    deviceId,
    deviceKey: sha256(`giftcode_device:${deviceId}`),
    appId,
    userAgent,
  };
}

function isHouseMember(houseData, uid) {
  const members = asObject(houseData.members);
  return normalizeText(houseData.owner_uid) === uid || members[uid] != null;
}

async function resolveHouseIdForUser(uid, requestedHouseId) {
  const requested = normalizeText(requestedHouseId);
  const db = admin.database();
  const userSnap = await db.ref(`users/${uid}`).once('value');
  const userData = asObject(userSnap.val());
  const storedHouseId = normalizeText(userData.houseId || userData.house_id);

  if (requested && storedHouseId && requested !== storedHouseId) {
    throw new Error('house_mismatch');
  }

  return requested || storedHouseId;
}

async function resolveMemberHouse(uid, requestedHouseId) {
  const houseId = await resolveHouseIdForUser(uid, requestedHouseId);
  if (!houseId) {
    throw new Error('house_not_found');
  }

  const db = admin.database();
  const houseSnap = await db.ref(`houses/${houseId}`).once('value');
  if (!houseSnap.exists()) {
    throw new Error('house_not_found');
  }

  const houseData = asObject(houseSnap.val());
  if (!isHouseMember(houseData, uid)) {
    throw new Error('forbidden');
  }

  return { houseId, houseData };
}

function isAdminToken(token) {
  return (
    token.admin === true ||
    token.admin === 'true' ||
    token.admin_role === 'super_admin' ||
    token.admin_role === 'admin' ||
    token.role === 'admin'
  );
}

async function isAdminUid(uid) {
  const db = admin.database();
  const [adminSnap, adminListSnap] = await Promise.all([
    db.ref(`admins/${uid}`).once('value'),
    db.ref(`admins_list/${uid}`).once('value'),
  ]);

  return adminSnap.exists() || adminListSnap.exists();
}

async function ensureAdminContext(context) {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Đăng nhập admin để thực hiện thao tác này.',
    );
  }

  const uid = context.auth.uid;
  const token = asObject(context.auth.token);
  if (!isAdminToken(token) && !(await isAdminUid(uid))) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Bạn không có quyền quản trị giftcode.',
    );
  }

  return {
    uid,
    email: normalizeEmail(token.email),
  };
}

function resolveGiftcodeDays(record) {
  const rewardType = normalizeText(
    record.rewardType || record.type || (record.days != null ? 'vip' : ''),
  ).toLowerCase();
  if (rewardType && rewardType !== 'vip') {
    throw new Error('unsupported_reward_type');
  }

  const rawDays = record.rewardValue ?? record.days ?? record.value;
  const days = Math.trunc(Number(rawDays));
  if (days <= 0 || days > GIFT_MAX_DAYS) {
    throw new Error('invalid_reward_value');
  }

  return days;
}

function resolveGiftcodeLimit(record) {
  const maxUses = Math.trunc(Number(record.maxUses ?? record.limit ?? 0));
  if (maxUses <= 0) {
    return 0;
  }

  return Math.min(maxUses, GIFT_MAX_USES);
}

function resolveGiftcodeUsedCount(record) {
  return Math.max(
    0,
    Math.trunc(Number(record.usedCount ?? record.used ?? 0)),
  );
}

function isGiftcodeActive(record, nowMs) {
  if (record.active === false || record.enabled === false) {
    return false;
  }

  const expiresAt = toTimestamp(record.expiresAt ?? record.expires_at);
  if (expiresAt > 0 && nowMs > expiresAt) {
    return false;
  }

  return true;
}

async function registerScopeAttempt({ path, now, cooldownMs, dailyLimit }) {
  const db = admin.database();
  const attemptRef = db.ref(path);
  const today = dayKey(now);
  let abortReason = '';

  const txn = await attemptRef.transaction((rawState) => {
    const state = asObject(rawState);
    const blockedUntil = toTimestamp(state.blockedUntil);
    if (blockedUntil > now) {
      abortReason = 'giftcode_temporarily_blocked';
      return;
    }

    const sameDay = normalizeText(state.day) === today;
    const lastAttemptAt = sameDay ? toTimestamp(state.lastAttemptAt) : 0;
    const attemptsToday = sameDay
      ? Math.max(0, Math.trunc(Number(state.attemptsToday) || 0))
      : 0;

    if (cooldownMs > 0 && lastAttemptAt > 0 && now - lastAttemptAt < cooldownMs) {
      abortReason = 'rate_limited';
      return;
    }

    if (dailyLimit > 0 && attemptsToday >= dailyLimit) {
      abortReason = 'daily_limit_reached';
      return;
    }

    abortReason = '';
    return {
      ...state,
      day: today,
      attemptsToday: attemptsToday + 1,
      lastAttemptAt: now,
      updatedAt: now,
    };
  });

  if (!txn.committed) {
    throw new Error(abortReason || 'rate_limited');
  }
}

async function registerRedeemAttempt({ uid, requestMeta }) {
  const now = Date.now();
  await registerScopeAttempt({
    path: `giftcode_redeem_state/users/${uid}`,
    now,
    cooldownMs: GIFT_REDEEM_USER_COOLDOWN_MS,
    dailyLimit: GIFT_REDEEM_USER_DAILY_LIMIT,
  });
  await registerScopeAttempt({
    path: `giftcode_redeem_state/devices/${requestMeta.deviceKey}`,
    now,
    cooldownMs: GIFT_REDEEM_DEVICE_COOLDOWN_MS,
    dailyLimit: GIFT_REDEEM_DEVICE_DAILY_LIMIT,
  });
  if (requestMeta.ipKey) {
    await registerScopeAttempt({
      path: `giftcode_redeem_state/ip/${requestMeta.ipKey}`,
      now,
      cooldownMs: GIFT_REDEEM_IP_COOLDOWN_MS,
      dailyLimit: GIFT_REDEEM_IP_DAILY_LIMIT,
    });
  }
}

async function registerFailureWindow({ path, now, threshold }) {
  const db = admin.database();
  const failureRef = db.ref(path);
  const txn = await failureRef.transaction((rawState) => {
    const state = asObject(rawState);
    const windowStartedAt = toTimestamp(state.windowStartedAt);
    const withinWindow =
      windowStartedAt > 0 && now - windowStartedAt < GIFT_BRUTE_FORCE_WINDOW_MS;
    const attempts = withinWindow
      ? Math.max(0, Math.trunc(Number(state.attempts) || 0)) + 1
      : 1;
    const currentBlockedUntil = toTimestamp(state.blockedUntil);
    const nextBlockedUntil =
      attempts >= threshold
        ? Math.max(currentBlockedUntil, now + GIFT_BRUTE_FORCE_BLOCK_MS)
        : currentBlockedUntil;

    return {
      ...state,
      windowStartedAt: withinWindow ? windowStartedAt : now,
      attempts,
      lastAttemptAt: now,
      blockedUntil: nextBlockedUntil,
      updatedAt: now,
    };
  });

  const state = asObject(txn.snapshot.val());
  return {
    attempts: Math.max(0, Math.trunc(Number(state.attempts) || 0)),
    blockedUntil: toTimestamp(state.blockedUntil),
  };
}

async function emitBruteForceAlert({
  scopeKey,
  scopeType,
  threshold,
  attempts,
  blockedUntil,
  reason,
  uid,
  houseId,
  code,
  requestMeta,
}) {
  const db = admin.database();
  const now = Date.now();
  const alertStateRef = db.ref(`giftcode_security/alert_state/${scopeKey}`);
  const alertTxn = await alertStateRef.transaction((rawState) => {
    const state = asObject(rawState);
    const lastAlertAt = toTimestamp(state.lastAlertAt);
    if (lastAlertAt > 0 && now - lastAlertAt < GIFT_ALERT_COOLDOWN_MS) {
      return;
    }

    return {
      lastAlertAt: now,
      threshold,
      attempts,
      blockedUntil,
      updatedAt: now,
    };
  });

  if (!alertTxn.committed) {
    return;
  }

  const securityRef = db.ref('admin_system/security_alerts').push();
  const auditRef = db.ref('admin_system/audit_log').push();
  const alertPayload = {
    ts: admin.database.ServerValue.TIMESTAMP,
    type: 'giftcode_bruteforce_detected',
    level: 'high',
    detail: `Giftcode brute force nghi van o ${scopeType}. Ly do: ${reason}.`,
    uid,
    houseId: houseId || null,
    code: code || null,
    scopeType,
    attempts,
    threshold,
    blockedUntil,
    ip: requestMeta.ip || null,
    deviceId: requestMeta.deviceId || null,
    appId: requestMeta.appId || null,
    userAgent: requestMeta.userAgent || null,
  };

  await db.ref().update({
    [`admin_system/security_alerts/${securityRef.key}`]: alertPayload,
    [`admin_system/audit_log/${auditRef.key}`]: {
      ts: admin.database.ServerValue.TIMESTAMP,
      action: 'giftcode_bruteforce_detected',
      type: 'security',
      detail: `${scopeType}:${attempts}/${threshold}`,
      msg: `Giftcode brute force suspected for uid ${uid || 'unknown'}`,
      uid,
      houseId: houseId || null,
    },
  });
}

async function recordBruteForceSignal({
  uid,
  houseId,
  code,
  reason,
  requestMeta,
}) {
  const now = Date.now();
  const scopes = [
    {
      path: `giftcode_security/failures/users/${uid}`,
      scopeType: 'user',
      scopeKey: `user_${uid}`,
      threshold: GIFT_BRUTE_FORCE_USER_THRESHOLD,
    },
    {
      path: `giftcode_security/failures/devices/${requestMeta.deviceKey}`,
      scopeType: 'device',
      scopeKey: `device_${requestMeta.deviceKey}`,
      threshold: GIFT_BRUTE_FORCE_DEVICE_THRESHOLD,
    },
  ];

  if (requestMeta.ipKey) {
    scopes.push({
      path: `giftcode_security/failures/ip/${requestMeta.ipKey}`,
      scopeType: 'ip',
      scopeKey: `ip_${requestMeta.ipKey}`,
      threshold: GIFT_BRUTE_FORCE_IP_THRESHOLD,
    });
  }

  for (const scope of scopes) {
    const result = await registerFailureWindow({
      path: scope.path,
      now,
      threshold: scope.threshold,
    });

    if (result.attempts >= scope.threshold) {
      await emitBruteForceAlert({
        ...scope,
        attempts: result.attempts,
        blockedUntil: result.blockedUntil,
        reason,
        uid,
        houseId,
        code,
        requestMeta,
      });
    }
  }
}

function shouldTrackGiftcodeFailure(reason) {
  return (
    reason === 'giftcode_not_found' ||
    reason === 'giftcode_inactive' ||
    reason === 'invalid_code_format'
  );
}

function mapRedeemError(error) {
  const code = normalizeText(error?.message);
  switch (code) {
    case 'invalid_code_format':
      return new functions.https.HttpsError(
        'invalid-argument',
        'Mã giftcode chỉ được gồm 4-32 ký tự A-Z, 0-9, gạch ngang hoặc gạch dưới.',
      );
    case 'house_not_found':
      return new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy nhà liên kết để nhận giftcode.',
      );
    case 'house_mismatch':
    case 'forbidden':
      return new functions.https.HttpsError(
        'permission-denied',
        'Bạn không có quyền sử dụng giftcode cho nhà này.',
      );
    case 'giftcode_not_found':
    case 'giftcode_inactive':
      return new functions.https.HttpsError(
        'not-found',
        'Mã giftcode không hợp lệ hoặc đã hết hạn.',
      );
    case 'giftcode_already_used':
      return new functions.https.HttpsError(
        'already-exists',
        'Nhà của bạn đã dùng mã giftcode này rồi.',
      );
    case 'giftcode_limit_reached':
      return new functions.https.HttpsError(
        'resource-exhausted',
        'Mã giftcode này đã hết lượt sử dụng.',
      );
    case 'unsupported_reward_type':
      return new functions.https.HttpsError(
        'failed-precondition',
        'Giftcode này chưa được cấu hình cho phần thưởng PRO trên app.',
      );
    case 'invalid_reward_value':
      return new functions.https.HttpsError(
        'failed-precondition',
        'Giftcode chưa được cấu hình số ngày PRO hợp lệ.',
      );
    case 'giftcode_temporarily_blocked':
      return new functions.https.HttpsError(
        'resource-exhausted',
        'Hệ thống tạm khóa việc nhập giftcode vì phát hiện thao tác bất thường. Vui lòng thử lại sau.',
      );
    case 'rate_limited':
      return new functions.https.HttpsError(
        'resource-exhausted',
        'Bạn thao tác quá nhanh. Vui lòng đợi một chút rồi thử lại.',
      );
    case 'daily_limit_reached':
      return new functions.https.HttpsError(
        'resource-exhausted',
        'Bạn đã thử quá nhiều giftcode trong hôm nay. Vui lòng thử lại vào ngày mai.',
      );
    default:
      return new functions.https.HttpsError(
        'internal',
        'Không thể áp dụng giftcode lúc này.',
      );
  }
}

function mapAdminGiftcodeError(error) {
  const code = normalizeText(error?.message);
  switch (code) {
    case 'invalid_code_format':
      return new functions.https.HttpsError(
        'invalid-argument',
        'Mã giftcode chỉ được gồm 4-32 ký tự A-Z, 0-9, gạch ngang hoặc gạch dưới.',
      );
    case 'invalid_reward_value':
      return new functions.https.HttpsError(
        'invalid-argument',
        `Số ngày PRO phải từ 1 đến ${GIFT_MAX_DAYS}.`,
      );
    case 'invalid_max_uses':
      return new functions.https.HttpsError(
        'invalid-argument',
        `Số lượt dùng tối đa phải từ 1 đến ${GIFT_MAX_USES}.`,
      );
    case 'invalid_expires_at':
      return new functions.https.HttpsError(
        'invalid-argument',
        'Ngày hết hạn không hợp lệ.',
      );
    case 'giftcode_exists':
      return new functions.https.HttpsError(
        'already-exists',
        'Giftcode này đã tồn tại.',
      );
    case 'giftcode_not_found':
      return new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy giftcode cần thao tác.',
      );
    default:
      return new functions.https.HttpsError(
        'internal',
        'Không thể xử lý giftcode lúc này.',
      );
  }
}

function buildGiftcodeRecord({
  code,
  rewardValue,
  maxUses,
  expiresAt,
  actorUid,
  actorEmail,
  now,
}) {
  const days = Math.trunc(Number(rewardValue));
  if (!Number.isFinite(days) || days < 1 || days > GIFT_MAX_DAYS) {
    throw new Error('invalid_reward_value');
  }

  const normalizedMaxUses = Math.trunc(Number(maxUses));
  if (
    !Number.isFinite(normalizedMaxUses) ||
    normalizedMaxUses < 1 ||
    normalizedMaxUses > GIFT_MAX_USES
  ) {
    throw new Error('invalid_max_uses');
  }

  const normalizedExpiresAt =
    expiresAt == null || expiresAt === ''
      ? null
      : Math.trunc(Number(expiresAt));
  if (
    normalizedExpiresAt != null &&
    (!Number.isFinite(normalizedExpiresAt) || normalizedExpiresAt <= 0)
  ) {
    throw new Error('invalid_expires_at');
  }

  return {
    rewardType: 'vip',
    rewardValue: days,
    maxUses: normalizedMaxUses,
    usedCount: 0,
    used: 0,
    expiresAt: normalizedExpiresAt,
    created_at: now,
    createdBy: actorEmail || 'admin',
    createdByUid: actorUid,
    active: true,
    code,
  };
}

exports.redeemGiftcode = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để sử dụng giftcode.',
      );
    }

    const uid = context.auth.uid;
    const code = normalizeText(data?.code).toUpperCase();
    const requestMeta = resolveRequestMeta(context, data);

    if (!code) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Vui lòng nhập giftcode.',
      );
    }

    try {
      if (!isValidGiftcodeFormat(code)) {
        try {
          await recordBruteForceSignal({
            uid,
            houseId: normalizeText(data?.houseId),
            code,
            reason: 'invalid_code_format',
            requestMeta,
          });
        } catch (signalError) {
          console.error('giftcode invalid format signal error:', signalError);
        }
        throw new Error('invalid_code_format');
      }

      await registerRedeemAttempt({ uid, requestMeta });
      const { houseId } = await resolveMemberHouse(uid, data?.houseId);
      const db = admin.database();
      const now = Date.now();
      const codeRef = db.ref(`admin_system/giftcodes/${code}`);
      const houseMarkerKey = sanitizeKey(houseId);
      let abortReason = '';
      let daysAdded = 0;

      const codeTxn = await codeRef.transaction((current) => {
        if (!current) {
          abortReason = 'giftcode_not_found';
          return;
        }

        const record = asObject(current);
        if (!isGiftcodeActive(record, now)) {
          abortReason = 'giftcode_inactive';
          return;
        }

        try {
          daysAdded = resolveGiftcodeDays(record);
        } catch (error) {
          abortReason = normalizeText(error?.message) || 'invalid_reward_value';
          return;
        }

        const redeemedHouses = {
          ...asObject(record.redeemedHouses),
        };
        if (redeemedHouses[houseMarkerKey]) {
          abortReason = 'giftcode_already_used';
          return;
        }

        const maxUses = resolveGiftcodeLimit(record);
        const usedCount = resolveGiftcodeUsedCount(record);
        if (maxUses > 0 && usedCount >= maxUses) {
          abortReason = 'giftcode_limit_reached';
          return;
        }

        redeemedHouses[houseMarkerKey] = now;
        return {
          ...record,
          usedCount: usedCount + 1,
          used: usedCount + 1,
          lastRedeemedAt: now,
          lastRedeemedByUid: uid,
          lastRedeemedByDevice: requestMeta.deviceId,
          redeemedHouses,
        };
      });

      if (!codeTxn.committed) {
        throw new Error(abortReason || 'giftcode_not_found');
      }

      const proRef = db.ref(`houses/${houseId}/proUntil`);
      let newProUntil = 0;

      try {
        const proTxn = await proRef.transaction((current) => {
          const currentProUntil = Math.max(0, Math.trunc(Number(current) || 0));
          const base = currentProUntil > now ? currentProUntil : now;
          newProUntil = base + daysAdded * 24 * 60 * 60 * 1000;
          return newProUntil;
        });

        if (!proTxn.committed) {
          throw new Error('pro_transaction_failed');
        }

        newProUntil = Math.trunc(Number(proTxn.snapshot.val()) || newProUntil);
        const notificationRef = db.ref(`notifications/${houseId}`).push();
        const rewardRef = db.ref(`reward_history/${uid}`).push();
        await db.ref().update({
          [`houses/${houseId}/vip`]: {
            isVip: true,
            plan: 'giftcode',
            vipExpiresAt: newProUntil,
            updatedAt: admin.database.ServerValue.TIMESTAMP,
            updatedBy: uid,
            code,
          },
          [`houses/${houseId}/used_giftcodes/${code}`]: now,
          [`house_profiles/${houseId}/proUntil`]: newProUntil,
          [`houses_public/${houseId}/proUntil`]: newProUntil,
          [`notifications/${houseId}/${notificationRef.key}`]: {
            type: 'system',
            from: 'Hệ thống',
            title: 'Giftcode thành công',
            msg: `Giftcode ${code} đã được áp dụng thành công.`,
            ts: admin.database.ServerValue.TIMESTAMP,
            immutable: true,
            systemLocked: true,
            source: 'redeem_giftcode',
          },
          [`reward_history/${uid}/${rewardRef.key}`]: {
            type: 'giftcode',
            code,
            houseId,
            daysAdded,
            proUntil: newProUntil,
            deviceId: requestMeta.deviceId,
            ts: admin.database.ServerValue.TIMESTAMP,
          },
        });
      } catch (error) {
        await codeRef.transaction((current) => {
          if (!current) {
            return current;
          }

          const record = asObject(current);
          const redeemedHouses = {
            ...asObject(record.redeemedHouses),
          };

          if (!redeemedHouses[houseMarkerKey]) {
            return current;
          }

          delete redeemedHouses[houseMarkerKey];
          const usedCount = Math.max(0, resolveGiftcodeUsedCount(record) - 1);
          return {
            ...record,
            usedCount,
            used: usedCount,
            redeemedHouses,
          };
        });
        throw error;
      }

      return {
        success: true,
        houseId,
        code,
        daysAdded,
        proUntil: newProUntil,
        message: `Giftcode hợp lệ. Bạn nhận được ${daysAdded} ngày PRO.`,
      };
    } catch (error) {
      const reason = normalizeText(error?.message);
      if (shouldTrackGiftcodeFailure(reason)) {
        try {
          await recordBruteForceSignal({
            uid,
            houseId: normalizeText(data?.houseId),
            code,
            reason,
            requestMeta,
          });
        } catch (signalError) {
          console.error('giftcode brute force signal error:', signalError);
        }
      }
      throw mapRedeemError(error);
    }
  });

exports.adminListGiftcodes = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (_data, context) => {
  await ensureAdminContext(context);

  const db = admin.database();
  const snap = await db.ref('admin_system/giftcodes').once('value');
  const data = asObject(snap.val());
  const list = Object.keys(data).map((code) => ({
    ...asObject(data[code]),
    code,
  }));

  list.sort((a, b) => toTimestamp(b.created_at) - toTimestamp(a.created_at));
  return {
    codes: list,
  };
});

exports.adminCreateGiftcode = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
  const actor = await ensureAdminContext(context);

  try {
    const code = normalizeText(data?.code).toUpperCase();
    if (!isValidGiftcodeFormat(code)) {
      throw new Error('invalid_code_format');
    }

    const record = buildGiftcodeRecord({
      code,
      rewardValue: data?.rewardValue,
      maxUses: data?.maxUses,
      expiresAt: data?.expiresAt,
      actorUid: actor.uid,
      actorEmail: actor.email,
      now: Date.now(),
    });

    const db = admin.database();
    const codeRef = db.ref(`admin_system/giftcodes/${code}`);
    const txn = await codeRef.transaction((current) => {
      if (current) {
        return;
      }
      return record;
    });

    if (!txn.committed) {
      throw new Error('giftcode_exists');
    }

    const auditRef = db.ref('admin_system/audit_log').push();
    await auditRef.set({
      ts: admin.database.ServerValue.TIMESTAMP,
      action: 'create_giftcode',
      type: 'giftcode',
      detail: code,
      msg: `Admin tao giftcode ${code}`,
      uid: actor.uid,
      actorUid: actor.uid,
      actorEmail: actor.email || null,
    });

    return {
      success: true,
      code,
      message: 'Đã tạo giftcode thành công.',
    };
  } catch (error) {
    throw mapAdminGiftcodeError(error);
  }
});

exports.adminDeleteGiftcode = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
  const actor = await ensureAdminContext(context);

  try {
    const code = normalizeText(data?.code).toUpperCase();
    if (!isValidGiftcodeFormat(code)) {
      throw new Error('invalid_code_format');
    }

    const db = admin.database();
    const codeRef = db.ref(`admin_system/giftcodes/${code}`);
    const snap = await codeRef.once('value');
    if (!snap.exists()) {
      throw new Error('giftcode_not_found');
    }

    await codeRef.remove();
    const auditRef = db.ref('admin_system/audit_log').push();
    await auditRef.set({
      ts: admin.database.ServerValue.TIMESTAMP,
      action: 'delete_giftcode',
      type: 'giftcode',
      detail: code,
      msg: `Admin xoa giftcode ${code}`,
      uid: actor.uid,
      actorUid: actor.uid,
      actorEmail: actor.email || null,
    });

    return {
      success: true,
      code,
      message: 'Đã xóa giftcode.',
    };
  } catch (error) {
    throw mapAdminGiftcodeError(error);
  }
});
