const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { google } = require('googleapis');
const sharp = require('sharp');
const otpModule = require('./otp');

const PRO_REWARD_PLANS = new Map([
  ['pro_12h', { pointsCost: 300, durationMs: 12 * 60 * 60 * 1000 }],
  ['pro_1d', { pointsCost: 500, durationMs: 24 * 60 * 60 * 1000 }],
  ['pro_3d', { pointsCost: 1000, durationMs: 3 * 24 * 60 * 60 * 1000 }],
  ['pro_7d', { pointsCost: 2000, durationMs: 7 * 24 * 60 * 60 * 1000 }],
  ['pro_30d', { pointsCost: 5000, durationMs: 30 * 24 * 60 * 60 * 1000 }],
]);
const PLAY_PACKAGE_NAME = 'com.soullocket.app';
const LIFETIME_VIP_EXPIRY_MS = 4102444800000;
const VIP_SUBSCRIPTION_IDS = new Set([
  'soullocket_vip_weekly',
  'soullocket_vip_monthly',
  'soullocket_vip_6_month',
  'soullocket_vip_6_months',
  'soullocket_vip_yearly',
]);
const VIP_PRODUCT_IDS = new Set([
  'soullocket_vip_lifetime',
  'soullocket_vip_forever',
]);
const VIP_PRODUCT_ID_SET = new Set([
  ...VIP_SUBSCRIPTION_IDS,
  ...VIP_PRODUCT_IDS,
]);
const TRIAL_VIP_DURATION_MS = 3 * 24 * 60 * 60 * 1000;
const PURCHASE_LOCK_TTL_MS = 2 * 60 * 1000;
const SECRET_VAULT_UPLOAD_TTL_MS = 15 * 60 * 1000;
const SECRET_VAULT_RESET_DELAY_MS = 24 * 60 * 60 * 1000;
const CHAT_IMAGE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const CHAT_IMAGE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const CHAT_IMAGE_RETENTION_MS = 15 * 24 * 60 * 60 * 1000;
const CHAT_IMAGE_USAGE_TZ_OFFSET_MS = 7 * 60 * 60 * 1000;
const CHAT_IMAGE_FREE_DAILY_LIMIT = 10;
const CHAT_IMAGE_PRO_DAILY_LIMIT = 30;
const MEMORY_IMAGE_USAGE_TZ_OFFSET_MS = 7 * 60 * 60 * 1000;
const MEMORY_IMAGE_FREE_DAILY_LIMIT = 10;
const MEMORY_IMAGE_PRO_DAILY_LIMIT = 30;
const ALBUM_IMAGE_USAGE_TZ_OFFSET_MS = 7 * 60 * 60 * 1000;
const ALBUM_IMAGE_FREE_DAILY_LIMIT = 5;
const ALBUM_IMAGE_PRO_DAILY_LIMIT = 30;
const ALBUM_IMAGE_FREE_TOTAL_CAP = 100;
const ALBUM_IMAGE_PRO_TOTAL_CAP = 1500;
const MEMORY_IMAGE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const MEMORY_IMAGE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const ALBUM_IMAGE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const ALBUM_IMAGE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const PUBLIC_IMAGE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const PUBLIC_IMAGE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const MEMORY_SHARE_DEFAULT_TTL_DAYS = 7;
const MEMORY_SHARE_MAX_TTL_DAYS = 183;
const MEMORY_SHARE_DEFAULT_TTL_MS = MEMORY_SHARE_DEFAULT_TTL_DAYS * 24 * 60 * 60 * 1000;
const MEMORY_SHARE_MAX_ITEMS = 24;
const MEMORY_IMAGE_THUMBNAIL_SIZE = 640;
const MEMORY_IMAGE_THUMBNAIL_QUALITY = 76;
const VOICE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const VOICE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const PRIVATE_MEDIA_READ_TTL_MS = 10 * 60 * 1000;
const CREATIVE_DIARY_VOICE_UPLOAD_TTL_MS = 15 * 60 * 1000;
const CREATIVE_DIARY_VOICE_FINALIZE_TTL_MS = 60 * 60 * 1000;
const SECRET_VAULT_ALLOWED_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.heic',
  '.heif',
]);
const SECRET_VAULT_CONTENT_TYPE_TO_EXTENSION = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/heic': '.heic',
  'image/heif': '.heif',
};
const VOICE_ALLOWED_EXTENSIONS = new Set(['.mp3', '.m4a', '.aac', '.wav', '.ogg']);
const VOICE_CONTENT_TYPE_TO_EXTENSION = {
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/aac': '.aac',
  'audio/wav': '.wav',
  'audio/ogg': '.ogg',
};

function asObject(value) {
  return value && typeof value === 'object' ? value : {};
}

function normalizeText(value) {
  return String(value ?? '').trim();
}

function normalizeEmail(value) {
  return normalizeText(value).toLowerCase();
}

function toTimestamp(value) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? Math.trunc(normalized) : 0;
}

function normalizeVoiceContentType(rawValue) {
  const value = normalizeText(rawValue).toLowerCase();
  if (Object.prototype.hasOwnProperty.call(VOICE_CONTENT_TYPE_TO_EXTENSION, value)) {
    return value;
  }

  throw new functions.https.HttpsError(
    'invalid-argument',
    'Định dạng audio không hợp lệ.',
  );
}

function resolveVoiceExtension({ fileName, contentType }) {
  const normalizedFileName = normalizeText(fileName);
  const extension = normalizedFileName
    ? require('path').extname(normalizedFileName).toLowerCase()
    : '';
  if (VOICE_ALLOWED_EXTENSIONS.has(extension)) {
    return extension;
  }
  return VOICE_CONTENT_TYPE_TO_EXTENSION[contentType] || '.m4a';
}

function isVoiceStoragePath(storagePath, uid, houseId, folder = 'utilities/voices') {
  return normalizeText(storagePath).startsWith(`uploads/${uid}/houses/${houseId}/${folder}/`);
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value ?? '')).digest('hex');
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function allowedCorsOrigin() {
  const configOrigins = functions.config()?.app?.allowed_origins;
  const origins = String(
    process.env.ALLOWED_ORIGINS ||
      configOrigins ||
      'https://soullockket.web.app,https://soullockket.firebaseapp.com,https://admin-soullockket.web.app',
  )
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  return origins[0] || 'https://soullockket.web.app';
}

function setCorsHeaders(res) {
  res.set('Access-Control-Allow-Origin', allowedCorsOrigin());
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Firebase-AppCheck');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

function jsonResponse(res, statusCode, payload) {
  setCorsHeaders(res);
  return res.status(statusCode).json(payload);
}

function parseRequestBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }

  return typeof body === 'object' ? body : {};
}

async function verifyRequestUser(req) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.startsWith('Bearer ')) {
    throw new Error('missing_bearer_token');
  }

  const idToken = authHeader.slice('Bearer '.length).trim();
  if (!idToken) {
    throw new Error('empty_bearer_token');
  }

  return admin.auth().verifyIdToken(idToken);
}

async function verifyAppCheckRequest(req) {
  const appCheckToken = normalizeText(req.headers['x-firebase-appcheck']);
  if (!appCheckToken) {
    throw new Error('missing_app_check');
  }

  await admin.appCheck().verifyToken(appCheckToken);
}

function isHouseMember(houseData, uid) {
  const normalizedUid = normalizeText(uid);
  if (!normalizedUid) {
    return false;
  }

  if (normalizeText(houseData.owner_uid) === normalizedUid) {
    return true;
  }

  const membersData = asObject(houseData.members);
  if (Object.prototype.hasOwnProperty.call(membersData, normalizedUid)) {
    return true;
  }

  return Object.values(membersData).some((rawValue) => {
    const item = asObject(rawValue);
    return normalizeText(item.uid) === normalizedUid;
  });
}

async function resolveHouseIdForUser(uid, requestedHouseId) {
  const userSnapshot = await admin.database().ref(`users/${uid}`).once('value');
  const userData = asObject(userSnapshot.val());
  const storedHouseId = normalizeText(userData.houseId || userData.house_id);
  const payloadHouseId = normalizeText(requestedHouseId);

  if (payloadHouseId && storedHouseId && payloadHouseId !== storedHouseId) {
    throw new Error('house_mismatch');
  }

  return payloadHouseId || storedHouseId;
}

async function resolveMemberHouse(uid, requestedHouseId) {
  const houseId = await resolveHouseIdForUser(uid, requestedHouseId);
  if (!houseId) {
    throw new Error('house_not_found');
  }

  const db = admin.database();
  const houseSnapshot = await db.ref(`houses/${houseId}`).once('value');
  if (!houseSnapshot.exists()) {
    throw new Error('house_not_found');
  }

  const houseData = asObject(houseSnapshot.val());
  if (!isHouseMember(houseData, uid)) {
    throw new Error('forbidden');
  }

  return { houseId, houseData };
}

function isVipActiveForHouseData(houseData, nowMs = Date.now()) {
  const proUntil = toTimestamp(houseData.proUntil);
  return proUntil > nowMs;
}

function resolveProRewardPlan(planId) {
  const normalizedPlanId = normalizeText(planId).toLowerCase();
  if (!normalizedPlanId || !PRO_REWARD_PLANS.has(normalizedPlanId)) {
    return null;
  }
  return PRO_REWARD_PLANS.get(normalizedPlanId);
}

async function writeRewardAuditLog({
  uid,
  action,
  status,
  reason = '',
  severity = 'info',
  extra = {},
}) {
  await admin.database().ref('admin_system/audit_log').push().set({
    type: 'reward_security',
    uid,
    action,
    status,
    reason: normalizeText(reason),
    severity,
    ts: admin.database.ServerValue.TIMESTAMP,
    ...extra,
  });
}

async function writeRewardHistoryEntry({ db, uid, payload }) {
  await db.ref(`reward_history/${uid}`).push().set({
    ...payload,
    ts: admin.database.ServerValue.TIMESTAMP,
  });
}

function classifyRewardSeverity(code) {
  switch (normalizeText(code)) {
    case 'forbidden':
    case 'house_mismatch':
    case 'missing_app_check':
    case 'invalid_app_check':
      return 'high';
    case 'invalid_plan':
    case 'not_enough_points':
    case 'points_transaction_failed':
    case 'pro_transaction_failed':
      return 'medium';
    default:
      return 'info';
  }
}

async function auditRedeemAttempt({
  uid,
  planId,
  requestedHouseId,
  status,
  reason = '',
  houseId,
  pointsBefore,
  pointsAfter,
  pointsCost,
  durationMs,
  proUntil,
}) {
  const extra = {
    planId: normalizeText(planId),
    requestedHouseId: normalizeText(requestedHouseId),
  };
  const normalizedHouseId = normalizeText(houseId);
  if (normalizedHouseId) {
    extra.houseId = normalizedHouseId;
  }
  if (pointsBefore != null) {
    extra.pointsBefore = pointsBefore;
  }
  if (pointsAfter != null) {
    extra.pointsAfter = pointsAfter;
  }
  if (pointsCost != null) {
    extra.pointsCost = pointsCost;
  }
  if (durationMs != null) {
    extra.durationMs = durationMs;
  }
  if (proUntil != null) {
    extra.proUntil = proUntil;
  }

  await writeRewardAuditLog({
    uid,
    action: 'redeem_pro_plan',
    status,
    reason,
    severity: status === 'success' ? 'info' : classifyRewardSeverity(reason),
    extra,
  });
}

function normalizeRewardPlanId(planId) {
  return normalizeText(planId).toLowerCase();
}

function isNonEmptyText(value) {
  return normalizeText(value).length > 0;
}

async function verifyGooglePlayPurchase(productId, purchaseToken) {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  if (VIP_SUBSCRIPTION_IDS.has(productId)) {
    const response = await publisher.purchases.subscriptions.get({
      packageName: PLAY_PACKAGE_NAME,
      subscriptionId: productId,
      token: purchaseToken,
    });
    const data = asObject(response.data);
    const expiryTimeMillis = toTimestamp(data.expiryTimeMillis);
    return {
      isValid: expiryTimeMillis > Date.now(),
      purchaseType: 'subscription',
      expiryTimeMillis: expiryTimeMillis > 0 ? expiryTimeMillis : null,
      orderId: normalizeText(data.orderId) || null,
    };
  }

  if (VIP_PRODUCT_IDS.has(productId)) {
    const response = await publisher.purchases.products.get({
      packageName: PLAY_PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
    const data = asObject(response.data);
    const purchaseState = Number(data.purchaseState ?? -1);
    return {
      isValid: purchaseState === 0,
      purchaseType: 'non_consumable',
      expiryTimeMillis: null,
      orderId: normalizeText(data.orderId) || null,
    };
  }

  return {
    isValid: false,
    purchaseType: null,
    expiryTimeMillis: null,
    orderId: null,
  };
}

function buildVerifyPurchaseSuccess(record, fallbackHouseId = '') {
  const effectiveHouseId = normalizeText(record.houseId || fallbackHouseId);
  const expiryTimeMillis = toTimestamp(record.expiryTimeMillis);
  const payload = {
    ok: true,
    uid: normalizeText(record.uid) || null,
    houseId: effectiveHouseId || null,
    productId: normalizeText(record.productId),
    purchaseType: normalizeText(record.purchaseType) || null,
    isVip: true,
  };

  const orderId = normalizeText(record.orderId);
  if (expiryTimeMillis > 0) {
    payload.vipExpiresAt = expiryTimeMillis;
  }
  if (orderId) {
    payload.orderId = orderId;
  }

  return payload;
}

function normalizePublicImageTarget(value) {
  const target = normalizeText(value).toLowerCase();
  return new Set([
    'home_avatar',
    'house_avatar',
    'profile_header',
    'story',
    'social_post',
  ]).has(target)
    ? target
    : '';
}

function normalizePublicImageContentType(value) {
  const contentType = normalizeText(value).toLowerCase();
  return contentType.startsWith('image/') ? contentType : 'image/webp';
}

function resolvePublicImageExtension({ fileName, contentType }) {
  const normalizedName = normalizeText(fileName).toLowerCase();
  const ext = normalizedName.includes('.') ? normalizedName.slice(normalizedName.lastIndexOf('.')) : '';
  if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif'].includes(ext)) {
    return ext;
  }
  switch (normalizePublicImageContentType(contentType)) {
    case 'image/png':
      return '.png';
    case 'image/gif':
      return '.gif';
    case 'image/heic':
      return '.heic';
    case 'image/heif':
      return '.heif';
    case 'image/jpeg':
      return '.jpg';
    default:
      return '.webp';
  }
}

async function reservePurchaseVerification({
  db,
  tokenHash,
  uid,
  houseId,
  productId,
  source,
}) {
  const ref = db.ref(`purchase_verifications/${tokenHash}`);
  const now = Date.now();
  let state = 'unknown';

  const transaction = await ref.transaction((current) => {
    const record = asObject(current);
    const existingUid = normalizeText(record.uid);
    const existingHouseId = normalizeText(record.houseId);
    const existingStatus = normalizeText(record.status).toLowerCase();
    const lockedAt = toTimestamp(record.lockedAt || record.lastAttemptAt || record.verifiedAt);

    if (existingUid && existingUid !== uid) {
      state = 'purchase_already_claimed';
      return;
    }

    if (existingHouseId && houseId && existingHouseId !== houseId) {
      state = 'purchase_bound_to_other_house';
      return;
    }

    const canRebindHouse = existingStatus === 'verified' && !existingHouseId && !!houseId;
    if (existingStatus === 'verified' && !canRebindHouse) {
      state = 'already_verified';
      return current;
    }

    if (
      existingStatus === 'pending' &&
      lockedAt > 0 &&
      now - lockedAt < PURCHASE_LOCK_TTL_MS
    ) {
      state = 'purchase_verification_in_progress';
      return;
    }

    state = 'reserved';
    return {
      ...record,
      uid,
      houseId: existingHouseId || houseId || null,
      productId,
      source,
      status: 'pending',
      lockedAt: now,
      lastAttemptAt: now,
    };
  });

  return {
    state,
    record: asObject(transaction.snapshot.val()),
  };
}

async function markPurchaseVerificationFailed({ db, tokenHash, record, code }) {
  const nextRecord = {
    ...asObject(record),
    status: 'failed',
    failureCode: normalizeText(code) || 'verification_failed',
    failedAt: admin.database.ServerValue.TIMESTAMP,
    lastAttemptAt: Date.now(),
  };
  delete nextRecord.lockedAt;
  await db.ref(`purchase_verifications/${tokenHash}`).set(nextRecord);
}

async function deductRewardPointsWithRetry({
  db,
  uid,
  pointsCost,
  maxAttempts = 3,
}) {
  const normalizedCost = Math.max(0, Math.trunc(Number(pointsCost) || 0));
  if (normalizedCost <= 0) {
    throw new Error('invalid_plan');
  }

  const pointsRef = db.ref(`users/${uid}/points`);

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const currentSnapshot = await pointsRef.once('value');
    const currentPoints = Math.max(
      0,
      Math.trunc(Number(currentSnapshot.val()) || 0),
    );
    if (currentPoints < normalizedCost) {
      throw new Error('not_enough_points');
    }

    let remainingPoints = currentPoints - normalizedCost;
    const transactionResult = await pointsRef.transaction((current) => {
      const livePoints = Math.max(0, Math.trunc(Number(current) || 0));
      if (livePoints < normalizedCost) {
        return;
      }
      remainingPoints = livePoints - normalizedCost;
      return remainingPoints;
    });

    if (transactionResult.committed) {
      return Math.trunc(
        Number(transactionResult.snapshot.val()) || remainingPoints,
      );
    }

    const freshSnapshot = await pointsRef.once('value');
    const freshPoints = Math.max(
      0,
      Math.trunc(Number(freshSnapshot.val()) || 0),
    );
    if (freshPoints < normalizedCost) {
      throw new Error('not_enough_points');
    }

    console.warn('deductRewardPointsWithRetry retrying aborted transaction', {
      uid,
      attempt,
      pointsCost: normalizedCost,
      currentPoints,
      freshPoints,
    });
  }

  throw new Error('points_transaction_failed');
}

