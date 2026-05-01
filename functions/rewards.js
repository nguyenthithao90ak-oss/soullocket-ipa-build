'use strict';

const crypto = require('crypto');

const DEFAULT_REWARD_GRANT_COOLDOWN_MS = 25 * 1000;
const DEFAULT_REWARD_GRANT_DAILY_CAP = 1200;
const DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS = 2 * 60 * 1000;
const DEFAULT_REWARDED_AD_FUTURE_SKEW_MS = 30 * 1000;
const DEFAULT_QUEST_PROGRESS_MIN_INTERVAL_MS = Object.freeze({
  partner_interaction: 10 * 1000,
  map_checkin: 60 * 1000,
  diary_entry: 30 * 1000,
  simultaneous_online: 60 * 1000,
});
const DEFAULT_REWARD_SOURCE_CONFIG = Object.freeze({
  rewarded_ad: Object.freeze({
    points: 50,
    cooldownMs: DEFAULT_REWARD_GRANT_COOLDOWN_MS,
  }),
  daily_checkin: Object.freeze({
    points: 50,
  }),
});
const DEFAULT_DAILY_QUEST_REWARDS = Object.freeze({
  partner_interaction: Object.freeze({ target: 3, points: 10 }),
  map_checkin: Object.freeze({ target: 1, points: 25 }),
  diary_entry: Object.freeze({ target: 1, points: 20 }),
  simultaneous_online: Object.freeze({ target: 1, points: 25 }),
});

function normalizeText(value) {
  return String(value ?? '').trim();
}

function asObject(value) {
  return value && typeof value === 'object' ? value : {};
}

function toTimestamp(value) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? normalized : 0;
}