async function redeemProPlanForUser({
  uid,
  requestedHouseId,
  planId,
}) {
  const normalizedPlanId = normalizeRewardPlanId(planId);
  const plan = resolveProRewardPlan(normalizedPlanId);
  if (!plan) {
    await auditRedeemAttempt({
      uid,
      planId: normalizedPlanId,
      requestedHouseId,
      status: 'rejected',
      reason: 'invalid_plan',
    });
    throw new Error('invalid_plan');
  }

  const db = admin.database();
  let houseId = '';
  let pointsBefore = 0;
  let remainingPoints = 0;
  let newProUntil = 0;
  const pointsRef = db.ref(`users/${uid}/points`);

  try {
    ({ houseId } = await resolveMemberHouse(uid, requestedHouseId));
    const currentPointsSnapshot = await pointsRef.once('value');
    pointsBefore = Math.max(
      0,
      Math.trunc(Number(currentPointsSnapshot.val()) || 0),
    );

    remainingPoints = await deductRewardPointsWithRetry({
      db,
      uid,
      pointsCost: plan.pointsCost,
    });

    const proRef = db.ref(`houses/${houseId}/proUntil`);
    const proResult = await proRef.transaction((current) => {
      const now = Date.now();
      const currentProUntil = Math.max(0, Math.trunc(Number(current) || 0));
      const base = currentProUntil > now ? currentProUntil : now;
      newProUntil = base + plan.durationMs;
      return newProUntil;
    });

    if (!proResult.committed) {
      throw new Error('pro_transaction_failed');
    }

    newProUntil = Math.trunc(Number(proResult.snapshot.val()) || newProUntil);
    const notificationRef = db.ref(`notifications/${houseId}`).push();
    const rewardHistoryKey = db.ref(`reward_history/${uid}`).push().key;
    const updates = {
      [`houses/${houseId}/vip`]: {
        isVip: true,
        plan: 'reward_points',
        vipExpiresAt: newProUntil,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
        updatedBy: uid,
      },
      [`house_profiles/${houseId}/proUntil`]: newProUntil,
      [`houses_public/${houseId}/proUntil`]: newProUntil,
      [`notifications/${houseId}/${notificationRef.key}`]: {
        type: 'system',
        from: 'Hệ thống',
        title: 'Gia hạn PRO thành công',
        msg: `Bạn đã đổi ${plan.pointsCost} điểm để gia hạn PRO.`,
        ts: admin.database.ServerValue.TIMESTAMP,
        immutable: true,
        systemLocked: true,
        source: 'redeem_pro_plan',
      },
      [`reward_history/${uid}/${rewardHistoryKey}`]: {
        type: 'redeem_pro',
        status: 'success',
        planId: normalizedPlanId,
        houseId,
        pointsBefore,
        pointsAfter: remainingPoints,
        pointsCost: plan.pointsCost,
        durationMs: plan.durationMs,
        proUntil: newProUntil,
        ts: admin.database.ServerValue.TIMESTAMP,
      },
    };
    await db.ref().update(updates);

    await auditRedeemAttempt({
      uid,
      planId: normalizedPlanId,
      requestedHouseId,
      status: 'success',
      reason: 'redeemed',
      houseId,
      pointsBefore,
      pointsAfter: remainingPoints,
      pointsCost: plan.pointsCost,
      durationMs: plan.durationMs,
      proUntil: newProUntil,
    });
  } catch (error) {
    const code = normalizeText(error?.message);
    if (remainingPoints > 0 && code !== 'not_enough_points') {
      await pointsRef.transaction((current) => {
        const currentPoints = Math.max(0, Math.trunc(Number(current) || 0));
        return currentPoints + plan.pointsCost;
      });
      remainingPoints = pointsBefore;
    }

    await auditRedeemAttempt({
      uid,
      planId: normalizedPlanId,
      requestedHouseId,
      status: 'rejected',
      reason: code || 'redeem_pro_plan_failed',
      houseId,
      pointsBefore: pointsBefore || undefined,
      pointsAfter: remainingPoints || undefined,
      pointsCost: plan.pointsCost,
      durationMs: plan.durationMs,
      proUntil: newProUntil || undefined,
    });
    throw error;
  }

  return {
    houseId,
    proUntil: newProUntil,
    points: remainingPoints,
  };
}

async function reserveHouseCreationTrialVip({ db, uid, houseId, now }) {
  const claimedAtRef = db.ref(`users/${uid}/trialVipClaimedAt`);
  const trialClaimResult = await claimedAtRef.transaction((current) => {
    const existingClaimedAt = toTimestamp(current);
    if (existingClaimedAt > 0) {
      return;
    }
    return now;
  });

  const trialGranted = trialClaimResult.committed;
  if (!trialGranted) {
    return {
      trialGranted: false,
      claimedAt: toTimestamp(trialClaimResult.snapshot.val()),
      trialUntil: 0,
      userUpdates: {},
      houseVipPatch: {},
      profilePatch: {},
      publicPatch: {},
    };
  }

  const trialUntil = now + TRIAL_VIP_DURATION_MS;
  return {
    trialGranted: true,
    claimedAt: now,
    trialUntil,
    userUpdates: {
      [`users/${uid}/trialVipHouseId`]: houseId,
    },
    houseVipPatch: {
      vip: {
        isVip: true,
        plan: 'trial',
        vipExpiresAt: trialUntil,
        activatedAt: admin.database.ServerValue.TIMESTAMP,
      },
      proUntil: trialUntil,
    },
    profilePatch: {
      proUntil: trialUntil,
    },
    publicPatch: {
      proUntil: trialUntil,
    },
  };
}

async function rollbackHouseCreationTrialVip({ db, uid, houseId, claimedAt }) {
  const normalizedHouseId = normalizeText(houseId);
  const normalizedClaimedAt = toTimestamp(claimedAt);
  if (!normalizedHouseId || normalizedClaimedAt <= 0) {
    return;
  }

  const claimedAtRef = db.ref(`users/${uid}/trialVipClaimedAt`);
  await claimedAtRef.transaction((current) => {
    if (toTimestamp(current) !== normalizedClaimedAt) {
      return current;
    }
    return null;
  });

  const houseIdRef = db.ref(`users/${uid}/trialVipHouseId`);
  await houseIdRef.transaction((current) => {
    if (normalizeText(current) !== normalizedHouseId) {
      return current;
    }
    return null;
  });
}

function normalizeSecretVaultContentType(value) {
  const contentType = normalizeText(value).toLowerCase();
  if (!contentType || !contentType.startsWith('image/')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Chỉ hỗ trợ ảnh cho Secret Vault.',
    );
  }

  return contentType.slice(0, 100);
}

function resolveSecretVaultExtension({ fileName, contentType }) {
  const sanitizedFileName = normalizeText(fileName).replace(/[?#].*$/, '');
  const lastDotIndex = sanitizedFileName.lastIndexOf('.');
  const requestedExtension = lastDotIndex >= 0
    ? sanitizedFileName.slice(lastDotIndex).toLowerCase()
    : '';

  if (requestedExtension && SECRET_VAULT_ALLOWED_EXTENSIONS.has(requestedExtension)) {
    return requestedExtension;
  }

  return SECRET_VAULT_CONTENT_TYPE_TO_EXTENSION[contentType] || '.jpg';
}

function normalizeChatImageScope(value) {
  const scope = normalizeText(value).toLowerCase();
  return scope === 'direct' || scope === 'internal' ? scope : '';
}

function normalizeChatSenderRole(value) {
  return normalizeText(value).toLowerCase() === 'user2' ? 'user2' : 'user1';
}

function buildChatRoomId(houseId, targetHouseId) {
  return [normalizeText(houseId), normalizeText(targetHouseId)]
    .filter(Boolean)
    .sort()
    .join('_');
}

function buildChatImageDayKey(nowMs = Date.now()) {
  return new Date(nowMs + CHAT_IMAGE_USAGE_TZ_OFFSET_MS)
    .toISOString()
    .slice(0, 10)
    .replace(/-/g, '');
}

function buildMemoryImageDayKey(nowMs = Date.now()) {
  return new Date(nowMs + MEMORY_IMAGE_USAGE_TZ_OFFSET_MS)
    .toISOString()
    .slice(0, 10)
    .replace(/-/g, '');
}

function buildAlbumImageDayKey(nowMs = Date.now()) {
  return new Date(nowMs + ALBUM_IMAGE_USAGE_TZ_OFFSET_MS)
    .toISOString()
    .slice(0, 10)
    .replace(/-/g, '');
}

async function reserveMemoryImageQuota({
  db,
  uid,
  houseId,
  houseData,
  now,
}) {
  const isPro = isVipActiveForHouseData(houseData, now);
  const dailyLimit = isPro
    ? MEMORY_IMAGE_PRO_DAILY_LIMIT
    : MEMORY_IMAGE_FREE_DAILY_LIMIT;
  const dayKey = buildMemoryImageDayKey(now);
  const usageRef = db.ref(`memory_image_usage/${uid}/${dayKey}`);
  let quotaExceeded = false;
  let usedToday = 0;
  let effectiveDailyLimit = dailyLimit;
  let effectivePlan = isPro ? 'pro' : 'free';

  const transactionResult = await usageRef.transaction((current) => {
    const currentData = asObject(current);
    const currentCount = Math.max(0, Math.trunc(Number(currentData.count) || 0));
    const storedDailyLimit = Math.max(0, Math.trunc(Number(currentData.dailyLimit) || 0));
    effectiveDailyLimit = Math.max(dailyLimit, storedDailyLimit);
    effectivePlan = effectiveDailyLimit > dailyLimit ? 'pro' : (isPro ? 'pro' : 'free');
    if (currentCount >= effectiveDailyLimit) {
      quotaExceeded = true;
      return;
    }

    usedToday = currentCount + 1;
    return {
      count: usedToday,
      dailyLimit: effectiveDailyLimit,
      houseId,
      plan: effectivePlan,
      updatedAt: now,
    };
  });

  if (!transactionResult.committed) {
    if (quotaExceeded) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        isPro
          ? `Bạn đã đạt giới hạn ${dailyLimit} ảnh Kỷ niệm hôm nay.`
          : `Tài khoản thường chỉ đăng được ${dailyLimit} ảnh Kỷ niệm/ngày.`,
      );
    }
    throw new functions.https.HttpsError(
      'aborted',
      'Không thể giữ lượt đăng ảnh Kỷ niệm lúc này. Vui lòng thử lại.',
    );
  }

  return {
    dayKey,
    dailyLimit,
    usedToday,
    remainingToday: Math.max(0, dailyLimit - usedToday),
    isPro,
  };
}

async function rollbackMemoryImageQuota({
  db,
  uid,
  dayKey,
}) {
  const usageRef = db.ref(`memory_image_usage/${uid}/${dayKey}`);
  await usageRef.transaction((current) => {
    const currentData = asObject(current);
    const currentCount = Math.max(0, Math.trunc(Number(currentData.count) || 0));
    if (currentCount <= 1) {
      return null;
    }
    return {
      ...currentData,
      count: currentCount - 1,
      updatedAt: Date.now(),
    };
  });
}

async function reserveAlbumImageQuota({
  db,
  uid,
  houseId,
  now,
}) {
  const houseSnapshot = await db.ref(`houses/${houseId}`).once('value');
  const houseData = asObject(houseSnapshot.val());
  const isPro = isVipActiveForHouseData(houseData, now);
  const dailyLimit = isPro
    ? ALBUM_IMAGE_PRO_DAILY_LIMIT
    : ALBUM_IMAGE_FREE_DAILY_LIMIT;
  const totalCap = isPro
    ? ALBUM_IMAGE_PRO_TOTAL_CAP
    : ALBUM_IMAGE_FREE_TOTAL_CAP;
  const dayKey = buildAlbumImageDayKey(now);
  const usageRef = db.ref(`album_image_usage/${uid}/${dayKey}`);
  const albumCountRef = db.ref(`houses/${houseId}/albumCount`);
  let quotaExceeded = false;
  let capExceeded = false;
  let usedToday = 0;
  let nextAlbumCount = 0;

  const usageResult = await usageRef.transaction((current) => {
    const currentData = asObject(current);
    const currentCount = Math.max(0, Math.trunc(Number(currentData.count) || 0));
    if (currentCount >= dailyLimit) {
      quotaExceeded = true;
      return;
    }

    usedToday = currentCount + 1;
    return {
      count: usedToday,
      dailyLimit,
      houseId,
      plan: isPro ? 'pro' : 'free',
      updatedAt: now,
    };
  });

  if (!usageResult.committed) {
    if (quotaExceeded) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        isPro
          ? `Bạn đã dùng hết ${dailyLimit} ảnh Album hôm nay.`
          : `Tài khoản thường chỉ tải được ${dailyLimit} ảnh Album/ngày.`,
      );
    }
    throw new functions.https.HttpsError(
      'aborted',
      'Không thể giữ lượt tải ảnh Album lúc này. Vui lòng thử lại.',
    );
  }

  try {
    const countResult = await albumCountRef.transaction((current) => {
      const currentCount = Math.max(0, Math.trunc(Number(current) || 0));
      if (currentCount >= totalCap) {
        capExceeded = true;
        nextAlbumCount = currentCount;
        return;
      }

      nextAlbumCount = currentCount + 1;
      return nextAlbumCount;
    });

    if (!countResult.committed) {
      if (capExceeded) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          isPro
            ? `Album đã đạt tối đa ${totalCap} ảnh.`
            : `Tài khoản thường chỉ lưu tối đa ${totalCap} ảnh Album.`,
        );
      }
      throw new functions.https.HttpsError(
        'aborted',
        'Không thể cập nhật số lượng ảnh Album lúc này. Vui lòng thử lại.',
      );
    }
  } catch (error) {
    try {
      await rollbackMemoryImageQuota({
        db,
        uid,
        dayKey,
      });
    } catch (_) {}
    throw error;
  }

  return {
    dayKey,
    dailyLimit,
    usedToday,
    remainingToday: Math.max(0, dailyLimit - usedToday),
    totalCap,
    albumCount: nextAlbumCount,
    isPro,
  };
}

async function rollbackAlbumImageQuota({
  db,
  uid,
  dayKey,
  houseId,
}) {
  await rollbackMemoryImageQuota({
    db,
    uid,
    dayKey,
  });

  const albumCountRef = db.ref(`houses/${houseId}/albumCount`);
  await albumCountRef.transaction((current) => {
    const currentCount = Math.max(0, Math.trunc(Number(current) || 0));
    return currentCount <= 0 ? 0 : currentCount - 1;
  });
}

function buildExpiredChatImageText() {
  return 'Ảnh đã bị xóa sau 15 ngày';
}

function normalizeChatImageContentType(value) {
  const contentType = normalizeText(value).toLowerCase();
  if (!contentType || !contentType.startsWith('image/')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Chỉ hỗ trợ ảnh cho chat.',
    );
  }

  return contentType.slice(0, 100);
}

function resolveChatImageExtension({ fileName, contentType }) {
  const sanitizedFileName = normalizeText(fileName).replace(/[?#].*$/, '');
  const lastDotIndex = sanitizedFileName.lastIndexOf('.');
  const requestedExtension = lastDotIndex >= 0
    ? sanitizedFileName.slice(lastDotIndex).toLowerCase()
    : '';

  if (requestedExtension && SECRET_VAULT_ALLOWED_EXTENSIONS.has(requestedExtension)) {
    return requestedExtension;
  }

  return SECRET_VAULT_CONTENT_TYPE_TO_EXTENSION[contentType] || '.jpg';
}

function normalizeMemoryImageContentType(value) {
  const contentType = normalizeText(value).toLowerCase();
  if (!contentType || !contentType.startsWith('image/')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Chỉ hỗ trợ ảnh cho Kỷ niệm.',
    );
  }

  return contentType.slice(0, 100);
}

function resolveMemoryImageExtension({ fileName, contentType }) {
  const sanitizedFileName = normalizeText(fileName).replace(/[?#].*$/, '');
  const lastDotIndex = sanitizedFileName.lastIndexOf('.');
  const requestedExtension = lastDotIndex >= 0
    ? sanitizedFileName.slice(lastDotIndex).toLowerCase()
    : '';

  if (requestedExtension && SECRET_VAULT_ALLOWED_EXTENSIONS.has(requestedExtension)) {
    return requestedExtension;
  }

  return SECRET_VAULT_CONTENT_TYPE_TO_EXTENSION[contentType] || '.jpg';
}

function isMemoryStoragePath(storagePath, uid, houseId) {
  const segments = parseStoragePathSegments(storagePath);
  return segments.length >= 6 &&
    segments[0] === 'uploads' &&
    segments[1] === normalizeText(uid) &&
    segments[2] === 'houses' &&
    segments[3] === normalizeText(houseId) &&
    segments[4] === 'memories';
}

async function createMemoryThumbnail({ bucket, storagePath }) {
  const normalizedPath = normalizeText(storagePath);
  if (!normalizedPath) {
    return null;
  }

  const originalFile = bucket.file(normalizedPath);
  const [buffer] = await originalFile.download();
  const thumbnailBuffer = await sharp(buffer)
    .rotate()
    .resize({
      width: MEMORY_IMAGE_THUMBNAIL_SIZE,
      height: MEMORY_IMAGE_THUMBNAIL_SIZE,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .jpeg({
      quality: MEMORY_IMAGE_THUMBNAIL_QUALITY,
      mozjpeg: true,
    })
    .toBuffer();

  const thumbnailPath = normalizedPath.replace(/(\.[^.\/]+)?$/, '_thumb.jpg');
  const thumbToken = crypto.randomUUID();
  const thumbnailFile = bucket.file(thumbnailPath);
  await thumbnailFile.save(thumbnailBuffer, {
    resumable: false,
    metadata: {
      contentType: 'image/jpeg',
      metadata: {
        firebaseStorageDownloadTokens: thumbToken,
        sourcePath: normalizedPath,
        mediaKind: 'memory_image_thumbnail',
      },
      cacheControl: 'public,max-age=31536000,immutable',
    },
  });

  return {
    thumbPath: thumbnailPath,
    thumbUrl: buildFirebaseDownloadUrl(bucket.name, thumbnailPath, thumbToken),
    thumbContentType: 'image/jpeg',
  };
}

async function createTemporaryReadUrl(bucket, storagePath, ttlMs = PRIVATE_MEDIA_READ_TTL_MS) {
  const normalizedPath = normalizeText(storagePath);
  if (!normalizedPath) {
    throw new functions.https.HttpsError('invalid-argument', 'Thiếu đường dẫn media riêng tư.');
  }

  const [url] = await bucket.file(normalizedPath).getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + Math.max(60 * 1000, ttlMs),
  });
  return url;
}

function normalizePrivateMediaKind(value) {
  const kind = normalizeText(value).toLowerCase();
  return kind === 'memory_image' || kind === 'voice' ? kind : '';
}

function canReadPrivateMemoryRecord(record, houseId) {
  const storagePath = normalizeText(record.storagePath || record.storageKey);
  const ownerUid = normalizeText(record.authorId || record.ownerUid);
  return !!storagePath && !!ownerUid && isMemoryStoragePath(storagePath, ownerUid, houseId);
}

function canReadPrivateVoiceRecord(record, houseId) {
  const storagePath = normalizeText(record.storagePath || record.storageKey);
  const ownerUid = normalizeText(record.ownerUid || record.authorId);
  return !!storagePath && !!ownerUid && isVoiceStoragePath(storagePath, ownerUid, houseId);
}

function normalizeAlbumImageContentType(value) {
  const contentType = normalizeText(value).toLowerCase();
  if (!contentType || !contentType.startsWith('image/')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Chỉ hỗ trợ ảnh cho Album.',
    );
  }

  return contentType.slice(0, 100);
}

function resolveAlbumImageExtension({ fileName, contentType }) {
  const sanitizedFileName = normalizeText(fileName).replace(/[?#].*$/, '');
  const lastDotIndex = sanitizedFileName.lastIndexOf('.');
  const requestedExtension = lastDotIndex >= 0
    ? sanitizedFileName.slice(lastDotIndex).toLowerCase()
    : '';

  if (requestedExtension && SECRET_VAULT_ALLOWED_EXTENSIONS.has(requestedExtension)) {
    return requestedExtension;
  }

  return SECRET_VAULT_CONTENT_TYPE_TO_EXTENSION[contentType] || '.jpg';
}

function isAlbumStoragePath(storagePath, uid, houseId) {
  const segments = parseStoragePathSegments(storagePath);
  return segments.length >= 6 &&
    segments[0] === 'uploads' &&
    segments[1] === normalizeText(uid) &&
    segments[2] === 'houses' &&
    segments[3] === normalizeText(houseId) &&
    segments[4] === 'album';
}

async function reserveChatImageQuota({
  db,
  uid,
  houseId,
  houseData,
  now,
}) {
  const isPro = isVipActiveForHouseData(houseData, now);
  const dailyLimit = isPro ? CHAT_IMAGE_PRO_DAILY_LIMIT : CHAT_IMAGE_FREE_DAILY_LIMIT;
  const dayKey = buildChatImageDayKey(now);
  const usageRef = db.ref(`chat_image_usage/${uid}/${dayKey}`);
  let quotaExceeded = false;
  let usedToday = 0;

  const transactionResult = await usageRef.transaction((current) => {
    const currentData = asObject(current);
    const currentCount = Math.max(0, Math.trunc(Number(currentData.count) || 0));
    if (currentCount >= dailyLimit) {
      quotaExceeded = true;
      return;
    }

    usedToday = currentCount + 1;
    return {
      count: usedToday,
      dailyLimit,
      houseId,
      plan: isPro ? 'pro' : 'free',
      updatedAt: now,
    };
  });

  if (!transactionResult.committed) {
    if (quotaExceeded) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Bạn đã dùng hết ${dailyLimit} ảnh chat trong hôm nay.`,
      );
    }
    throw new functions.https.HttpsError(
      'aborted',
      'Không thể giữ lượt gửi ảnh chat lúc này. Vui lòng thử lại.',
    );
  }

  return {
    dayKey,
    dailyLimit,
    usedToday,
    remainingToday: Math.max(0, dailyLimit - usedToday),
    isPro,
  };
}

async function rollbackChatImageQuota({
  db,
  uid,
  dayKey,
}) {
  const usageRef = db.ref(`chat_image_usage/${uid}/${dayKey}`);
  await usageRef.transaction((current) => {
    const currentData = asObject(current);
    const currentCount = Math.max(0, Math.trunc(Number(currentData.count) || 0));
    if (currentCount <= 1) {
      return null;
    }

    return {
      ...currentData,
      count: currentCount - 1,
      updatedAt: Date.now(),
    };
  });
}

async function assertDirectChatImageAllowed({
  db,
  houseId,
  houseData,
  targetHouseId,
}) {
  const normalizedTargetHouseId = normalizeText(targetHouseId);
  if (!normalizedTargetHouseId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Thiếu targetHouseId cho ảnh chat.',
    );
  }

  if (normalizedTargetHouseId === houseId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Chat nội bộ không dùng targetHouseId.',
    );
  }

  const targetHouseSnapshot = await db.ref(`houses/${normalizedTargetHouseId}`).once('value');
  if (!targetHouseSnapshot.exists()) {
    throw new functions.https.HttpsError(
      'not-found',
      'Không tìm thấy nhà nhận ảnh.',
    );
  }

  const targetHouseData = asObject(targetHouseSnapshot.val());
  const sourceBlocked = asObject(houseData.blocked_users);
  const targetBlocked = asObject(targetHouseData.blocked_users);
  if (sourceBlocked[normalizedTargetHouseId] === true || targetBlocked[houseId] === true) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Hai nhà đã chặn nhau, không thể gửi ảnh.',
    );
  }

  const roomId = buildChatRoomId(houseId, normalizedTargetHouseId);
  const roomSnapshot = await db.ref(`chats/${roomId}`).once('value');
  if (roomSnapshot.exists()) {
    const roomData = asObject(roomSnapshot.val());
    if (normalizeText(roomData.status).toLowerCase() === 'closed') {
      const closedMessage = normalizeText(roomData.closedMessage);
      throw new functions.https.HttpsError(
        'failed-precondition',
        closedMessage || 'Đoạn chat này đã bị đóng.',
      );
    }
  }

  return {
    roomId,
    targetHouseId: normalizedTargetHouseId,
  };
}

async function ensureDirectChatRoomMetadata({
  db,
  myHouseId,
  targetHouseId,
  roomId,
}) {
  const ids = [normalizeText(myHouseId), normalizeText(targetHouseId)].sort();
  await db.ref().update({
    [`chats/${roomId}/members/${myHouseId}`]: true,
    [`chats/${roomId}/members/${targetHouseId}`]: true,
    [`chats/${roomId}/participants/${myHouseId}`]: true,
    [`chats/${roomId}/participants/${targetHouseId}`]: true,
    [`chats/${roomId}/houseA`]: ids[0],
    [`chats/${roomId}/houseB`]: ids[1],
    [`houses/${myHouseId}/chat_rooms/${roomId}`]: true,
    [`houses/${targetHouseId}/chat_rooms/${roomId}`]: true,
  });
}

async function deleteStorageObjectIfExists(bucket, storagePath) {
  const normalizedPath = normalizeText(storagePath);
  if (!normalizedPath) {
    return;
  }

  try {
    await bucket.file(normalizedPath).delete();
  } catch (error) {
    const code = normalizeText(error?.code);
    const message = normalizeText(error?.message).toLowerCase();
    if (code === '404' || message.includes('no such object')) {
      return;
    }
    throw error;
  }
}

function parseStoragePathSegments(storagePath) {
  return normalizeText(storagePath)
    .replace(/^\/+/, '')
    .split('/')
    .filter(Boolean);
}

function isInternalChatBackgroundPath(storagePath, houseId) {
  const segments = parseStoragePathSegments(storagePath);
  return segments.length >= 7 &&
    segments[0] === 'uploads' &&
    segments[2] === 'houses' &&
    segments[3] === normalizeText(houseId) &&
    segments[4] === 'chat_backgrounds' &&
    segments[5] === 'internal';
}

function isDirectChatBackgroundPath(storagePath, houseId, targetHouseId) {
  const normalizedHouseId = normalizeText(houseId);
  const normalizedTargetHouseId = normalizeText(targetHouseId);
  const roomId = buildChatRoomId(normalizedHouseId, normalizedTargetHouseId);
  const segments = parseStoragePathSegments(storagePath);
  if (segments.length < 8) {
    return false;
  }

  return segments[0] === 'uploads' &&
    segments[2] === 'houses' &&
    (segments[3] === normalizedHouseId || segments[3] === normalizedTargetHouseId) &&
    segments[4] === 'chat_backgrounds' &&
    segments[5] === 'direct' &&
    segments[6] === roomId;
}

async function expireChatImageMessage({
  db,
  bucket,
  queueKey,
  queueItem,
  now,
}) {
  const messagePath = normalizeText(queueItem.messagePath);
  const lastMessagePath = normalizeText(queueItem.lastMessagePath);
  const messageId = normalizeText(queueItem.messageId);
  const sessionId = normalizeText(queueItem.sessionId) || normalizeText(queueKey);
  const expiredText = buildExpiredChatImageText();
  const updates = {
    [`chat_image_retention/${queueKey}`]: null,
  };

  await deleteStorageObjectIfExists(bucket, queueItem.storagePath);

  if (messagePath) {
    const messageSnapshot = await db.ref(messagePath).once('value');
    if (messageSnapshot.exists()) {
      updates[`${messagePath}/text`] = expiredText;
      updates[`${messagePath}/imageStatus`] = 'expired';
      updates[`${messagePath}/deletedAt`] = now;
      updates[`${messagePath}/deletedReason`] = 'ttl_expired';
    }
  }

  if (lastMessagePath && messageId) {
    const lastMessageSnapshot = await db.ref(lastMessagePath).once('value');
    const lastMessageData = asObject(lastMessageSnapshot.val());
    if (normalizeText(lastMessageData.messageId) === messageId) {
      updates[`${lastMessagePath}/text`] = expiredText;
      updates[`${lastMessagePath}/imageStatus`] = 'expired';
      updates[`${lastMessagePath}/deletedAt`] = now;
      updates[`${lastMessagePath}/deletedReason`] = 'ttl_expired';
    }
  }

  if (sessionId) {
    updates[`chat_image_upload_sessions/${sessionId}/imageStatus`] = 'expired';
    updates[`chat_image_upload_sessions/${sessionId}/expiredAt`] = now;
    updates[`chat_image_upload_sessions/${sessionId}/deletedReason`] = 'ttl_expired';
  }

  await db.ref().update(updates);
}

async function expirePendingChatImageSession({
  db,
  bucket,
  sessionId,
  session,
  now,
}) {
  const status = normalizeText(session.status).toLowerCase();
  if (status !== 'pending' && status !== 'finalizing') {
    return false;
  }

  await deleteStorageObjectIfExists(bucket, session.storagePath);
  await db.ref(`chat_image_upload_sessions/${sessionId}`).update({
    status: 'expired',
    expiredAt: now,
    expiredReason: status === 'finalizing' ? 'finalize_timeout' : 'session_timeout',
    cleanedUpAt: now,
    finalizeBy: now + CHAT_IMAGE_RETENTION_MS,
  });
  return true;
}

function buildFirebaseDownloadUrl(bucketName, storagePath, downloadToken) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(
    storagePath,
  )}?alt=media&token=${downloadToken}`;
}

function extractStorageObjectPath(url, bucketName) {
  const value = normalizeText(url);
  if (!value) {
    return '';
  }

  if (value.startsWith('gs://')) {
    const withoutScheme = value.slice('gs://'.length);
    const slashIndex = withoutScheme.indexOf('/');
    if (slashIndex <= 0) {
      return '';
    }
    const sourceBucket = withoutScheme.slice(0, slashIndex);
    if (bucketName && sourceBucket !== bucketName) {
      return '';
    }
    return withoutScheme.slice(slashIndex + 1);
  }

  let parsedUrl;
  try {
    parsedUrl = new URL(value);
  } catch (_) {
    return '';
  }

  if (parsedUrl.hostname.toLowerCase().includes('firebasestorage.googleapis.com')) {
    const marker = '/o/';
    const pathIndex = parsedUrl.pathname.indexOf(marker);
    if (pathIndex < 0) {
      return '';
    }
    return decodeURIComponent(parsedUrl.pathname.slice(pathIndex + marker.length));
  }

  if (parsedUrl.hostname.toLowerCase() === 'storage.googleapis.com') {
    const segments = parsedUrl.pathname.split('/').filter(Boolean);
    if (segments.length < 2) {
      return '';
    }
    const sourceBucket = segments.shift();
    if (bucketName && sourceBucket !== bucketName) {
      return '';
    }
    return segments.join('/');
  }

  return '';
}

async function queueHouseNotification({
  houseId,
  senderUid,
  title,
  body,
  data = {},
}) {
  await admin.database().ref('notification_queue').push().set({
    houseId,
    house_id: houseId,
    sender_uid: normalizeText(senderUid) || 'system',
    title,
    body,
    data,
    timestamp: Date.now(),
    status: 'pending',
  });
}

async function cleanupSecretVaultStorage(secretVaultItems) {
  const bucket = admin.storage().bucket();
  const storagePaths = new Set();

  Object.values(asObject(secretVaultItems)).forEach((rawItem) => {
    const item = asObject(rawItem);
    const storagePath = normalizeText(item.storagePath);
    if (storagePath) {
      storagePaths.add(storagePath);
      return;
    }

    const fallbackPath = extractStorageObjectPath(item.url, bucket.name);
    if (fallbackPath) {
      storagePaths.add(fallbackPath);
    }
  });

  for (const storagePath of storagePaths) {
    try {
      await bucket.file(storagePath).delete();
    } catch (error) {
      if (error?.code === 404) {
        continue;
      }
      console.error(`Unable to delete Secret Vault object ${storagePath}:`, error);
    }
  }
}

async function executeSecretVaultReset({ db, houseId, request }) {
  const normalizedHouseId = normalizeText(houseId);
  if (!normalizedHouseId) {
    return false;
  }

  const now = Date.now();
  const normalizedRequest = asObject(request);
  const secretVaultSnap = await db.ref(`houses/${normalizedHouseId}/private_secure`).once('value');
  await cleanupSecretVaultStorage(secretVaultSnap.val());

  await db.ref().update({
    [`houses/${normalizedHouseId}/private_secure`]: null,
    [`houses/${normalizedHouseId}/private_secure_meta/encryption`]: null,
    [`houses/${normalizedHouseId}/private_secure_meta/resetRequest`]: null,
    [`houses/${normalizedHouseId}/private_secure_meta/lastResetAt`]: now,
    [`secret_vault_reset_requests/${normalizedHouseId}/status`]: 'completed',
    [`secret_vault_reset_requests/${normalizedHouseId}/completedAt`]: now,
    [`secret_vault_reset_requests/${normalizedHouseId}/lastProcessedAt`]: now,
  });

  await queueHouseNotification({
    houseId: normalizedHouseId,
    senderUid: normalizedRequest.requestedBy || 'system',
    title: 'Kho ảnh mật đã được reset',
    body: 'Toàn bộ dữ liệu Kho ảnh mật đã được xoá sau thời gian chờ 24 giờ.',
    data: {
      screen: 'vault',
      type: 'secret_vault_reset_completed',
      houseId: normalizedHouseId,
    },
  });

  return true;
}

const verifyPurchase = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res);
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return jsonResponse(res, 405, { ok: false, error: 'method_not_allowed' });
  }

  let decodedToken;
  try {
    decodedToken = await verifyRequestUser(req);
  } catch (_) {
    return jsonResponse(res, 401, { ok: false, error: 'unauthenticated' });
  }

  try {
    await verifyAppCheckRequest(req);
  } catch (error) {
    const code = normalizeText(error?.message);
    return jsonResponse(res, 403, {
      ok: false,
      error: code === 'missing_app_check' ? 'missing_app_check' : 'invalid_app_check',
    });
  }

  const body = parseRequestBody(req.body);
  const authUid = normalizeText(decodedToken.uid);
  const requestedUid = normalizeText(body.uid);
  const productId = normalizeText(body.productId);
  const purchaseToken = normalizeText(body.purchaseToken);
  const source = normalizeText(body.source).toLowerCase();

  if (!authUid) {
    return jsonResponse(res, 401, { ok: false, error: 'invalid_auth_token' });
  }
  if (requestedUid && requestedUid !== authUid) {
    return jsonResponse(res, 403, { ok: false, error: 'uid_mismatch' });
  }
  if (source !== 'google_play') {
    return jsonResponse(res, 400, { ok: false, error: 'unsupported_source' });
  }
  if (!VIP_PRODUCT_ID_SET.has(productId)) {
    return jsonResponse(res, 400, { ok: false, error: 'unsupported_product_id' });
  }
  if (!purchaseToken || purchaseToken.length > 4096) {
    return jsonResponse(res, 400, { ok: false, error: 'invalid_purchase_token' });
  }

  const db = admin.database();
  const tokenHash = sha256(purchaseToken);
  const userSnap = await db.ref(`users/${authUid}`).once('value');
  const userData = asObject(userSnap.val());
  const houseId = normalizeText(userData.houseId || userData.house_id);

  const reservation = await reservePurchaseVerification({
    db,
    tokenHash,
    uid: authUid,
    houseId,
    productId,
    source,
  });

  if (reservation.state === 'purchase_already_claimed') {
    return jsonResponse(res, 409, { ok: false, error: 'purchase_already_claimed' });
  }
  if (reservation.state === 'purchase_bound_to_other_house') {
    return jsonResponse(res, 409, {
      ok: false,
      error: 'purchase_bound_to_other_house',
      houseId: normalizeText(reservation.record.houseId) || null,
    });
  }
  if (reservation.state === 'purchase_verification_in_progress') {
    return jsonResponse(res, 409, {
      ok: false,
      error: 'purchase_verification_in_progress',
    });
  }
  if (reservation.state === 'already_verified') {
    return jsonResponse(res, 200, buildVerifyPurchaseSuccess(reservation.record, houseId));
  }

  try {
    const verifiedPurchase = await verifyGooglePlayPurchase(productId, purchaseToken);
    if (!verifiedPurchase.isValid || !verifiedPurchase.purchaseType) {
      await markPurchaseVerificationFailed({
        db,
        tokenHash,
        record: reservation.record,
        code: 'purchase_not_verified',
      });
      return jsonResponse(res, 400, { ok: false, error: 'purchase_not_verified' });
    }

    const lockedHouseId = normalizeText(reservation.record.houseId);
    if (lockedHouseId && houseId && lockedHouseId !== houseId) {
      await markPurchaseVerificationFailed({
        db,
        tokenHash,
        record: reservation.record,
        code: 'purchase_bound_to_other_house',
      });
      return jsonResponse(res, 409, {
        ok: false,
        error: 'purchase_bound_to_other_house',
        houseId: lockedHouseId,
      });
    }

    const effectiveHouseId = lockedHouseId || houseId;
    const expiryTimeMillis = verifiedPurchase.expiryTimeMillis;
    const houseProUntil = expiryTimeMillis ?? LIFETIME_VIP_EXPIRY_MS;
    const verificationRecord = {
      uid: authUid,
      houseId: effectiveHouseId || null,
      productId,
      source,
      purchaseType: verifiedPurchase.purchaseType,
      status: 'verified',
      verifiedAt: admin.database.ServerValue.TIMESTAMP,
      lastAttemptAt: Date.now(),
      ...(verifiedPurchase.orderId ? { orderId: verifiedPurchase.orderId } : {}),
      ...(expiryTimeMillis != null ? { expiryTimeMillis } : {}),
    };

    const updates = {
      [`users/${authUid}/vip`]: {
        isVip: true,
        vipPlan: productId,
        purchaseSource: source,
        purchaseType: verifiedPurchase.purchaseType,
        purchaseTokenHash: tokenHash,
        verifiedAt: admin.database.ServerValue.TIMESTAMP,
        ...(verifiedPurchase.orderId ? { orderId: verifiedPurchase.orderId } : {}),
        ...(expiryTimeMillis != null
          ? { vipExpiresAt: expiryTimeMillis }
          : { vipExpiresAt: null }),
      },
      [`purchase_verifications/${tokenHash}`]: verificationRecord,
    };

    if (effectiveHouseId) {
      updates[`houses/${effectiveHouseId}/vip`] = {
        isVip: true,
        grantedTo: authUid,
        plan: productId,
        purchaseSource: source,
        purchaseType: verifiedPurchase.purchaseType,
        purchaseTokenHash: tokenHash,
        activatedAt: admin.database.ServerValue.TIMESTAMP,
        ...(verifiedPurchase.orderId ? { orderId: verifiedPurchase.orderId } : {}),
        ...(expiryTimeMillis != null
          ? { vipExpiresAt: expiryTimeMillis }
          : { vipExpiresAt: null }),
      };
      updates[`houses/${effectiveHouseId}/proUntil`] = houseProUntil;
      updates[`houses_public/${effectiveHouseId}/proUntil`] = houseProUntil;
      updates[`house_profiles/${effectiveHouseId}/proUntil`] = houseProUntil;
    }

    await db.ref().update(updates);
    return jsonResponse(res, 200, buildVerifyPurchaseSuccess(verificationRecord, effectiveHouseId));
  } catch (error) {
    try {
      await markPurchaseVerificationFailed({
        db,
        tokenHash,
        record: reservation.record,
        code: normalizeText(error?.message) || 'verify_purchase_failed',
      });
    } catch (markError) {
      console.error('markPurchaseVerificationFailed error:', markError);
    }

    console.error('verifyPurchase failed:', error?.response?.data || error?.message || error);
    return jsonResponse(res, 500, {
      ok: false,
      error: 'verify_purchase_failed',
    });
  }
});

const redeemProPlanHttp = functions
  .runWith({ invoker: 'public' })
  .https.onRequest(async (req, res) => {
    if (req.method === 'OPTIONS') {
      setCorsHeaders(res);
      return res.status(204).send('');
    }

    if (req.method !== 'POST') {
      return jsonResponse(res, 405, { ok: false, error: 'method_not_allowed' });
    }

    let decodedToken;
    try {
      decodedToken = await verifyRequestUser(req);
    } catch (_) {
      return jsonResponse(res, 401, { ok: false, error: 'unauthenticated' });
    }

    try {
      await verifyAppCheckRequest(req);
    } catch (error) {
      const code = normalizeText(error?.message);
      return jsonResponse(res, 403, {
        ok: false,
        error: code === 'missing_app_check' ? 'missing_app_check' : 'invalid_app_check',
      });
    }

    try {
      const body = parseRequestBody(req.body);
      const planId = normalizeRewardPlanId(body.planId || body.plan_id);
      const result = await redeemProPlanForUser({
        uid: decodedToken.uid,
        requestedHouseId: body.houseId,
        planId,
      });
      return jsonResponse(res, 200, {
        ok: true,
        houseId: result.houseId,
        proUntil: result.proUntil,
        points: result.points,
      });
    } catch (error) {
      const code = normalizeText(error?.message);
      if (code === 'invalid_plan') {
        return jsonResponse(res, 400, { ok: false, error: code });
      }
      if (code === 'house_not_found') {
        return jsonResponse(res, 404, { ok: false, error: code });
      }
      if (code === 'house_mismatch' || code === 'forbidden') {
        return jsonResponse(res, 403, { ok: false, error: code });
      }
      if (code === 'not_enough_points') {
        return jsonResponse(res, 409, { ok: false, error: code });
      }
      if (code === 'points_transaction_failed') {
        return jsonResponse(res, 409, { ok: false, error: 'points_sync_retry' });
      }

      console.error('redeemProPlanHttp error:', error);
      return jsonResponse(res, 500, {
        ok: false,
        error: 'redeem_pro_plan_failed',
      });
    }
  });

const createSecretVaultUploadSession = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để tải ảnh kho bí mật.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId cho Secret Vault.',
      );
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    if (!isVipActiveForHouseData(houseData)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Secret Vault yêu cầu PRO đang hoạt động.',
      );
    }

    const contentType = normalizeSecretVaultContentType(data?.contentType);
    const extension = resolveSecretVaultExtension({
      fileName: data?.fileName,
      contentType,
    });
    const now = Date.now();
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const storagePath = `uploads/${uid}/secret_vault/${houseId}/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const expiresAt = now + SECRET_VAULT_UPLOAD_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'secret_vault_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: expiresAt,
      contentType,
      extensionHeaders: headers,
    });

    return {
      ok: true,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl: buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken),
      expiresAt,
    };
  });

const createPublicImageUploadSession = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để tải ảnh công khai.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const target = normalizePublicImageTarget(data?.target);
    if (!requestedHouseId || !target) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId hoặc target cho ảnh công khai.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizePublicImageContentType(data?.contentType);
    const extension = resolvePublicImageExtension({
      fileName: data?.fileName,
      contentType,
    });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const folder = target === 'story'
      ? 'stories'
      : target === 'social_post'
        ? 'feed'
        : target === 'home_avatar'
          ? 'avatars'
          : target === 'house_avatar'
            ? 'profile_avatars'
            : 'profile_headers';
    const sessionRef = admin.database().ref('public_image_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/${folder}/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + PUBLIC_IMAGE_UPLOAD_TTL_MS;
    const finalizeBy = now + PUBLIC_IMAGE_FINALIZE_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'public_image_session',
      'x-goog-meta-public-image-target': target,
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      target,
      status: 'pending',
      storagePath,
      downloadUrl,
      contentType,
      createdAt: now,
      uploadExpiresAt,
      finalizeBy,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl,
      uploadExpiresAt,
      finalizeBy,
    };
  });

const createChatImageUploadSession = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để gửi ảnh chat.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const scope = normalizeChatImageScope(data?.scope);
    if (!requestedHouseId || !scope) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId hoặc kiểu chat cho ảnh.',
      );
    }

    const db = admin.database();
    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeChatImageContentType(data?.contentType);
    const extension = resolveChatImageExtension({
      fileName: data?.fileName,
      contentType,
    });

    let roomId = '';
    let targetHouseId = '';
    if (scope === 'direct') {
      const directChat = await assertDirectChatImageAllowed({
        db,
        houseId,
        houseData,
        targetHouseId: data?.targetHouseId,
      });
      roomId = directChat.roomId;
      targetHouseId = directChat.targetHouseId;
    }

    const quota = await reserveChatImageQuota({
      db,
      uid,
      houseId,
      houseData,
      now,
    });

    try {
      const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
      const sessionRef = db.ref('chat_image_upload_sessions').push();
      const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
      const storagePath = scope === 'internal'
        ? `uploads/${uid}/chat_images/internal/${houseId}/${quota.dayKey}/${fileId}${extension}`
        : `uploads/${uid}/chat_images/direct/${roomId}/${quota.dayKey}/${fileId}${extension}`;
      const downloadToken = crypto.randomUUID();
      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);
      const uploadExpiresAt = now + CHAT_IMAGE_UPLOAD_TTL_MS;
      const finalizeBy = now + CHAT_IMAGE_FINALIZE_TTL_MS;
      const retentionExpiresAt = now + CHAT_IMAGE_RETENTION_MS;
      const headers = {
        'Content-Type': contentType,
        'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
        'x-goog-meta-house-id': houseId,
        'x-goog-meta-owner-uid': uid,
        'x-goog-meta-chat-scope': scope,
        'x-goog-meta-upload-source': 'chat_image_session',
        'x-goog-meta-retention-expires-at': String(retentionExpiresAt),
      };

      if (roomId) {
        headers['x-goog-meta-chat-room-id'] = roomId;
      }
      if (targetHouseId) {
        headers['x-goog-meta-target-house-id'] = targetHouseId;
      }

      const [uploadUrl] = await file.getSignedUrl({
        version: 'v4',
        action: 'write',
        expires: uploadExpiresAt,
        contentType,
        extensionHeaders: headers,
      });

      const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
      await sessionRef.set({
        sessionId,
        uid,
        houseId,
        targetHouseId,
        roomId,
        scope,
        status: 'pending',
        storagePath,
        downloadUrl,
        contentType,
        createdAt: now,
        uploadExpiresAt,
        finalizeBy,
        retentionExpiresAt,
        quotaDayKey: quota.dayKey,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
        plan: quota.isPro ? 'pro' : 'free',
      });

      return {
        ok: true,
        sessionId,
        method: 'PUT',
        uploadUrl,
        headers,
        storagePath,
        downloadUrl,
        uploadExpiresAt,
        finalizeBy,
        expiresAt: retentionExpiresAt,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
      };
    } catch (error) {
      try {
        await rollbackChatImageQuota({
          db,
          uid,
          dayKey: quota.dayKey,
        });
      } catch (_) {}
      throw error;
    }
  });

const createMemoryImageUploadSession = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để tải ảnh Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId cho ảnh Kỷ niệm.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeMemoryImageContentType(data?.contentType);
    const extension = resolveMemoryImageExtension({
      fileName: data?.fileName,
      contentType,
    });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = admin.database().ref('memory_image_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/memories/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + MEMORY_IMAGE_UPLOAD_TTL_MS;
    const finalizeBy = now + MEMORY_IMAGE_FINALIZE_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'memory_image_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'pending',
      storagePath,
      downloadUrl,
      contentType,
      createdAt: now,
      uploadExpiresAt,
      finalizeBy,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl,
      uploadExpiresAt,
      finalizeBy,
    };
  });

const createVoiceUploadSession = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để tải lời nhắn thoại.');
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu houseId cho lời nhắn thoại.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeVoiceContentType(data?.contentType);
    const extension = resolveVoiceExtension({ fileName: data?.fileName, contentType });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = admin.database().ref('voice_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/utilities/voices/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + VOICE_UPLOAD_TTL_MS;
    const finalizeBy = now + VOICE_FINALIZE_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'voice_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'pending',
      storagePath,
      contentType,
      createdAt: now,
      uploadExpiresAt,
      finalizeBy,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      uploadExpiresAt,
      finalizeBy,
    };
  });

const createCreativeDiaryVoiceUploadSession = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để tải ghi âm lên.');
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu thông tin nhà cho bản ghi âm.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeVoiceContentType(data?.contentType);
    const extension = resolveVoiceExtension({ fileName: data?.fileName, contentType });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = admin.database().ref('creative_diary_voice_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/creative_diary_voice/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + CREATIVE_DIARY_VOICE_UPLOAD_TTL_MS;
    const finalizeBy = now + CREATIVE_DIARY_VOICE_FINALIZE_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'creative_diary_voice_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'pending',
      storagePath,
      contentType,
      createdAt: now,
      uploadExpiresAt,
      finalizeBy,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      uploadExpiresAt,
      finalizeBy,
    };
  });

const createAlbumImageUploadSession = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để tải ảnh Album.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId cho Album.',
      );
    }

    const db = admin.database();
    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const isPro = isVipActiveForHouseData(houseData, now);
    const dailyLimit = isPro
      ? ALBUM_IMAGE_PRO_DAILY_LIMIT
      : ALBUM_IMAGE_FREE_DAILY_LIMIT;
    const totalCap = isPro
      ? ALBUM_IMAGE_PRO_TOTAL_CAP
      : ALBUM_IMAGE_FREE_TOTAL_CAP;
    const dayKey = buildAlbumImageDayKey(now);
    const [usageSnapshot, countSnapshot] = await Promise.all([
      db.ref(`album_image_usage/${uid}/${dayKey}`).once('value'),
      db.ref(`houses/${houseId}/albumCount`).once('value'),
    ]);
    const usedToday = Math.max(
      0,
      Math.trunc(Number(asObject(usageSnapshot.val()).count) || 0),
    );
    const currentAlbumCount = Math.max(
      0,
      Math.trunc(Number(countSnapshot.val()) || 0),
    );
    if (usedToday >= dailyLimit) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        isPro
          ? `Bạn đã dùng hết ${dailyLimit} ảnh Album hôm nay.`
          : `Tài khoản thường chỉ tải được ${dailyLimit} ảnh Album/ngày.`,
      );
    }
    if (currentAlbumCount >= totalCap) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        isPro
          ? `Album đã đạt tối đa ${totalCap} ảnh.`
          : `Tài khoản thường chỉ lưu tối đa ${totalCap} ảnh Album.`,
      );
    }
    const contentType = normalizeAlbumImageContentType(data?.contentType);
    const extension = resolveAlbumImageExtension({
      fileName: data?.fileName,
      contentType,
    });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = db.ref('album_image_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/album/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + ALBUM_IMAGE_UPLOAD_TTL_MS;
    const finalizeBy = now + ALBUM_IMAGE_FINALIZE_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'album_image_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'pending',
      storagePath,
      downloadUrl,
      contentType,
      createdAt: now,
      uploadExpiresAt,
      finalizeBy,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl,
      uploadExpiresAt,
      finalizeBy,
      dailyLimit,
      usedToday,
      remainingToday: Math.max(0, dailyLimit - usedToday),
      totalCap,
      albumCount: currentAlbumCount,
    };
  });

const createGiftImageUploadSession = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để tải ảnh quà.');
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu houseId cho ảnh quà.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeAlbumImageContentType(data?.contentType);
    const extension = resolveAlbumImageExtension({
      fileName: data?.fileName,
      contentType,
    });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = admin.database().ref('gift_image_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/gifts/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + ALBUM_IMAGE_UPLOAD_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'gift_image_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'uploaded',
      storagePath,
      downloadUrl,
      contentType,
      createdAt: now,
      uploadExpiresAt,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl,
      uploadExpiresAt,
    };
  });

const createLoveCardImageUploadSession = functions
  .https.onCall(async (data, context) => { 
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để tải ảnh thiệp.');
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu houseId cho ảnh thiệp.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    const now = Date.now();
    const contentType = normalizeAlbumImageContentType(data?.contentType);
    const extension = resolveAlbumImageExtension({
      fileName: data?.fileName,
      contentType,
    });
    const fileId = `${now}_${crypto.randomBytes(5).toString('hex')}`;
    const sessionRef = admin.database().ref('love_card_image_upload_sessions').push();
    const sessionId = normalizeText(sessionRef.key) || `${now}_${crypto.randomBytes(6).toString('hex')}`;
    const storagePath = `uploads/${uid}/houses/${houseId}/love_cards/${fileId}${extension}`;
    const downloadToken = crypto.randomUUID();
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const uploadExpiresAt = now + ALBUM_IMAGE_UPLOAD_TTL_MS;
    const headers = {
      'Content-Type': contentType,
      'x-goog-meta-firebaseStorageDownloadTokens': downloadToken,
      'x-goog-meta-house-id': houseId,
      'x-goog-meta-owner-uid': uid,
      'x-goog-meta-upload-source': 'love_card_image_session',
    };

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: uploadExpiresAt,
      contentType,
      extensionHeaders: headers,
    });

    const downloadUrl = buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken);
    await sessionRef.set({
      sessionId,
      uid,
      houseId,
      status: 'uploaded',
      storagePath,
      downloadUrl,
      contentType,
      createdAt: now,
      uploadExpiresAt,
    });

    return {
      ok: true,
      sessionId,
      method: 'PUT',
      uploadUrl,
      headers,
      storagePath,
      downloadUrl,
      uploadExpiresAt,
    };
  });

const finalizeChatImageMessage = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để hoàn tất gửi ảnh chat.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin để hoàn tất ảnh chat.',
      );
    }

    const db = admin.database();
    const sessionRef = db.ref(`chat_image_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy phiên gửi ảnh chat.',
      );
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bạn không có quyền dùng phiên gửi ảnh này.',
      );
    }

    const currentStatus = normalizeText(session.status).toLowerCase();
    if (currentStatus === 'finalized') {
      return {
        ok: true,
        alreadyFinalized: true,
        messageId: normalizeText(session.messageId),
        expiresAt: toTimestamp(session.retentionExpiresAt),
      };
    }

    if (currentStatus !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên gửi ảnh chat không còn hợp lệ.',
      );
    }

    const sessionHouseId = normalizeText(session.houseId);
    if (requestedHouseId && requestedHouseId !== sessionHouseId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'houseId không khớp với phiên gửi ảnh.',
      );
    }

    const now = Date.now();
    if (toTimestamp(session.finalizeBy) > 0 && toTimestamp(session.finalizeBy) <= now) {
      await sessionRef.update({
        status: 'expired',
        expiredAt: now,
        expiredReason: 'finalize_timeout',
      });
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên gửi ảnh chat đã hết hạn, vui lòng chọn lại ảnh.',
      );
    }

    const claimedStatus = await sessionRef.transaction((value) => {
      const currentSession = value && typeof value === 'object' ? value : session;
      if (normalizeText(currentSession.status).toLowerCase() !== 'pending') {
        return undefined;
      }
      return {
        ...currentSession,
        status: 'finalizing',
      };
    });
    if (!claimedStatus.committed) {
      const latestSnapshot = await sessionRef.once('value');
      const latestSession = asObject(latestSnapshot.val());
      if (normalizeText(latestSession.status).toLowerCase() === 'finalized') {
        return {
          ok: true,
          alreadyFinalized: true,
          messageId: normalizeText(latestSession.messageId),
          expiresAt: toTimestamp(latestSession.retentionExpiresAt),
        };
      }
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên gửi ảnh chat đang được xử lý hoặc đã hết hạn.',
      );
    }

    let shouldRestorePending = true;
    try {
      const { houseId, houseData } = await resolveMemberHouse(uid, sessionHouseId);
      const scope = normalizeChatImageScope(session.scope);
      const bucket = admin.storage().bucket();
      const storagePath = normalizeText(session.storagePath);
      const downloadUrl = normalizeText(session.downloadUrl);
      const retentionExpiresAt = toTimestamp(session.retentionExpiresAt) > now
        ? toTimestamp(session.retentionExpiresAt)
        : now + CHAT_IMAGE_RETENTION_MS;
      const [exists] = await bucket.file(storagePath).exists();
      if (!exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Ảnh chưa tải lên hoàn tất.',
        );
      }

      let senderId = houseId;
      let messageId = '';
      let messagePath = '';
      let lastMessagePath = '';
      const updates = {};

      if (scope === 'direct') {
        const directChat = await assertDirectChatImageAllowed({
          db,
          houseId,
          houseData,
          targetHouseId: session.targetHouseId,
        });
        const roomId = normalizeText(session.roomId) || directChat.roomId;
        await ensureDirectChatRoomMetadata({
          db,
          myHouseId: houseId,
          targetHouseId: directChat.targetHouseId,
          roomId,
        });

        messageId = normalizeText(db.ref(`chats/${roomId}/messages`).push().key);
        messagePath = `chats/${roomId}/messages/${messageId}`;
        lastMessagePath = `chats/${roomId}/lastMessage`;
        updates[`chats/${roomId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
      } else if (scope === 'internal') {
        senderId = normalizeChatSenderRole(data?.senderRole);
        messageId = normalizeText(db.ref(`houses/${houseId}/chat_room/messages`).push().key);
        messagePath = `houses/${houseId}/chat_room/messages/${messageId}`;
        lastMessagePath = `houses/${houseId}/chat_room/lastMessage`;
        updates[`houses/${houseId}/chat_room/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
      } else {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Kiểu chat của ảnh không hợp lệ.',
        );
      }

      if (!messageId || !messagePath || !lastMessagePath) {
        throw new functions.https.HttpsError(
          'internal',
          'Không thể tạo tin nhắn ảnh chat.',
        );
      }

      updates[messagePath] = {
        senderId,
        text: downloadUrl,
        type: 'image',
        ts: now,
        isRead: false,
        storagePath,
        expiresAt: retentionExpiresAt,
        imageStatus: 'active',
      };
      updates[lastMessagePath] = {
        text: '[Hình ảnh]',
        ts: now,
        senderId,
        isRead: false,
        type: 'image',
        messageId,
        expiresAt: retentionExpiresAt,
        imageStatus: 'active',
      };
      updates[`chat_image_retention/${sessionId}`] = {
        sessionId,
        scope,
        houseId,
        targetHouseId: normalizeText(session.targetHouseId),
        roomId: normalizeText(session.roomId),
        messageId,
        messagePath,
        lastMessagePath,
        storagePath,
        expiresAt: retentionExpiresAt,
        createdAt: now,
      };
      updates[`chat_image_upload_sessions/${sessionId}/status`] = 'finalized';
      updates[`chat_image_upload_sessions/${sessionId}/messageId`] = messageId;
      updates[`chat_image_upload_sessions/${sessionId}/messagePath`] = messagePath;
      updates[`chat_image_upload_sessions/${sessionId}/lastMessagePath`] = lastMessagePath;
      updates[`chat_image_upload_sessions/${sessionId}/finalizedAt`] = now;
      updates[`chat_image_upload_sessions/${sessionId}/finalizeBy`] =
        retentionExpiresAt + CHAT_IMAGE_RETENTION_MS;
      updates[`chat_image_upload_sessions/${sessionId}/imageStatus`] = 'active';

      await db.ref().update(updates);
      shouldRestorePending = false;
      return {
        ok: true,
        messageId,
        expiresAt: retentionExpiresAt,
      };
    } catch (error) {
      if (shouldRestorePending) {
        try {
          await sessionRef.update({
            status: 'pending',
            finalizeErrorAt: now,
            finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
          });
        } catch (_) {}
      }
      throw error;
    }
  });