function parseBoolean(value) {
  const normalized = normalizeText(value).toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

function parseStringList(value) {
  return normalizeText(value)
    .split(',')
    .map((item) => normalizeText(item).toLowerCase())
    .filter(Boolean);
}

function rewardDateKey(nowMs = Date.now()) {
  const vnDate = new Date(nowMs + 7 * 60 * 60 * 1000);
  const year = vnDate.getUTCFullYear();
  const month = String(vnDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(vnDate.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value ?? '')).digest('hex');
}

function createDefaultParseRequestBody(body) {
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

function createDefaultJsonResponse(res, statusCode, payload) {
  setCorsHeaders(res);
  return res.status(statusCode).json(payload);
}

async function createDefaultVerifyRequestUser(admin, req) {
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

async function createDefaultVerifyAppCheckRequest(admin, req) {
  const appCheckToken = normalizeText(req.headers['x-firebase-appcheck']);
  if (!appCheckToken) {
    throw new Error('missing_app_check');
  }

  await admin.appCheck().verifyToken(appCheckToken);
}

function canonicalRewardedAdProofPayload({ uid, eventId, issuedAtMs, adUnit = '' }) {
  return [
    normalizeText(uid),
    normalizeText(eventId),
    String(toTimestamp(issuedAtMs)),
    normalizeText(adUnit),
  ].join(':');
}

function createRewardedAdProofSignature({
  uid,
  eventId,
  issuedAtMs,
  adUnit = '',
  secret,
  cryptoLib = crypto,
}) {
  const normalizedSecret = normalizeText(secret);
  if (!normalizedSecret) {
    throw new Error('missing_rewarded_ad_proof_secret');
  }

  return cryptoLib
    .createHmac('sha256', normalizedSecret)
    .update(canonicalRewardedAdProofPayload({ uid, eventId, issuedAtMs, adUnit }))
    .digest('hex');
}

function extractRewardedAdProof(body) {
  const nestedProof = asObject(body.proof);
  const rewardProof = asObject(body.rewardProof);
  const source = Object.keys(nestedProof).length ? nestedProof : rewardProof;

  if (Object.keys(source).length) {
    return {
      eventId: normalizeText(source.eventId || source.proofId || source.id),
      issuedAtMs: toTimestamp(
        source.issuedAtMs || source.proofIssuedAtMs || source.timestamp,
      ),
      signature: normalizeText(
        source.signature || source.proofSignature || source.sig,
      ).toLowerCase(),
      adUnit: normalizeText(source.adUnit || source.ad_unit),
    };
  }

  return {
    eventId: normalizeText(body.proofId || body.eventId || body.rewardEventId),
    issuedAtMs: toTimestamp(body.proofIssuedAtMs || body.issuedAtMs),
    signature: normalizeText(body.proofSignature || body.signature).toLowerCase(),
    adUnit: normalizeText(body.adUnit || body.ad_unit),
  };
}

function verifyRewardedAdProof({
  uid,
  proof,
  secret,
  now = Date.now(),
  maxAgeMs = DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS,
  futureSkewMs = DEFAULT_REWARDED_AD_FUTURE_SKEW_MS,
  cryptoLib = crypto,
}) {
  const normalizedSecret = normalizeText(secret);
  if (!normalizedSecret) {
    return { ok: false, code: 'rewarded_ad_temporarily_disabled' };
  }

  const normalizedUid = normalizeText(uid);
  const normalizedProof = {
    eventId: normalizeText(proof?.eventId),
    issuedAtMs: toTimestamp(proof?.issuedAtMs),
    signature: normalizeText(proof?.signature).toLowerCase(),
    adUnit: normalizeText(proof?.adUnit),
  };

  if (
    !normalizedUid ||
    !normalizedProof.eventId ||
    normalizedProof.issuedAtMs <= 0 ||
    !normalizedProof.signature
  ) {
    return { ok: false, code: 'missing_proof' };
  }

  if (
    normalizedProof.eventId.length > 200 ||
    normalizedProof.signature.length !== 64 ||
    !/^[a-f0-9]{64}$/.test(normalizedProof.signature)
  ) {
    return { ok: false, code: 'invalid_proof' };
  }

  if (normalizedProof.issuedAtMs > now + Math.max(0, futureSkewMs)) {
    return { ok: false, code: 'expired_proof' };
  }

  if (now - normalizedProof.issuedAtMs > Math.max(0, maxAgeMs)) {
    return { ok: false, code: 'expired_proof' };
  }

  const expectedSignature = createRewardedAdProofSignature({
    uid: normalizedUid,
    eventId: normalizedProof.eventId,
    issuedAtMs: normalizedProof.issuedAtMs,
    adUnit: normalizedProof.adUnit,
    secret: normalizedSecret,
    cryptoLib,
  });

  const submittedBuffer = Buffer.from(normalizedProof.signature, 'hex');
  const expectedBuffer = Buffer.from(expectedSignature, 'hex');
  if (
    submittedBuffer.length !== expectedBuffer.length ||
    !cryptoLib.timingSafeEqual(submittedBuffer, expectedBuffer)
  ) {
    return { ok: false, code: 'invalid_proof' };
  }

  return { ok: true, proof: normalizedProof };
}

function buildQuestProgressSettings({
  allowPublicQuestProgress,
  publicQuestProgressIds,
  dailyQuestRewards = DEFAULT_DAILY_QUEST_REWARDS,
}) {
  const allowedQuestIds = new Set(
    parseStringList(publicQuestProgressIds).filter((questId) =>
      Object.prototype.hasOwnProperty.call(dailyQuestRewards, questId),
    ),
  );

  return {
    allowPublicQuestProgress: parseBoolean(allowPublicQuestProgress),
    allowedQuestIds,
  };
}

function canAcceptPublicQuestProgress({
  questId,
  allowPublicQuestProgress,
  allowedQuestIds,
}) {
  const normalizedQuestId = normalizeText(questId).toLowerCase();
  if (!allowPublicQuestProgress || !normalizedQuestId) {
    return false;
  }
  return allowedQuestIds.has(normalizedQuestId);
}

function pickRewardHttpStatus(code) {
  switch (code) {
    case 'invalid_source':
    case 'invalid_quest':
    case 'missing_proof':
    case 'invalid_proof':
    case 'expired_proof':
    case 'invalid_request':
    case 'quest_server_validation_required':
      return 400;
    case 'missing_app_check':
    case 'invalid_app_check':
      return 403;
    case 'replay_detected':
    case 'already_claimed':
    case 'quest_not_done':
      return 409;
    case 'rate_limited':
    case 'daily_cap_reached':
      return 429;
    case 'rewarded_ad_temporarily_disabled':
      return 503;
    default:
      return 500;
  }
}

function createRewardsModule(customDeps = {}) {
  const functions = customDeps.functions || require('firebase-functions');
  const admin = customDeps.admin || require('firebase-admin');
  const rewardSourceConfig = customDeps.rewardSourceConfig || DEFAULT_REWARD_SOURCE_CONFIG;
  const dailyQuestRewards = customDeps.dailyQuestRewards || DEFAULT_DAILY_QUEST_REWARDS;
  const rewardGrantDailyCap = Math.max(
    1,
    Math.trunc(customDeps.rewardGrantDailyCap || DEFAULT_REWARD_GRANT_DAILY_CAP),
  );
  const rewardedAdProofSecret = normalizeText(
    customDeps.rewardedAdProofSecret ?? process.env.REWARDED_AD_PROOF_SECRET,
  );
  const rewardedAdProofMaxAgeMs = Math.max(
    1,
    Math.trunc(
      Number(
        customDeps.rewardedAdProofMaxAgeMs ??
          process.env.REWARDED_AD_PROOF_MAX_AGE_MS ??
          DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS,
      ),
    ) || DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS,
  );
  const rewardedAdFutureSkewMs = Math.max(
    0,
    Math.trunc(
      Number(
        customDeps.rewardedAdFutureSkewMs ??
          process.env.REWARDED_AD_FUTURE_SKEW_MS ??
          DEFAULT_REWARDED_AD_FUTURE_SKEW_MS,
      ),
    ) || DEFAULT_REWARDED_AD_FUTURE_SKEW_MS,
  );
  const questProgressIntervals = {
    ...DEFAULT_QUEST_PROGRESS_MIN_INTERVAL_MS,
    ...asObject(customDeps.questProgressIntervals),
  };
  const parseRequestBody = customDeps.parseRequestBody || createDefaultParseRequestBody;
  const jsonResponse = customDeps.jsonResponse || createDefaultJsonResponse;
  const verifyRequestUser =
    customDeps.verifyRequestUser ||
    ((req) => createDefaultVerifyRequestUser(admin, req));
  const verifyAppCheckRequest =
    customDeps.verifyAppCheckRequest ||
    ((req) => createDefaultVerifyAppCheckRequest(admin, req));
  const questSettings = buildQuestProgressSettings({
    allowPublicQuestProgress:
      customDeps.allowPublicQuestProgress ?? process.env.ALLOW_PUBLIC_QUEST_PROGRESS,
    publicQuestProgressIds:
      customDeps.publicQuestProgressIds ?? process.env.PUBLIC_QUEST_PROGRESS_IDS,
    dailyQuestRewards,
  });

  async function verifyRewardedAdRequest({ uid, body, now = Date.now() }) {
    const verification = verifyRewardedAdProof({
      uid,
      proof: extractRewardedAdProof(body),
      secret: rewardedAdProofSecret,
      now,
      maxAgeMs: rewardedAdProofMaxAgeMs,
      futureSkewMs: rewardedAdFutureSkewMs,
    });

    if (!verification.ok) {
      throw new Error(verification.code);
    }

    const proofKey = sha256(`rewarded_ad:${uid}:${verification.proof.eventId}`);
    const proofRef = admin.database().ref(`reward_proofs/${proofKey}`);
    const proofResult = await proofRef.transaction((current) => {
      if (current) {
        return;
      }
      return {
        uid,
        source: 'rewarded_ad',
        eventId: verification.proof.eventId,
        issuedAtMs: verification.proof.issuedAtMs,
        adUnit: verification.proof.adUnit || null,
        verifiedAt: admin.database.ServerValue.TIMESTAMP,
      };
    });

    if (!proofResult.committed) {
      throw new Error('replay_detected');
    }

    return verification.proof;
  }

  async function grantRewardPoints({ uid, source, questId }) {
    if (source === 'daily_checkin') {
      return claimDailyCheckinReward({ uid });
    }

    if (source === 'daily_quest_progress') {
      if (
        !canAcceptPublicQuestProgress({
          questId,
          allowPublicQuestProgress: questSettings.allowPublicQuestProgress,
          allowedQuestIds: questSettings.allowedQuestIds,
        })
      ) {
        throw new Error('quest_server_validation_required');
      }
      return recordDailyQuestProgress({ uid, questId });
    }

    if (source === 'daily_quest') {
      throw new Error('quest_server_validation_required');
    }

    if (!Object.prototype.hasOwnProperty.call(rewardSourceConfig, source)) {
      throw new Error('invalid_source');
    }

    return grantStandardReward({ uid, source });
  }

  async function grantStandardReward({ uid, source }) {
    const config = rewardSourceConfig[source];
    if (!config) {
      throw new Error('invalid_source');
    }

    const amount = Math.max(0, Math.trunc(Number(config.points) || 0));
    const cooldownMs = Math.max(0, Math.trunc(Number(config.cooldownMs) || 0));
    const db = admin.database();
    const now = Date.now();
    const day = rewardDateKey(now);
    const stateRef = db.ref(`reward_state/${uid}/${source}`);
    let abortReason = '';

    const stateResult = await stateRef.transaction((rawState) => {
      const state = asObject(rawState);
      const sameDay = normalizeText(state.day) === day;
      const lastAt = sameDay ? toTimestamp(state.lastAt) : 0;
      const grantedToday = sameDay
        ? Math.max(0, Math.trunc(Number(state.grantedToday) || 0))
        : 0;

      if (cooldownMs > 0 && lastAt > 0 && now - lastAt < cooldownMs) {
        abortReason = 'rate_limited';
        return;
      }

      if (grantedToday + amount > rewardGrantDailyCap) {
        abortReason = 'daily_cap_reached';
        return;
      }

      abortReason = '';
      return {
        day,
        grantedToday: grantedToday + amount,
        lastAt: now,
        lastAmount: amount,
        updatedAt: now,
      };
    });

    if (!stateResult.committed) {
      throw new Error(abortReason || 'rate_limited');
    }

    const finalPoints = await incrementUserPoints({ db, uid, amount });
    await writeRewardHistory({ db, uid, amount, source, day });

    return {
      granted: amount,
      points: finalPoints,
    };
  }

  async function claimDailyCheckinReward({ uid }) {
    const db = admin.database();
    const now = Date.now();
    const day = rewardDateKey(now);
    const amount = Math.max(0, Math.trunc(Number(rewardSourceConfig.daily_checkin?.points) || 0));
    const userRef = db.ref(`users/${uid}`);
    let finalPoints = 0;
    let abortReason = '';

    const result = await userRef.transaction((rawUser) => {
      const user = asObject(rawUser);
      const checkinDays = asObject(user.checkinDays);

      if (checkinDays[day] === true) {
        abortReason = 'already_claimed';
        return;
      }

      const currentPoints = Math.max(0, Math.trunc(Number(user.points) || 0));
      finalPoints = currentPoints + amount;
      checkinDays[day] = true;

      return {
        ...user,
        points: finalPoints,
        checkinDays,
        lastCheckIn: day,
        lastCheckInAt: now,
      };
    });

    if (!result.committed) {
      throw new Error(abortReason || 'already_claimed');
    }

    const userData = asObject(result.snapshot.val());
    finalPoints = Math.max(0, Math.trunc(Number(userData.points) || finalPoints));
    await writeRewardHistory({
      db,
      uid,
      amount,
      source: 'daily_checkin',
      day,
    });

    return {
      granted: amount,
      points: finalPoints,
    };
  }

  async function recordDailyQuestProgress({ uid, questId }) {
    const normalizedQuestId = normalizeText(questId).toLowerCase();
    const config = dailyQuestRewards[normalizedQuestId];
    if (!config) {
      throw new Error('invalid_quest');
    }

    const minIntervalMs = Math.max(
      0,
      Math.trunc(Number(questProgressIntervals[normalizedQuestId]) || 0),
    );
    const db = admin.database();
    const now = Date.now();
    const day = rewardDateKey(now);
    const questRef = db.ref(`users/${uid}/daily_quests/${day}/${normalizedQuestId}`);
    let abortReason = '';

    const progressResult = await questRef.transaction((rawQuest) => {
      const quest = asObject(rawQuest);
      const wasDone = quest.done === true;
      const currentProgress = Math.max(0, Math.trunc(Number(quest.progress) || 0));
      const lastProgressAt = toTimestamp(quest.lastProgressAt || quest.updatedAt);

      if (minIntervalMs > 0 && lastProgressAt > 0 && now - lastProgressAt < minIntervalMs) {
        abortReason = 'rate_limited';
        return;
      }

      if (wasDone) {
        abortReason = 'already_claimed';
        return {
          ...quest,
          progress: Math.min(config.target, currentProgress),
          target: config.target,
          done: true,
          updatedAt: now,
          lastProgressAt: lastProgressAt || now,
        };
      }

      const nextProgress = Math.min(config.target, currentProgress + 1);
      const done = nextProgress >= config.target;
      abortReason = '';
      return {
        ...quest,
        progress: nextProgress,
        target: config.target,
        done,
        updatedAt: now,
        lastProgressAt: now,
        ...(done ? { completedAt: now } : {}),
      };
    });

    if (!progressResult.committed) {
      throw new Error(abortReason || 'quest_progress_failed');
    }

    const questData = asObject(progressResult.snapshot.val());
    const progress = Math.max(0, Math.trunc(Number(questData.progress) || 0));
    const done = questData.done === true;
    let reward = { granted: 0, points: 0 };

    if (done) {
      try {
        reward = await claimDailyQuestReward({
          uid,
          questId: normalizedQuestId,
          requireDone: false,
          day,
        });
      } catch (error) {
        if (normalizeText(error?.message) !== 'already_claimed') {
          throw error;
        }
      }
    }

    return {
      progress,
      done,
      granted: reward.granted,
      points: reward.points,
    };
  }

  async function claimDailyQuestReward({
    uid,
    questId,
    requireDone = true,
    day = rewardDateKey(),
  }) {
    const normalizedQuestId = normalizeText(questId).toLowerCase();
    const config = dailyQuestRewards[normalizedQuestId];
    if (!config) {
      throw new Error('invalid_quest');
    }

    const db = admin.database();
    if (requireDone) {
      const doneSnap = await db
        .ref(`users/${uid}/daily_quests/${day}/${normalizedQuestId}/done`)
        .once('value');
      if (doneSnap.val() !== true) {
        throw new Error('quest_not_done');
      }
    }

    const claimRef = db.ref(`reward_claims/${uid}/${day}/daily_quests/${normalizedQuestId}`);
    let abortReason = '';
    const claimResult = await claimRef.transaction((rawClaim) => {
      if (rawClaim) {
        abortReason = 'already_claimed';
        return;
      }

      return {
        source: 'daily_quest',
        questId: normalizedQuestId,
        amount: config.points,
        claimedAt: Date.now(),
      };
    });

    if (!claimResult.committed) {
      throw new Error(abortReason || 'already_claimed');
    }

    const finalPoints = await incrementUserPoints({
      db,
      uid,
      amount: config.points,
    });
    await writeRewardHistory({
      db,
      uid,
      amount: config.points,
      source: `daily_quest:${normalizedQuestId}`,
      day,
    });

    return {
      granted: config.points,
      points: finalPoints,
    };
  }

  async function incrementUserPoints({ db, uid, amount }) {
    let finalPoints = 0;
    const pointsResult = await db.ref(`users/${uid}/points`).transaction((current) => {
      const currentPoints = Math.max(0, Math.trunc(Number(current) || 0));
      finalPoints = currentPoints + amount;
      return finalPoints;
    });

    if (!pointsResult.committed) {
      throw new Error('grant_points_failed');
    }

    return Math.trunc(Number(pointsResult.snapshot.val()) || finalPoints);
  }

  async function writeRewardHistory({ db, uid, amount, source, day }) {
    await db.ref(`reward_history/${uid}`).push().set({
      amount,
      source,
      ts: admin.database.ServerValue.TIMESTAMP,
      day,
    });
  }

  const grantRewardPointsHttp = functions
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
        const source = normalizeText(body.source || 'rewarded_ad').toLowerCase();
        const questId = normalizeText(body.questId || body.quest_id).toLowerCase();

        if (source === 'rewarded_ad') {
          await verifyRewardedAdRequest({
            uid: decodedToken.uid,
            body,
          });
        }

        const result = await grantRewardPoints({
          uid: decodedToken.uid,
          source,
          questId,
        });
        return jsonResponse(res, 200, {
          ok: true,
          points: result.points,
          granted: result.granted,
          progress: result.progress,
          done: result.done,
        });
      } catch (error) {
        const code = normalizeText(error?.message);
        const statusCode = pickRewardHttpStatus(code);
        if (statusCode !== 500) {
          return jsonResponse(res, statusCode, { ok: false, error: code });
        }

        console.error('grantRewardPointsHttp error:', error);
        return jsonResponse(res, 500, {
          ok: false,
          error: 'grant_reward_points_failed',
        });
      }
    });

  return {
    constants: {
      DEFAULT_REWARD_GRANT_COOLDOWN_MS,
      DEFAULT_REWARD_GRANT_DAILY_CAP,
      DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS,
      DEFAULT_REWARDED_AD_FUTURE_SKEW_MS,
      rewardSourceConfig,
      dailyQuestRewards,
      questSettings,
    },
    grantRewardPointsHttp,
    grantRewardPoints,
    claimDailyCheckinReward,
    recordDailyQuestProgress,
    claimDailyQuestReward,
    incrementUserPoints,
    writeRewardHistory,
    verifyRewardedAdRequest,
  };
}

module.exports = {
  createRewardsModule,
  __testables: {
    DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS,
    DEFAULT_REWARDED_AD_FUTURE_SKEW_MS,
    DEFAULT_DAILY_QUEST_REWARDS,
    normalizeText,
    asObject,
    toTimestamp,
    parseBoolean,
    parseStringList,
    rewardDateKey,
    sha256,
    canonicalRewardedAdProofPayload,
    createRewardedAdProofSignature,
    extractRewardedAdProof,
    verifyRewardedAdProof,
    buildQuestProgressSettings,
    canAcceptPublicQuestProgress,
    pickRewardHttpStatus,
  },
};