const finalizeMemoryImageUpload = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để hoàn tất ảnh Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!sessionId || !requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin để hoàn tất ảnh Kỷ niệm.',
      );
    }

    const db = admin.database();
    const sessionRef = db.ref(`memory_image_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy phiên tải ảnh Kỷ niệm.',
      );
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bạn không có quyền dùng phiên tải ảnh Kỷ niệm này.',
      );
    }

    const now = Date.now();
    const currentStatus = normalizeText(session.status).toLowerCase();
    if (currentStatus === 'finalized') {
      return {
        ok: true,
        alreadyFinalized: true,
        memoryId: normalizeText(session.memoryId),
      };
    }
    if (currentStatus !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên tải ảnh Kỷ niệm đang được xử lý hoặc không còn hợp lệ.',
      );
    }
    if (false && toTimestamp(session.finalizeBy) > 0 && now > toTimestamp(session.finalizeBy)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên tải ảnh Kỷ niệm đã hết hạn.',
      );
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    if (normalizeText(session.houseId) !== houseId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Phiên tải ảnh Kỷ niệm không thuộc nhà này.',
      );
    }

    const storagePath = normalizeText(session.storagePath);
    if (!isMemoryStoragePath(storagePath, uid, houseId)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Đường dẫn ảnh Kỷ niệm không hợp lệ.',
      );
    }

    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Ảnh Kỷ niệm chưa tải lên hoàn tất.',
      );
    }

    const authorId = uid;
    const authorName = normalizeText(data?.authorName).slice(0, 120);
    const authorEmail = normalizeText(data?.authorEmail).toLowerCase().slice(0, 160);
    const authorRole = normalizeText(data?.authorRole).slice(0, 40);
    const lat = Number(data?.lat);
    const lng = Number(data?.lng);
    const hasLatLng = Number.isFinite(lat) && Number.isFinite(lng);

    let quota = null;
    let shouldRestorePending = true;
    try {
      await sessionRef.update({
        status: 'finalizing',
        finalizingAt: now,
      });

      quota = await reserveMemoryImageQuota({
        db,
        uid,
        houseId,
        now,
      });

      await sessionRef.update({
        quotaDayKey: quota.dayKey,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
        plan: quota.isPro ? 'pro' : 'free',
      });

      const memoryRef = db.ref(`houses/${houseId}/memories`).push();
      const memoryId = normalizeText(memoryRef.key);
      if (!memoryId) {
        throw new functions.https.HttpsError('internal', 'Không thể tạo ID ảnh Kỷ niệm.');
      }

      const memoryData = {
        ts: now,
        date: now,
        author: authorName,
        authorId,
        authorName,
        ...(authorEmail ? { authorEmail } : {}),
        ...(authorRole ? { authorRole } : {}),
        ...(hasLatLng ? { lat, lng } : {}),
        storagePath,
        uploadSessionId: sessionId,
        mediaKind: 'memory_image',
        source: 'functions',
      };

      const temporaryUrl = await createTemporaryReadUrl(bucket, storagePath);
      memoryData.url = temporaryUrl;
      memoryData.urlExpiresAt = now + PRIVATE_MEDIA_READ_TTL_MS;
      memoryData.storageAccess = 'signed';
      memoryData.privateMedia = true;
      memoryData.storageKey = storagePath;

      try {
        const thumbnail = await createMemoryThumbnail({
          bucket,
          storagePath,
        });
        if (thumbnail?.thumbUrl) {
          memoryData.thumbUrl = thumbnail.thumbUrl;
          memoryData.previewUrl = thumbnail.thumbUrl;
          memoryData.thumbPath = thumbnail.thumbPath;
          memoryData.thumbContentType = thumbnail.thumbContentType;
        }
      } catch (thumbnailError) {
        console.warn('Unable to create memory thumbnail:', thumbnailError?.message || thumbnailError);
      }

      const updates = {
        [`houses/${houseId}/memories/${memoryId}`]: memoryData,
        [`houses/${houseId}/memoriesCount`]: admin.database.ServerValue.increment(1),
        [`memory_image_upload_sessions/${sessionId}/status`]: 'finalized',
        [`memory_image_upload_sessions/${sessionId}/finalizedAt`]: now,
        [`memory_image_upload_sessions/${sessionId}/memoryId`]: memoryId,
        [`memory_image_upload_sessions/${sessionId}/memoryPath`]: `houses/${houseId}/memories/${memoryId}`,
      };
      await db.ref().update(updates);
      shouldRestorePending = false;

      return {
        ok: true,
        memoryId,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
        data: memoryData,
      };
    } catch (error) {
      if (quota?.dayKey) {
        try {
          await rollbackMemoryImageQuota({
            db,
            uid,
            dayKey: quota.dayKey,
          });
        } catch (_) {}
      }
      if (shouldRestorePending) {
        try {
          await sessionRef.update({
            status: 'pending',
            finalizeErrorAt: now,
            finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
          });
        } catch (_) {}
      }
      throw error;
    }
  });

const finalizeVoiceUpload = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để hoàn tất lời nhắn thoại.');
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    const authorName = normalizeText(data?.authorName).slice(0, 120);
    const fileName = normalizeText(data?.fileName).slice(0, 240);
    const mimeType = normalizeVoiceContentType(data?.mimeType || data?.contentType);
    const durationMs = toTimestamp(data?.durationMs);
    const size = toTimestamp(data?.size);
    if (!sessionId || !requestedHouseId || !authorName || durationMs <= 0 || size <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu dữ liệu hoàn tất lời nhắn thoại.');
    }

    const db = admin.database();
    const sessionRef = db.ref(`voice_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError('not-found', 'Không tìm thấy phiên tải thoại.');
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Bạn không có quyền dùng phiên tải thoại này.');
    }

    const now = Date.now();
    if (normalizeText(session.status).toLowerCase() === 'finalized') {
      return { ok: true, voiceId: normalizeText(session.voiceId) };
    }
    if (toTimestamp(session.finalizeBy) > 0 && now > toTimestamp(session.finalizeBy)) {
      throw new functions.https.HttpsError('failed-precondition', 'Phiên tải thoại đã hết hạn.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    if (normalizeText(session.houseId) !== houseId) {
      throw new functions.https.HttpsError('permission-denied', 'Phiên tải thoại không thuộc nhà này.');
    }

    const storagePath = normalizeText(session.storagePath);
    if (!isVoiceStoragePath(storagePath, uid, houseId)) {
      throw new functions.https.HttpsError('failed-precondition', 'Đường dẫn audio không hợp lệ.');
    }

    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Audio chưa tải lên hoàn tất.');
    }

    await sessionRef.update({ status: 'finalizing', finalizingAt: now });

    try {
      const voiceRef = db.ref(`houses/${houseId}/utilities/voices`).push();
      const voiceId = normalizeText(voiceRef.key);
      if (!voiceId) {
        throw new functions.https.HttpsError('internal', 'Không thể tạo ID lời nhắn thoại.');
      }

      const temporaryUrl = await createTemporaryReadUrl(bucket, storagePath);
      const voiceData = {
        a: authorName,
        aud: temporaryUrl,
        audExpiresAt: now + PRIVATE_MEDIA_READ_TTL_MS,
        storageAccess: 'signed',
        privateMedia: true,
        mediaKind: 'voice',
        source: 'functions',
        ts: now,
        mime: mimeType,
        duration: durationMs,
        name: fileName,
        size,
        storagePath,
        storageKey: storagePath,
        uploadSessionId: sessionId,
        ownerUid: uid,
      };

      const updates = {
        [`houses/${houseId}/utilities/voices/${voiceId}`]: voiceData,
        [`voice_upload_sessions/${sessionId}/status`]: 'finalized',
        [`voice_upload_sessions/${sessionId}/finalizedAt`]: now,
        [`voice_upload_sessions/${sessionId}/voiceId`]: voiceId,
      };
      await db.ref().update(updates);
      return { ok: true, voiceId, data: voiceData };
    } catch (error) {
      try {
        await sessionRef.update({
          status: 'pending',
          finalizeErrorAt: now,
          finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
        });
      } catch (_) {}
      throw error;
    }
  });

const finalizeCreativeDiaryVoiceUpload = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để lưu trang sáng tạo.');
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    const content = normalizeText(data?.content).slice(0, 20000);
    const metadata = asObject(data?.metadata);
    const fileName = normalizeText(data?.fileName).slice(0, 240);
    const mimeType = normalizeVoiceContentType(data?.mimeType || data?.contentType);
    if (!sessionId || !requestedHouseId || !content) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu dữ liệu lưu trang sáng tạo.');
    }

    const db = admin.database();
    const sessionRef = db.ref(`creative_diary_voice_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError('not-found', 'Không tìm thấy lượt tải ghi âm này.');
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Bạn không có quyền hoàn tất lượt tải ghi âm này.');
    }

    const now = Date.now();
    if (normalizeText(session.status).toLowerCase() === 'finalized') {
      return { ok: true, entryId: normalizeText(session.entryId) };
    }
    if (toTimestamp(session.finalizeBy) > 0 && now > toTimestamp(session.finalizeBy)) {
      throw new functions.https.HttpsError('failed-precondition', 'Lượt tải ghi âm này đã hết hạn.');
    }

    const { houseId, houseData } = await resolveMemberHouse(uid, requestedHouseId);
    if (normalizeText(session.houseId) !== houseId) {
      throw new functions.https.HttpsError('permission-denied', 'Lượt tải ghi âm này không thuộc ngôi nhà hiện tại.');
    }

    const storagePath = normalizeText(session.storagePath);
    if (!isVoiceStoragePath(storagePath, uid, houseId, 'creative_diary_voice')) {
      throw new functions.https.HttpsError('failed-precondition', 'Tệp ghi âm không hợp lệ.');
    }

    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Bản ghi âm vẫn chưa tải lên xong.');
    }

    await sessionRef.update({ status: 'finalizing', finalizingAt: now });

    try {
      const entryRef = db.ref(`houses/${houseId}/creative_diary`).push();
      const entryId = normalizeText(entryRef.key);
      if (!entryId) {
        throw new functions.https.HttpsError('internal', 'Không thể tạo trang sáng tạo.');
      }

      const entryData = {
        content,
        metadata,
        voiceUrl: normalizeText(session.downloadUrl),
        voiceStoragePath: storagePath,
        voiceUploadSessionId: sessionId,
        voiceName: fileName,
        voiceMime: mimeType,
        timestamp: now,
      };

      const updates = {
        [`houses/${houseId}/creative_diary/${entryId}`]: entryData,
        [`creative_diary_voice_upload_sessions/${sessionId}/status`]: 'finalized',
        [`creative_diary_voice_upload_sessions/${sessionId}/finalizedAt`]: now,
        [`creative_diary_voice_upload_sessions/${sessionId}/entryId`]: entryId,
      };
      await db.ref().update(updates);
      return { ok: true, entryId, data: entryData };
    } catch (error) {
      try {
        await sessionRef.update({
          status: 'pending',
          finalizeErrorAt: now,
          finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
        });
      } catch (_) {}
      throw error;
    }
  });

const deleteVoiceMessage = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Đăng nhập để xóa lời nhắn thoại.');
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const voiceId = normalizeText(data?.voiceId);
    if (!requestedHouseId || !voiceId) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu dữ liệu xóa lời nhắn thoại.');
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const voiceRef = db.ref(`houses/${houseId}/utilities/voices/${voiceId}`);
    const voiceSnapshot = await voiceRef.once('value');
    if (!voiceSnapshot.exists()) {
      return { ok: true, alreadyDeleted: true };
    }

    const voice = asObject(voiceSnapshot.val());
    const storagePath = normalizeText(voice.storagePath);
    if (storagePath && isVoiceStoragePath(storagePath, normalizeText(voice.ownerUid), houseId)) {
      await deleteStorageObjectIfExists(admin.storage().bucket(), storagePath);
    }

    await voiceRef.remove();
    return { ok: true };
  });

const finalizePublicImageUpload = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để hoàn tất ảnh công khai.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!sessionId || !requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin để hoàn tất ảnh công khai.',
      );
    }

    const db = admin.database();
    const sessionRef = db.ref(`public_image_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy phiên tải ảnh công khai.',
      );
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bạn không có quyền dùng phiên tải ảnh này.',
      );
    }

    const now = Date.now();
    const currentStatus = normalizeText(session.status).toLowerCase();
    if (currentStatus === 'finalized') {
      return {
        ok: true,
        alreadyFinalized: true,
        target: normalizeText(session.target),
        downloadUrl: normalizeText(session.downloadUrl),
      };
    }
    if (currentStatus !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên tải ảnh công khai không còn hợp lệ.',
      );
    }
    if (toTimestamp(session.finalizeBy) > 0 && now > toTimestamp(session.finalizeBy)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên tải ảnh công khai đã hết hạn.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    if (normalizeText(session.houseId) !== houseId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Phiên tải ảnh không thuộc nhà này.',
      );
    }

    const target = normalizePublicImageTarget(session.target);
    if (!target) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Loại ảnh công khai không hợp lệ.',
      );
    }

    const storagePath = normalizeText(session.storagePath);
    const downloadUrl = normalizeText(session.downloadUrl);
    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Ảnh chưa tải lên hoàn tất.',
      );
    }

    await sessionRef.update({
      status: 'finalizing',
      finalizingAt: now,
    });

    try {
      const updates = {
        [`public_image_upload_sessions/${sessionId}/status`]: 'finalized',
        [`public_image_upload_sessions/${sessionId}/finalizedAt`]: now,
      };

      if (target === 'home_avatar') {
        const role = normalizeText(data?.role) === 'user2' ? 'user2' : 'user1';
        const field = role === 'user2' ? 'avtUser2' : 'avtUser1';
        updates[`houses/${houseId}/settings/${field}`] = downloadUrl;
        updates[`house_profiles/${houseId}/${field}`] = downloadUrl;
        updates[`house_profiles/${houseId}/settings/${field}`] = downloadUrl;
        updates[`houses/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
      } else if (target === 'house_avatar') {
        updates[`houses/${houseId}/settings/houseAvatar`] = downloadUrl;
        updates[`houses/${houseId}/avatar`] = downloadUrl;
        updates[`houses/${houseId}/houseAvatar`] = downloadUrl;
        updates[`house_profiles/${houseId}/avatar`] = downloadUrl;
        updates[`house_profiles/${houseId}/houseAvatar`] = downloadUrl;
        updates[`house_profiles/${houseId}/settings/houseAvatar`] = downloadUrl;
        updates[`houses_public/${houseId}/avatar`] = downloadUrl;
        updates[`houses_public/${houseId}/houseAvatar`] = downloadUrl;
        updates[`houses_public/${houseId}/settings/houseAvatar`] = downloadUrl;
        updates[`houses/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
      } else if (target === 'profile_header') {
        updates[`houses/${houseId}/settings/profileHeaderImageUrl`] = downloadUrl;
        updates[`house_profiles/${houseId}/profileHeaderImageUrl`] = downloadUrl;
        updates[`house_profiles/${houseId}/settings/profileHeaderImageUrl`] = downloadUrl;
        updates[`houses_public/${houseId}/profileHeaderImageUrl`] = downloadUrl;
        updates[`houses_public/${houseId}/settings/profileHeaderImageUrl`] = downloadUrl;
        updates[`houses/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`house_profiles/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updatedAt`] = admin.database.ServerValue.TIMESTAMP;
        updates[`houses_public/${houseId}/updated_at`] = admin.database.ServerValue.TIMESTAMP;
      } else if (target === 'story') {
        const storyRef = db.ref(`houses/${houseId}/stories`).push();
        const storyId = normalizeText(storyRef.key);
        if (!storyId) {
          throw new functions.https.HttpsError('internal', 'Không thể tạo ID story.');
        }
        updates[`houses/${houseId}/stories/${storyId}`] = {
          url: downloadUrl,
          author: normalizeText(data?.authorName).slice(0, 120),
          ts: admin.database.ServerValue.TIMESTAMP,
          expiresAt: now + (24 * 60 * 60 * 1000),
          storagePath,
          uploadSessionId: sessionId,
        };
        updates[`public_image_upload_sessions/${sessionId}/storyId`] = storyId;
      } else if (target === 'social_post') {
        const content = normalizeText(data?.content);
        const privacy = normalizeText(data?.privacy) || 'public';
        const mood = normalizeText(data?.mood).slice(0, 80);
        const moodEmoji = normalizeText(data?.moodEmoji).slice(0, 16);
        const location = normalizeText(data?.location).slice(0, 160);
        const postType = normalizeText(data?.postType) || 'mood';
        const authorName = normalizeText(data?.authorName).slice(0, 120);
        const authorAvt = normalizeText(data?.authorAvt);
        const houseName = normalizeText(data?.houseName).slice(0, 120);
        const authorRole = normalizeText(data?.authorRole).slice(0, 128);
        const isAnon = data?.isAnon === true;
        const isLocket = data?.isLocket === true;
        const commentsEnabled = data?.commentsEnabled !== false;
        const flagged = data?.flagged === true;
        const resolvedPrivacy = flagged ? 'private' : privacy;
        const postRef = db.ref('social_feed').push();
        const postId = normalizeText(postRef.key);
        if (!postId) {
          throw new functions.https.HttpsError('internal', 'Không thể tạo ID bài viết.');
        }
        updates[`social_feed/${postId}`] = {
          houseId,
          houseName,
          author_uid: uid,
          authorRole,
          authorName,
          authorAvt,
          houseAvt: authorAvt,
          content,
          imageUrl: downloadUrl,
          imageStoragePath: storagePath,
          imageUploadSessionId: sessionId,
          videoUrl: '',
          likes: 0,
          commentCount: 0,
          shareCount: 0,
          hotScore: 0,
          ts: now,
          privacy: resolvedPrivacy,
          visibility: resolvedPrivacy,
          mood,
          moodEmoji,
          location,
          postType,
          isAnon,
          isLocket,
          commentsEnabled,
          ...(flagged ? { moderationStatus: 'flagged' } : {}),
          isRepost: false,
          id: postId,
        };
        updates[`public_image_upload_sessions/${sessionId}/postId`] = postId;
      }

      await db.ref().update(updates);
      return {
        ok: true,
        target,
        downloadUrl,
      };
    } catch (error) {
      try {
        await sessionRef.update({
          status: 'pending',
          finalizeErrorAt: now,
          finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
        });
      } catch (_) {}
      throw error;
    }
  });

function normalizeMemorySharePhoto(rawPhoto, index) {
  const item = asObject(rawPhoto);
  const url = normalizeText(item.url).slice(0, 2048);
  if (!url || !/^https?:\/\//i.test(url)) {
    return null;
  }

  const parsedUrl = new URL(url);
  if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
    return null;
  }

  return {
    id: normalizeText(item.id).slice(0, 160) || `photo_${index}`,
    url,
    previewUrl: normalizeText(
      item.previewUrl || item.thumbUrl || item.thumbnailUrl || item.url,
    ).slice(0, 2048) || url,
    ts: toTimestamp(item.ts || item.timestamp || item.date),
    authorName: normalizeText(item.authorName).slice(0, 80),
    order: index,
  };
}

function sanitizeMemoryShareForPublic(record, token) {
  const photos = Array.isArray(record.photos) ? record.photos : [];
  const title = normalizeText(record.title).slice(0, 120) || 'Kỷ niệm của chúng mình';
  const description = normalizeText(record.description).slice(0, 280) ||
    'SoulLocket lưu giữ những khoảnh khắc riêng tư của hai bạn và biến chúng thành album kỷ niệm dễ chia sẻ.';
  const brandLabel = normalizeText(record.brandLabel).slice(0, 80) || 'SoulLocket Memories';
  const theme = normalizeText(record.theme).slice(0, 40) || 'soullocket_dream';
  return {
    ok: true,
    token,
    createdAt: toTimestamp(record.createdAt),
    expiresAt: toTimestamp(record.expiresAt),
    photoCount: Math.max(0, Math.trunc(Number(record.photoCount) || photos.length)),
    title,
    description,
    brandLabel,
    theme,
    photos: photos.map((photo, index) => normalizeMemorySharePhoto(photo, index)).filter(Boolean),
  };
}

function buildMemoryShareHtml(payload) {
  const photos = Array.isArray(payload.photos) ? payload.photos : [];
  const title = escapeHtml(payload.title || 'Kỷ niệm của chúng mình');
  const description = escapeHtml(payload.description || 'SoulLocket lưu giữ những khoảnh khắc riêng tư của hai bạn và biến chúng thành album kỷ niệm dễ chia sẻ.');
  const brandLabel = escapeHtml(payload.brandLabel || 'SoulLocket Memories');
  const expires = payload.expiresAt > 0
    ? new Date(payload.expiresAt).toLocaleDateString('vi-VN')
    : 'không giới hạn';
  const createdAt = payload.createdAt > 0
    ? new Date(payload.createdAt).toLocaleDateString('vi-VN')
    : '';
  const lightboxItems = JSON.stringify(photos.map((photo, index) => {
    const date = photo.ts > 0 ? new Date(photo.ts).toLocaleDateString('vi-VN') : '';
    const author = normalizeText(photo.authorName);
    return {
      url: photo.url,
      caption: [date, author].filter(Boolean).join(' • ') || `Kỷ niệm ${index + 1}`,
    };
  })).replace(/</g, '\\u003c');
  const heroPreview = photos.slice(0, 4).map((photo, index) => {
    return `<button class="preview-tile preview-${index + 1}" type="button" data-index="${index}" aria-label="Mở ảnh nổi bật ${index + 1}"><img src="${escapeHtml(photo.previewUrl || photo.url)}" loading="lazy" alt="Ảnh nổi bật ${index + 1}"></button>`;
  }).join('');
  const heroPreviewContent = heroPreview ||
    '<div class="preview-empty">Chưa có ảnh hiển thị</div>';
  const photoCards = photos.map((photo, index) => {
    const date = photo.ts > 0 ? new Date(photo.ts).toLocaleDateString('vi-VN') : '';
    const author = normalizeText(photo.authorName);
    const meta = [date, author].filter(Boolean).join(' • ');
    return `<figure class="card"><button class="media-wrap" type="button" data-index="${index}" data-src="${escapeHtml(photo.url)}" data-caption="${escapeHtml(meta || `Kỷ niệm ${index + 1}`)}" aria-label="Mở ảnh kỷ niệm ${index + 1}"><img src="${escapeHtml(photo.previewUrl || photo.url)}" loading="lazy" alt="Kỷ niệm ${index + 1}"><span class="media-shine"></span><span class="media-open">Xem ảnh</span></button><figcaption><span class="caption-index">Kỷ niệm ${index + 1}</span><span class="caption-meta">${escapeHtml(meta || 'Khoảnh khắc được lưu giữ')}</span></figcaption></figure>`;
  }).join('');

  return `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${title} • SoulLocket</title>
  <meta name="description" content="${description}">
  <style>
    :root {
      color-scheme: light;
      --bg-1: #fff0f6;
      --bg-2: #eef6ff;
      --bg-3: #f4efff;
      --text: #2a2440;
      --muted: #6e6a86;
      --card: rgba(255,255,255,0.78);
      --stroke: rgba(255,255,255,0.72);
      --shadow: 0 24px 60px rgba(94, 76, 154, 0.18);
      --pink: #ff5fa2;
      --purple: #8e7dff;
      --blue: #6ec7ff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(255,132,187,0.32), transparent 34%),
        radial-gradient(circle at top right, rgba(110,199,255,0.30), transparent 28%),
        radial-gradient(circle at 50% 85%, rgba(142,125,255,0.18), transparent 30%),
        linear-gradient(135deg, var(--bg-1), var(--bg-2) 48%, var(--bg-3));
      overflow-x: hidden;
    }
    .backdrop {
      position: fixed;
      inset: 0;
      pointer-events: none;
      overflow: hidden;
    }
    .blob {
      position: absolute;
      border-radius: 999px;
      filter: blur(8px);
      opacity: .58;
    }
    .blob.one { width: 240px; height: 240px; background: rgba(255,95,162,.22); top: 54px; left: -40px; }
    .blob.two { width: 300px; height: 300px; background: rgba(110,199,255,.18); top: 160px; right: -70px; }
    .blob.three { width: 280px; height: 280px; background: rgba(142,125,255,.16); bottom: 90px; left: 50%; transform: translateX(-50%); }
    .shell {
      position: relative;
      max-width: 1180px;
      margin: 0 auto;
      padding: 28px 16px 48px;
    }
    .hero {
      position: relative;
      overflow: hidden;
      border-radius: 32px;
      background: linear-gradient(145deg, rgba(255,255,255,.86), rgba(255,255,255,.64));
      border: 1px solid var(--stroke);
      box-shadow: var(--shadow);
      backdrop-filter: blur(18px);
      padding: 28px 20px 22px;
    }
    .hero::after {
      content: "";
      position: absolute;
      width: 220px;
      height: 220px;
      right: -60px;
      top: -80px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(255,95,162,.22), transparent 68%);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 14px;
      border-radius: 999px;
      background: rgba(255,255,255,.74);
      border: 1px solid rgba(255,255,255,.88);
      color: #9a4b7d;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    .hero h1 {
      margin: 18px 0 10px;
      font-size: clamp(30px, 5vw, 48px);
      line-height: 1.08;
      letter-spacing: -.03em;
    }
    .hero p {
      margin: 0;
      max-width: 700px;
      color: var(--muted);
      font-size: 15px;
      line-height: 1.7;
    }
    .stat-row {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 22px;
    }
    .stat {
      min-width: 130px;
      padding: 14px 16px;
      border-radius: 22px;
      background: rgba(255,255,255,.72);
      border: 1px solid rgba(255,255,255,.82);
      box-shadow: 0 10px 28px rgba(98, 88, 140, 0.08);
    }
    .stat-label {
      display: block;
      margin-bottom: 6px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: .06em;
    }
    .stat-value {
      display: block;
      font-size: 18px;
      font-weight: 800;
    }
    .intro {
      display: grid;
      grid-template-columns: 1.15fr .85fr;
      gap: 18px;
      margin-top: 20px;
    }
    .panel {
      border-radius: 28px;
      background: var(--card);
      border: 1px solid rgba(255,255,255,.8);
      box-shadow: 0 16px 42px rgba(106, 93, 153, .10);
      backdrop-filter: blur(16px);
      padding: 18px;
    }
    .panel h2 {
      margin: 0 0 10px;
      font-size: 18px;
    }
    .panel p {
      margin: 0;
      color: var(--muted);
      line-height: 1.7;
      font-size: 14px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(165px, 1fr));
      gap: 14px;
      margin-top: 22px;
    }
    .card {
      margin: 0;
      overflow: hidden;
      border-radius: 26px;
      background: rgba(255,255,255,.82);
      border: 1px solid rgba(255,255,255,.84);
      box-shadow: 0 16px 38px rgba(75, 60, 120, .12);
      transition: transform .2s ease, box-shadow .2s ease;
    }
    .card:hover { transform: translateY(-5px) scale(1.01); box-shadow: 0 26px 54px rgba(75, 60, 120, .20); }
    .card:hover img { transform: scale(1.045); }
    .media-wrap {
      position: relative;
      display: block;
      width: 100%;
      border: 0;
      padding: 0;
      cursor: zoom-in;
      aspect-ratio: 1 / 1;
      overflow: hidden;
      background: linear-gradient(135deg, rgba(255,95,162,.16), rgba(110,199,255,.16));
    }
    .card img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
      transition: transform .28s ease;
    }
    .card figcaption {
      display: grid;
      gap: 6px;
      padding: 12px 13px 14px;
    }
    .caption-index {
      color: var(--pink);
      font-size: 12px;
      font-weight: 800;
      letter-spacing: .05em;
      text-transform: uppercase;
    }
    .caption-meta {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
      min-height: 18px;
    }
    .empty {
      margin-top: 20px;
      padding: 38px 18px;
      text-align: center;
      border-radius: 28px;
      background: rgba(255,255,255,.7);
      border: 1px solid rgba(255,255,255,.82);
      color: var(--muted);
      box-shadow: 0 14px 36px rgba(75, 60, 120, .10);
    }
    .footer {
      padding: 26px 10px 8px;
      text-align: center;
      color: var(--muted);
      font-size: 12px;
    }
    @media (max-width: 820px) {
      .intro { grid-template-columns: 1fr; }
      .hero { padding: 24px 16px 20px; border-radius: 28px; }
    }
    @media (max-width: 560px) {
      .shell { padding: 18px 12px 32px; }
      .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .stat { flex: 1 1 calc(50% - 12px); min-width: 0; }
      .hero h1 { font-size: 28px; }
      .hero p, .panel p { font-size: 14px; }
    }
    .lightbox {
      position: fixed;
      inset: 0;
      z-index: 20;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 18px;
      background: rgba(21, 16, 35, .82);
      backdrop-filter: blur(18px);
    }
    .lightbox.open { display: flex; }
    .lightbox-inner {
      position: relative;
      width: min(100%, 980px);
      max-height: 92vh;
      border-radius: 28px;
      overflow: hidden;
      background: rgba(255,255,255,.12);
      border: 1px solid rgba(255,255,255,.24);
      box-shadow: 0 30px 90px rgba(0,0,0,.36);
    }
    .lightbox img {
      display: block;
      width: 100%;
      max-height: 82vh;
      object-fit: contain;
      background: rgba(0,0,0,.24);
    }
    .lightbox-caption {
      padding: 13px 16px;
      color: #fff;
      font-size: 13px;
      font-weight: 700;
    }
    .lightbox-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      padding: 0 14px 14px;
    }
    .lightbox-action,
    .lightbox-nav {
      border: 0;
      cursor: pointer;
      font-weight: 800;
      box-shadow: 0 12px 30px rgba(0,0,0,.18);
    }
    .lightbox-action {
      padding: 10px 12px;
      border-radius: 999px;
      background: rgba(255,255,255,.9);
      color: #2a2440;
      font-size: 12px;
      text-decoration: none;
    }
    .lightbox-nav {
      position: absolute;
      top: 50%;
      width: 44px;
      height: 44px;
      border-radius: 999px;
      background: rgba(255,255,255,.84);
      color: #2a2440;
      font-size: 30px;
      line-height: 1;
      transform: translateY(-50%);
    }
    .lightbox-prev { left: 10px; }
    .lightbox-next { right: 10px; }
    .lightbox-close {
      position: absolute;
      top: 10px;
      right: 10px;
      width: 42px;
      height: 42px;
      border: 0;
      border-radius: 999px;
      background: rgba(255,255,255,.9);
      color: #2a2440;
      font-size: 26px;
      line-height: 1;
      cursor: pointer;
      box-shadow: 0 12px 30px rgba(0,0,0,.22);
    }
    .blob { display: none; }
    body {
      background:
        linear-gradient(135deg, #fff0f6 0%, #eef6ff 48%, #f4efff 100%);
    }
    .backdrop {
      background-image:
        linear-gradient(120deg, rgba(255,255,255,.34), rgba(255,255,255,0) 38%, rgba(110,199,255,.12) 72%, rgba(255,255,255,0)),
        repeating-linear-gradient(90deg, rgba(255,255,255,.20) 0 1px, transparent 1px 82px),
        repeating-linear-gradient(0deg, rgba(255,255,255,.18) 0 1px, transparent 1px 82px);
      opacity: .55;
    }
    .shell {
      max-width: 1240px;
      padding: 22px 14px 46px;
    }
    .hero {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(280px, 390px);
      gap: 24px;
      padding: 26px;
      border-radius: 30px;
      background:
        linear-gradient(135deg, rgba(255,255,255,.90), rgba(255,255,255,.68)),
        linear-gradient(135deg, rgba(255,95,162,.18), rgba(110,199,255,.14));
    }
    .hero::after { display: none; }
    .hero-copy,
    .hero-preview {
      position: relative;
      z-index: 1;
    }
    .eyebrow-row {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
      margin-bottom: 18px;
    }
    .badge,
    .soft-pill {
      display: inline-flex;
      align-items: center;
      min-height: 38px;
      border-radius: 999px;
      border: 1px solid rgba(255,255,255,.86);
      background: rgba(255,255,255,.74);
      box-shadow: 0 10px 26px rgba(94, 76, 154, .08);
    }
    .soft-pill {
      padding: 9px 12px;
      color: #546179;
      font-size: 12px;
      font-weight: 800;
    }
    .hero h1 {
      max-width: 720px;
      margin: 0 0 12px;
      font-size: 44px;
      letter-spacing: 0;
    }
    .hero p {
      max-width: 730px;
      font-size: 15px;
    }
    .stat-row {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      margin-top: 22px;
    }
    .stat {
      min-width: 0;
      border-radius: 18px;
      background: rgba(255,255,255,.66);
      box-shadow: 0 12px 26px rgba(98, 88, 140, .09);
    }
    .hero-preview {
      min-height: 330px;
      border-radius: 28px;
      border: 1px solid rgba(255,255,255,.74);
      background:
        linear-gradient(145deg, rgba(255,255,255,.44), rgba(255,255,255,.20)),
        linear-gradient(135deg, rgba(255,95,162,.18), rgba(110,199,255,.18));
      overflow: hidden;
      box-shadow: inset 0 1px 0 rgba(255,255,255,.55), 0 18px 44px rgba(75,60,120,.12);
    }
    .preview-tile {
      position: absolute;
      border: 0;
      padding: 0;
      overflow: hidden;
      cursor: zoom-in;
      background: rgba(255,255,255,.45);
      box-shadow: 0 18px 42px rgba(52, 42, 88, .18);
    }
    .preview-tile img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }
    .preview-1 {
      left: 22px;
      top: 22px;
      width: 58%;
      height: 68%;
      border-radius: 26px;
    }
    .preview-2 {
      right: 22px;
      top: 42px;
      width: 34%;
      height: 34%;
      border-radius: 22px;
    }
    .preview-3 {
      right: 42px;
      bottom: 32px;
      width: 42%;
      height: 36%;
      border-radius: 22px;
    }
    .preview-4 {
      left: 48px;
      bottom: 22px;
      width: 26%;
      height: 25%;
      border-radius: 18px;
    }
    .preview-tile:only-child {
      inset: 22px;
      width: auto;
      height: auto;
      border-radius: 26px;
    }
    .preview-empty {
      display: grid;
      place-items: center;
      height: 100%;
      padding: 28px;
      color: var(--muted);
      font-weight: 800;
      text-align: center;
    }
    .note-strip {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
      margin-top: 16px;
    }
    .panel {
      border-radius: 20px;
      background: rgba(255,255,255,.72);
      box-shadow: 0 12px 32px rgba(106, 93, 153, .08);
    }
    .grid {
      grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
      gap: 16px;
      margin-top: 20px;
    }
    .card {
      border-radius: 20px;
      background: rgba(255,255,255,.86);
    }
    .media-wrap {
      aspect-ratio: 4 / 5;
      border-radius: 18px;
    }
    .card:nth-child(3n) .media-wrap { aspect-ratio: 1 / 1; }
    .card:nth-child(4n) .media-wrap { aspect-ratio: 5 / 4; }
    .media-shine {
      position: absolute;
      inset: 0;
      background: linear-gradient(135deg, rgba(255,255,255,.28), transparent 36%, rgba(255,255,255,0));
      pointer-events: none;
    }
    .media-open {
      position: absolute;
      right: 10px;
      bottom: 10px;
      padding: 7px 10px;
      border-radius: 999px;
      background: rgba(255,255,255,.88);
      color: #2a2440;
      font-size: 11px;
      font-weight: 800;
      opacity: 0;
      transform: translateY(6px);
      transition: opacity .18s ease, transform .18s ease;
    }
    .card:hover .media-open,
    .media-wrap:focus-visible .media-open {
      opacity: 1;
      transform: translateY(0);
    }
    .caption-index {
      color: #d84f88;
      letter-spacing: 0;
      text-transform: none;
    }
    .lightbox {
      background: rgba(24, 17, 38, .88);
    }
    .lightbox-inner {
      width: min(100%, 1040px);
      border-radius: 24px;
      background: rgba(22,18,32,.82);
    }
    .lightbox-action,
    .lightbox-nav,
    .lightbox-close {
      background: rgba(255,255,255,.92);
    }
    @media (max-width: 900px) {
      .hero {
        grid-template-columns: 1fr;
      }
      .hero-preview {
        min-height: 300px;
      }
      .note-strip {
        grid-template-columns: 1fr;
      }
    }
    @media (max-width: 560px) {
      .hero {
        padding: 18px;
        border-radius: 24px;
      }
      .hero h1 {
        font-size: 30px;
      }
      .stat-row {
        grid-template-columns: 1fr;
      }
      .hero-preview {
        min-height: 260px;
      }
      .grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
      .media-open {
        opacity: 1;
        transform: none;
      }
    }
  </style>
</head>
<body>
  <div class="backdrop" aria-hidden="true"></div>
  <main class="shell">
    <section class="hero">
      <div class="hero-copy">
        <div class="eyebrow-row">
          <span class="badge">💖 ${brandLabel}</span>
          <span class="soft-pill">Album riêng tư có thời hạn</span>
        </div>
        <h1>${title}</h1>
        <p>${description}</p>
        <div class="stat-row">
          <div class="stat"><span class="stat-label">Số ảnh</span><span class="stat-value">${photos.length}</span></div>
          <div class="stat"><span class="stat-label">Ngày tạo</span><span class="stat-value">${escapeHtml(createdAt || 'Hôm nay')}</span></div>
          <div class="stat"><span class="stat-label">Hết hạn</span><span class="stat-value">${escapeHtml(expires)}</span></div>
        </div>
        <div class="note-strip">
          <article class="panel">
            <h2>Album kỷ niệm được chia sẻ riêng cho bạn</h2>
            <p>Mỗi tấm ảnh là một mảnh nhỏ của hành trình yêu thương, được gom lại thành một trang xem nhanh, dịu mắt và dễ lưu giữ.</p>
          </article>
          <article class="panel">
            <h2>Chạm ảnh để xem lớn</h2>
            <p>Bạn có thể mở từng ảnh, tải ảnh, chia sẻ hoặc copy link ảnh ngay trong chế độ xem phóng to.</p>
          </article>
        </div>
      </div>
      <div class="hero-preview" aria-label="Ảnh nổi bật trong album">${heroPreviewContent}</div>
    </section>
    ${photos.length ? `<section class="grid">${photoCards}</section>` : '<section class="empty">Liên kết này chưa có ảnh hiển thị. Hãy quay lại SoulLocket và tạo lại album mới khi bạn đã có ảnh phù hợp.</section>'}
    <footer class="footer">Được tạo bằng SoulLocket • Memory Share</footer>
  </main>
  <div class="lightbox" id="lightbox" role="dialog" aria-modal="true" aria-label="Xem ảnh phóng to">
    <div class="lightbox-inner">
      <button class="lightbox-close" id="lightboxClose" type="button" aria-label="Đóng">×</button>
      <button class="lightbox-nav lightbox-prev" id="lightboxPrev" type="button" aria-label="Ảnh trước">‹</button>
      <button class="lightbox-nav lightbox-next" id="lightboxNext" type="button" aria-label="Ảnh tiếp theo">›</button>
      <img id="lightboxImage" alt="Ảnh kỷ niệm phóng to">
      <div class="lightbox-caption" id="lightboxCaption"></div>
      <div class="lightbox-actions">
        <a class="lightbox-action" id="lightboxDownload" href="#" download target="_blank" rel="noopener">Tải ảnh</a>
        <button class="lightbox-action" id="lightboxShare" type="button">Chia sẻ</button>
        <button class="lightbox-action" id="lightboxCopy" type="button">Copy link</button>
      </div>
    </div>
  </div>
  <script>
    const lightboxItems = ${lightboxItems};
    const lightbox = document.getElementById('lightbox');
    const lightboxImage = document.getElementById('lightboxImage');
    const lightboxCaption = document.getElementById('lightboxCaption');
    const lightboxDownload = document.getElementById('lightboxDownload');
    const lightboxShare = document.getElementById('lightboxShare');
    const lightboxCopy = document.getElementById('lightboxCopy');
    let activeIndex = 0;

    const renderLightbox = () => {
      const item = lightboxItems[activeIndex] || {};
      const url = item.url || '';
      lightboxImage.src = url;
      lightboxCaption.textContent = item.caption || 'Kỷ niệm SoulLocket';
      lightboxDownload.href = url;
    };

    const openLightbox = (index) => {
      activeIndex = Math.max(0, Math.min(lightboxItems.length - 1, index));
      renderLightbox();
      lightbox.classList.add('open');
      document.body.style.overflow = 'hidden';
    };

    const closeLightbox = () => {
      lightbox.classList.remove('open');
      lightboxImage.removeAttribute('src');
      document.body.style.overflow = '';
    };

    const moveLightbox = (delta) => {
      if (!lightboxItems.length) return;
      activeIndex = (activeIndex + delta + lightboxItems.length) % lightboxItems.length;
      renderLightbox();
    };

    const copyActiveLink = async () => {
      const url = lightboxItems[activeIndex]?.url || '';
      if (!url) return;
      try {
        await navigator.clipboard.writeText(url);
        lightboxCopy.textContent = 'Đã copy';
        setTimeout(() => { lightboxCopy.textContent = 'Copy link'; }, 1400);
      } catch (_) {
        window.prompt('Copy link ảnh:', url);
      }
    };

    document.querySelectorAll('.media-wrap, .preview-tile').forEach((button) => {
      button.addEventListener('click', () => openLightbox(Number(button.dataset.index) || 0));
    });
    document.getElementById('lightboxClose').addEventListener('click', closeLightbox);
    document.getElementById('lightboxPrev').addEventListener('click', () => moveLightbox(-1));
    document.getElementById('lightboxNext').addEventListener('click', () => moveLightbox(1));
    lightboxShare.addEventListener('click', async () => {
      const item = lightboxItems[activeIndex] || {};
      if (navigator.share && item.url) {
        try {
          await navigator.share({ title: item.caption || 'SoulLocket', url: item.url });
          return;
        } catch (_) {}
      }
      await copyActiveLink();
    });
    lightboxCopy.addEventListener('click', copyActiveLink);
    lightbox.addEventListener('click', (event) => {
      if (event.target === lightbox) closeLightbox();
    });
    document.addEventListener('keydown', (event) => {
      if (!lightbox.classList.contains('open')) return;
      if (event.key === 'Escape') closeLightbox();
      if (event.key === 'ArrowLeft') moveLightbox(-1);
      if (event.key === 'ArrowRight') moveLightbox(1);
    });
  </script>
</body>
</html>`;
}

const createMemoryShareLink = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để tạo liên kết Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const rawPhotos = Array.isArray(data?.photos) ? data.photos : [];
    if (!requestedHouseId || rawPhotos.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId hoặc danh sách ảnh Kỷ niệm.',
      );
    }
    if (rawPhotos.length > MEMORY_SHARE_MAX_ITEMS) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Mỗi liên kết chỉ hỗ trợ tối đa ${MEMORY_SHARE_MAX_ITEMS} ảnh.`,
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const photos = rawPhotos
      .map((photo, index) => normalizeMemorySharePhoto(photo, index))
      .filter(Boolean);
    if (photos.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Không có ảnh hợp lệ để chia sẻ.',
      );
    }

    const title = normalizeText(data?.title).slice(0, 120) || 'Kỷ niệm của chúng mình';
    const description = normalizeText(data?.description).slice(0, 280) ||
      'SoulLocket lưu giữ những khoảnh khắc riêng tư của hai bạn và biến chúng thành album kỷ niệm dễ chia sẻ.';
    const brandLabel = normalizeText(data?.brandLabel).slice(0, 80) || 'SoulLocket Memories';
    const theme = normalizeText(data?.theme).slice(0, 40) || 'soullocket_dream';

    const requestedExpiryDays = Number(data?.expiryDays);
    const ttlDays = Number.isFinite(requestedExpiryDays)
      ? Math.min(Math.max(Math.floor(requestedExpiryDays), 1), MEMORY_SHARE_MAX_TTL_DAYS)
      : MEMORY_SHARE_DEFAULT_TTL_DAYS;
    const now = Date.now();
    const token = crypto.randomBytes(18).toString('base64url');
    const expiresAt = now + ttlDays * 24 * 60 * 60 * 1000;
    const share = {
      houseId,
      createdBy: uid,
      createdAt: now,
      expiresAt,
      ttlDays,
      revoked: false,
      photoCount: photos.length,
      title,
      description,
      brandLabel,
      theme,
      photos,
    };
    const db = admin.database();
    await db.ref().update({
      [`memory_shares/${token}`]: share,
      [`houses/${houseId}/memoryShares/${token}`]: {
        createdAt: now,
        expiresAt,
        ttlDays,
        photoCount: photos.length,
        revoked: false,
        createdBy: uid,
      },
    });

    return {
      ok: true,
      token,
      url: `https://soullockket.web.app/memory-share?token=${encodeURIComponent(token)}`,
      expiresAt,
      ttlDays,
      photoCount: photos.length,
    };
  });

const resolvePrivateMediaUrl = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để mở media riêng tư.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const kind = normalizePrivateMediaKind(data?.kind);
    const mediaId = normalizeText(data?.mediaId);
    if (!requestedHouseId || !kind || !mediaId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId, kind hoặc mediaId.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const recordPath = kind === 'memory_image'
      ? `houses/${houseId}/memories/${mediaId}`
      : `houses/${houseId}/utilities/voices/${mediaId}`;
    const snap = await db.ref(recordPath).once('value');
    if (!snap.exists()) {
      throw new functions.https.HttpsError('not-found', 'Không tìm thấy media riêng tư.');
    }

    const record = asObject(snap.val());
    const canRead = kind === 'memory_image'
      ? canReadPrivateMemoryRecord(record, houseId)
      : canReadPrivateVoiceRecord(record, houseId);
    if (!canRead) {
      throw new functions.https.HttpsError('permission-denied', 'Media riêng tư không hợp lệ.');
    }

    const storagePath = normalizeText(record.storagePath || record.storageKey);
    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError('not-found', 'File media không còn tồn tại.');
    }

    const now = Date.now();
    const expiresAt = now + PRIVATE_MEDIA_READ_TTL_MS;
    const url = await createTemporaryReadUrl(bucket, storagePath);
    const updates = kind === 'memory_image'
      ? {
          [`${recordPath}/url`]: url,
          [`${recordPath}/urlExpiresAt`]: expiresAt,
          [`${recordPath}/storageAccess`]: 'signed',
          [`${recordPath}/privateMedia`]: true,
          [`${recordPath}/storageKey`]: storagePath,
        }
      : {
          [`${recordPath}/aud`]: url,
          [`${recordPath}/audExpiresAt`]: expiresAt,
          [`${recordPath}/storageAccess`]: 'signed',
          [`${recordPath}/privateMedia`]: true,
          [`${recordPath}/storageKey`]: storagePath,
        };
    await db.ref().update(updates);

    return {
      ok: true,
      kind,
      mediaId,
      storagePath,
      url,
      expiresAt,
    };
  });

const revokeMemoryShareLink = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để thu hồi liên kết Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const token = normalizeText(data?.token);
    if (!token) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu token liên kết.');
    }

    const db = admin.database();
    const shareSnap = await db.ref(`memory_shares/${token}`).once('value');
    if (!shareSnap.exists()) {
      throw new functions.https.HttpsError('not-found', 'Không tìm thấy liên kết Kỷ niệm.');
    }

    const share = asObject(shareSnap.val());
    const houseId = normalizeText(share.houseId);
    await resolveMemberHouse(uid, houseId);
    const now = Date.now();
    await db.ref().update({
      [`memory_shares/${token}/revoked`]: true,
      [`memory_shares/${token}/revokedAt`]: now,
      [`memory_shares/${token}/revokedBy`]: uid,
      [`houses/${houseId}/memoryShares/${token}/revoked`]: true,
      [`houses/${houseId}/memoryShares/${token}/revokedAt`]: now,
      [`houses/${houseId}/memoryShares/${token}/revokedBy`]: uid,
    });

    return { ok: true, token, revokedAt: now };
  });

const memorySharePage = functions
  .runWith({ invoker: 'public' })
  .https.onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    if (req.method !== 'GET') {
      return res.status(405).send('Method not allowed');
    }

    const token = normalizeText(req.query.token);
    if (!token) {
      return res.status(400).send('Thiếu mã liên kết.');
    }

    const snap = await admin.database().ref(`memory_shares/${token}`).once('value');
    if (!snap.exists()) {
      return res.status(404).send('Liên kết không tồn tại.');
    }

    const record = asObject(snap.val());
    if (record.revoked === true) {
      return res.status(410).send('Liên kết đã được thu hồi.');
    }
    const expiresAt = toTimestamp(record.expiresAt);
    if (expiresAt > 0 && Date.now() > expiresAt) {
      return res.status(410).send('Liên kết đã hết hạn.');
    }

    const payload = sanitizeMemoryShareForPublic(record, token);
    if (normalizeText(req.query.format).toLowerCase() === 'json') {
      return res.status(200).json(payload);
    }
    return res.status(200).type('html').send(buildMemoryShareHtml(payload));
  });

const MEMORY_TRASH_TTL_MS = 3 * 24 * 60 * 60 * 1000;

function buildDeletedMemoryPayload(memoryId, item, deletedAt, purgeAt) {
  return {
    ...item,
    id: memoryId,
    deletedAt,
    purgeAt,
  };
}

function resolveMemoryStoragePath(item) {
  return normalizeText(
    item.storagePath ||
      item.path ||
      item.fullPath ||
      item.filePath ||
      item.originalStoragePath,
  );
}

const moveMemoryImagesToTrash = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để xóa ảnh Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const ids = Array.isArray(data?.memoryIds)
      ? [...new Set(data.memoryIds.map((item) => normalizeText(item)).filter(Boolean))]
      : [];
    if (!requestedHouseId || ids.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId hoặc memoryIds.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const now = Date.now();
    const purgeAt = now + MEMORY_TRASH_TTL_MS;
    const updates = {};
    const deletedItems = [];

    for (const memoryId of ids) {
      const memoryRef = db.ref(`houses/${houseId}/memories/${memoryId}`);
      const snapshot = await memoryRef.once('value');
      if (!snapshot.exists()) {
        continue;
      }

      const item = asObject(snapshot.val());
      const trashPayload = buildDeletedMemoryPayload(memoryId, item, now, purgeAt);
      updates[`houses/${houseId}/memories_trash/${memoryId}`] = trashPayload;
      updates[`houses/${houseId}/memories/${memoryId}`] = null;
      deletedItems.push({
        memoryId,
        trashId: memoryId,
        url: normalizeText(item.url || item.downloadUrl || item.imageUrl),
        previewUrl: normalizeText(item.thumbUrl || item.thumbnailUrl || item.url || item.downloadUrl || item.imageUrl),
        storagePath: resolveMemoryStoragePath(item),
        title: normalizeText(item.caption || item.title || item.authorName),
        deletedAt: now,
        purgeAt,
        restorePayload: trashPayload,
      });
    }

    if (deletedItems.length <= 0) {
      return { ok: true, deletedCount: 0, deletedItems: [] };
    }

    updates[`houses/${houseId}/memoriesCount`] = admin.database.ServerValue.increment(-deletedItems.length);
    await db.ref().update(updates);
    return {
      ok: true,
      deletedCount: deletedItems.length,
      purgeAt,
      deletedItems,
    };
  });

const restoreMemoryImageFromTrash = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để khôi phục ảnh Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const memoryId = normalizeText(data?.memoryId || data?.trashId);
    if (!requestedHouseId || !memoryId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin khôi phục ảnh Kỷ niệm.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const trashRef = db.ref(`houses/${houseId}/memories_trash/${memoryId}`);
    const snapshot = await trashRef.once('value');
    if (!snapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Ảnh Kỷ niệm không còn trong thùng rác.',
      );
    }

    const item = asObject(snapshot.val());
    const purgeAt = toTimestamp(item.purgeAt);
    if (purgeAt > 0 && Date.now() > purgeAt) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Ảnh Kỷ niệm đã quá hạn khôi phục.',
      );
    }

    const restored = { ...item };
    delete restored.deletedAt;
    delete restored.purgeAt;
    restored.id = memoryId;
    restored.restoredAt = Date.now();

    await db.ref().update({
      [`houses/${houseId}/memories/${memoryId}`]: restored,
      [`houses/${houseId}/memories_trash/${memoryId}`]: null,
      [`houses/${houseId}/memoriesCount`]: admin.database.ServerValue.increment(1),
    });

    return { ok: true, memoryId };
  });

const cleanupExpiredMemoryImagesTrash = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để dọn thùng rác Kỷ niệm.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const snap = await db.ref(`houses/${houseId}/memories_trash`).once('value');
    if (!snap.exists()) {
      return { ok: true, deletedCount: 0 };
    }

    const now = Date.now();
    const updates = {};
    const bucket = admin.storage().bucket();
    let deletedCount = 0;
    const raw = asObject(snap.val());
    for (const [memoryId, value] of Object.entries(raw)) {
      const item = asObject(value);
      const purgeAt = toTimestamp(item.purgeAt);
      if (purgeAt > 0 && purgeAt <= now) {
        await deleteStorageObjectIfExists(bucket, resolveMemoryStoragePath(item));
        updates[`houses/${houseId}/memories_trash/${memoryId}`] = null;
        deletedCount += 1;
      }
    }

    if (deletedCount > 0) {
      await db.ref().update(updates);
    }
    return { ok: true, deletedCount };
  });

const finalizeAlbumImageUpload = functions
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để hoàn tất ảnh Album.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const sessionId = normalizeText(data?.sessionId);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!sessionId || !requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin để hoàn tất ảnh Album.',
      );
    }

    const db = admin.database();
    const sessionRef = db.ref(`album_image_upload_sessions/${sessionId}`);
    const sessionSnapshot = await sessionRef.once('value');
    if (!sessionSnapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy phiên tải ảnh Album.',
      );
    }

    const session = asObject(sessionSnapshot.val());
    if (normalizeText(session.uid) !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bạn không có quyền dùng phiên tải ảnh Album này.',
      );
    }

    const now = Date.now();
    if (normalizeText(session.status).toLowerCase() === 'finalized') {
      return {
        ok: true,
        photoId: normalizeText(session.photoId),
      };
    }
    if (toTimestamp(session.finalizeBy) > 0 && now > toTimestamp(session.finalizeBy)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Phiên tải ảnh Album đã hết hạn.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    if (normalizeText(session.houseId) !== houseId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Phiên tải ảnh Album không thuộc nhà này.',
      );
    }

    const storagePath = normalizeText(session.storagePath);
    if (!isAlbumStoragePath(storagePath, uid, houseId)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Đường dẫn ảnh Album không hợp lệ.',
      );
    }

    const bucket = admin.storage().bucket();
    const [exists] = await bucket.file(storagePath).exists();
    if (!exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Ảnh Album chưa tải lên hoàn tất.',
      );
    }

    const caption = normalizeText(data?.caption).slice(0, 500);
    const thumbUrl = normalizeText(data?.thumbUrl).slice(0, 2048);
    const role = normalizeText(data?.role).slice(0, 40);
    const authorName = normalizeText(data?.authorName).slice(0, 80);
    const type = normalizeText(data?.type) || 'image';
    if (!['image', 'video', 'gif'].includes(type)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Kiểu ảnh Album không hợp lệ.',
      );
    }

    let quota = null;
    try {
      await sessionRef.update({
        status: 'finalizing',
        finalizingAt: now,
      });

      quota = await reserveAlbumImageQuota({
        db,
        uid,
        houseId,
        houseData,
        now,
      });

      await sessionRef.update({
        quotaDayKey: quota.dayKey,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
        totalCap: quota.totalCap,
        albumCount: quota.albumCount,
        plan: quota.isPro ? 'pro' : 'free',
      });

      const photoRef = db.ref(`houses/${houseId}/album`).push();
      const photoId = normalizeText(photoRef.key);
      if (!photoId) {
        throw new functions.https.HttpsError('internal', 'Không thể tạo ID ảnh Album.');
      }

      const photoData = {
        url: normalizeText(session.downloadUrl),
        ...(thumbUrl ? { thumbUrl } : {}),
        ...(caption ? { caption } : {}),
        ...(role ? { role } : {}),
        ...(authorName ? { authorName } : {}),
        ts: now,
        timestamp: now,
        type,
        likes: 0,
        storagePath,
        uploadSessionId: sessionId,
      };

      const updates = {
        [`houses/${houseId}/album/${photoId}`]: photoData,
        [`album_image_upload_sessions/${sessionId}/status`]: 'finalized',
        [`album_image_upload_sessions/${sessionId}/finalizedAt`]: now,
        [`album_image_upload_sessions/${sessionId}/photoId`]: photoId,
        [`album_image_upload_sessions/${sessionId}/photoPath`]: `houses/${houseId}/album/${photoId}`,
      };
      await db.ref().update(updates);

      return {
        ok: true,
        photoId,
        dailyLimit: quota.dailyLimit,
        usedToday: quota.usedToday,
        remainingToday: quota.remainingToday,
        totalCap: quota.totalCap,
        albumCount: quota.albumCount,
        data: photoData,
      };
    } catch (error) {
      if (quota?.dayKey) {
        try {
          await rollbackAlbumImageQuota({
            db,
            uid,
            dayKey: quota.dayKey,
            houseId,
          });
        } catch (_) {}
      }
      try {
        await sessionRef.update({
          status: 'pending',
          finalizeErrorAt: now,
          finalizeErrorCode: normalizeText(error?.code || error?.message).slice(0, 80),
        });
      } catch (_) {}
      throw error;
    }
  });

const deleteChatBackgroundAsset = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để xóa ảnh nền chat.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    const scope = normalizeChatImageScope(data?.scope);
    const storagePath = normalizeText(data?.storagePath);
    if (!requestedHouseId || !scope || !storagePath) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu thông tin xóa ảnh nền chat.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    let isAllowedPath = false;
    if (scope === 'internal') {
      isAllowedPath = isInternalChatBackgroundPath(storagePath, houseId);
    } else {
      const targetHouseId = normalizeText(data?.targetHouseId);
      if (!targetHouseId || targetHouseId === houseId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Thiếu targetHouseId hợp lệ để xóa nền chat trực tiếp.',
        );
      }
      isAllowedPath = isDirectChatBackgroundPath(
        storagePath,
        houseId,
        targetHouseId,
      );
    }

    if (!isAllowedPath) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Đường dẫn ảnh nền chat không hợp lệ.',
      );
    }

    await deleteStorageObjectIfExists(admin.storage().bucket(), storagePath);
    return { success: true };
  });

const requestSecretVaultReset = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để yêu cầu reset Kho ảnh mật.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const email = normalizeEmail(data?.email);
    const otp = normalizeText(data?.otp);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId || !email || !otp) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId, email hoặc mã OTP.',
      );
    }

    const db = admin.database();
    await otpModule.verifyPrimaryEmailOtpOrThrow({
      uid,
      email,
      otp,
      db,
    });

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const resetRequestRef = db.ref(`secret_vault_reset_requests/${houseId}`);
    const mirroredResetRef = db.ref(`houses/${houseId}/private_secure_meta/resetRequest`);
    const scheduledAt = Date.now() + SECRET_VAULT_RESET_DELAY_MS;
    const requestId = `${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    const userRecord = await admin.auth().getUser(uid);
    const requesterName =
      normalizeText(userRecord.displayName) || 'Một người trong nhà';

    let existingPending = null;
    const transactionResult = await resetRequestRef.transaction((current) => {
      const record = asObject(current);
      const status = normalizeText(record.status).toLowerCase();
      if (status === 'pending') {
        existingPending = record;
        return;
      }

      return {
        requestId,
        houseId,
        status: 'pending',
        requestedBy: uid,
        requestedByEmail: email,
        requestedByName: requesterName,
        requestedAt: Date.now(),
        scheduledAt,
        canCancel: true,
      };
    });

    if (!transactionResult.committed) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Đã có yêu cầu reset Kho ảnh mật đang chờ xử lý.',
        {
          scheduledAt: toTimestamp(existingPending?.scheduledAt),
          status: normalizeText(existingPending?.status) || 'pending',
          requestedBy: normalizeText(existingPending?.requestedBy),
        },
      );
    }

    const createdRecord = asObject(transactionResult.snapshot.val());
    await mirroredResetRef.set(createdRecord);

    await queueHouseNotification({
      houseId,
      senderUid: uid,
      title: 'Đã lên lịch reset Kho ảnh mật',
      body:
        `${requesterName} vừa xác nhận reset Kho ảnh mật. Toàn bộ dữ liệu sẽ bị xoá sau 24 giờ nếu không thu hồi.`,
      data: {
        screen: 'vault',
        type: 'secret_vault_reset_pending',
        houseId,
      },
    });

    return {
      ok: true,
      ...createdRecord,
    };
  });

const cancelSecretVaultReset = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Đăng nhập để thu hồi yêu cầu reset Kho ảnh mật.',
      );
    }

    const uid = normalizeText(context.auth.uid);
    const requestedHouseId = normalizeText(data?.houseId);
    if (!requestedHouseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu houseId để thu hồi reset Kho ảnh mật.',
      );
    }

    const { houseId } = await resolveMemberHouse(uid, requestedHouseId);
    const db = admin.database();
    const resetRequestRef = db.ref(`secret_vault_reset_requests/${houseId}`);
    const resetRequestSnap = await resetRequestRef.once('value');
    if (!resetRequestSnap.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Không tìm thấy yêu cầu reset Kho ảnh mật đang chờ.',
      );
    }

    const existingRecord = asObject(resetRequestSnap.val());
    if (normalizeText(existingRecord.status).toLowerCase() !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Yêu cầu reset Kho ảnh mật không còn ở trạng thái chờ.',
      );
    }

    const userRecord = await admin.auth().getUser(uid);
    const cancellerName =
      normalizeText(userRecord.displayName) || 'Một người trong nhà';
    const canceledAt = Date.now();

    await db.ref().update({
      [`secret_vault_reset_requests/${houseId}/status`]: 'canceled',
      [`secret_vault_reset_requests/${houseId}/canceledAt`]: canceledAt,
      [`secret_vault_reset_requests/${houseId}/canceledBy`]: uid,
      [`secret_vault_reset_requests/${houseId}/canceledByName`]: cancellerName,
      [`houses/${houseId}/private_secure_meta/resetRequest`]: null,
    });

    await queueHouseNotification({
      houseId,
      senderUid: uid,
      title: 'Đã thu hồi reset Kho ảnh mật',
      body:
        `${cancellerName} vừa thu hồi yêu cầu reset Kho ảnh mật. Dữ liệu sẽ không bị xoá nữa.`,
      data: {
        screen: 'vault',
        type: 'secret_vault_reset_canceled',
        houseId,
      },
    });

    return {
      ok: true,
      houseId,
      status: 'canceled',
      canceledAt,
    };
  });

const processPendingSecretVaultResets = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async () => {
    const db = admin.database();
    const snapshot = await db.ref('secret_vault_reset_requests').once('value');
    const pendingRequests = asObject(snapshot.val());
    const now = Date.now();
    let processedCount = 0;

    for (const [houseId, rawRequest] of Object.entries(pendingRequests)) {
      const request = asObject(rawRequest);
      if (normalizeText(request.status).toLowerCase() !== 'pending') {
        continue;
      }
      if (toTimestamp(request.scheduledAt) > now) {
        continue;
      }

      try {
        const didProcess = await executeSecretVaultReset({
          db,
          houseId,
          request,
        });
        if (didProcess) {
          processedCount += 1;
        }
      } catch (error) {
        console.error(`processPendingSecretVaultResets failed for ${houseId}:`, error);
      }
    }

    console.log(`processPendingSecretVaultResets completed: ${processedCount}`);
    return null;
  });

const cleanupExpiredMemoryShares = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async () => {
    const db = admin.database();
    const now = Date.now();
    const snapshot = await db
      .ref('memory_shares')
      .orderByChild('expiresAt')
      .endAt(now)
      .limitToFirst(200)
      .once('value');
    const expiredShares = asObject(snapshot.val());
    let deletedCount = 0;

    for (const [token, rawShare] of Object.entries(expiredShares)) {
      const share = asObject(rawShare);
      const houseId = normalizeText(share.houseId);
      const updates = {
        [`memory_shares/${token}`]: null,
      };
      if (houseId) {
        updates[`houses/${houseId}/memoryShares/${token}`] = null;
      }
      try {
        await db.ref().update(updates);
        deletedCount += 1;
      } catch (error) {
        console.error(`cleanupExpiredMemoryShares failed for ${token}:`, error);
      }
    }

    console.log(`cleanupExpiredMemoryShares completed: deleted=${deletedCount}`);
    return null;
  });

const processChatImageRetention = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async () => {
    const db = admin.database();
    const bucket = admin.storage().bucket();
    const now = Date.now();
    let expiredMessages = 0;
    let expiredSessions = 0;

    const retentionSnapshot = await db
      .ref('chat_image_retention')
      .orderByChild('expiresAt')
      .endAt(now)
      .limitToFirst(200)
      .once('value');
    const retentionItems = asObject(retentionSnapshot.val());
    for (const [queueKey, rawItem] of Object.entries(retentionItems)) {
      try {
        await expireChatImageMessage({
          db,
          bucket,
          queueKey,
          queueItem: asObject(rawItem),
          now,
        });
        expiredMessages += 1;
      } catch (error) {
        console.error(`processChatImageRetention message cleanup failed for ${queueKey}:`, error);
      }
    }

    const sessionSnapshot = await db
      .ref('chat_image_upload_sessions')
      .orderByChild('finalizeBy')
      .endAt(now)
      .limitToFirst(200)
      .once('value');
    const sessions = asObject(sessionSnapshot.val());
    for (const [sessionId, rawSession] of Object.entries(sessions)) {
      try {
        const didExpire = await expirePendingChatImageSession({
          db,
          bucket,
          sessionId,
          session: asObject(rawSession),
          now,
        });
        if (didExpire) {
          expiredSessions += 1;
        }
      } catch (error) {
        console.error(`processChatImageRetention session cleanup failed for ${sessionId}:`, error);
      }
    }

    console.log(
      `processChatImageRetention completed: expiredMessages=${expiredMessages}, expiredSessions=${expiredSessions}`,
    );
    return null;
  });

module.exports = {
  cancelSecretVaultReset,
  cleanupExpiredMemoryShares,
  createAlbumImageUploadSession,
  createChatImageUploadSession,
  createCreativeDiaryVoiceUploadSession,
  createGiftImageUploadSession,
  createLoveCardImageUploadSession,
  createMemoryImageUploadSession,
  createMemoryShareLink,
  createPublicImageUploadSession,
  createSecretVaultUploadSession,
  memorySharePage,
  moveMemoryImagesToTrash,
  resolvePrivateMediaUrl,
  createVoiceUploadSession,
  deleteChatBackgroundAsset,
  deleteVoiceMessage,
  finalizeAlbumImageUpload,
  finalizeChatImageMessage,
  finalizeCreativeDiaryVoiceUpload,
  finalizeMemoryImageUpload,
  finalizePublicImageUpload,
  finalizeVoiceUpload,
  restoreMemoryImageFromTrash,
  cleanupExpiredMemoryImagesTrash,
  processChatImageRetention,
  processPendingSecretVaultResets,
  redeemProPlanForUser,
  redeemProPlanHttp,
  requestSecretVaultReset,
  revokeMemoryShareLink,
  reserveHouseCreationTrialVip,
  rollbackHouseCreationTrialVip,
  verifyGooglePlayPurchase,
  verifyPurchase,
};
