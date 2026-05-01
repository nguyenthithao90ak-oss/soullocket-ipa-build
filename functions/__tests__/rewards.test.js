'use strict';

const assert = require('assert');

const { __testables } = require('../rewards');

function testValidRewardedAdProof() {
  const now = 1_700_000_000_000;
  const proof = {
    eventId: 'evt_123456',
    issuedAtMs: now - 30_000,
    adUnit: 'rewarded-main',
  };
  const signature = __testables.createRewardedAdProofSignature({
    uid: 'user_1',
    eventId: proof.eventId,
    issuedAtMs: proof.issuedAtMs,
    adUnit: proof.adUnit,
    secret: 'top-secret',
  });

  const result = __testables.verifyRewardedAdProof({
    uid: 'user_1',
    proof: {
      ...proof,
      signature,
    },
    secret: 'top-secret',
    now,
  });

  assert.deepStrictEqual(result, {
    ok: true,
    proof: {
      eventId: 'evt_123456',
      issuedAtMs: now - 30_000,
      signature,
      adUnit: 'rewarded-main',
    },
  });
}

function testInvalidRewardedAdProofSignature() {
  const result = __testables.verifyRewardedAdProof({
    uid: 'user_1',
    proof: {
      eventId: 'evt_123456',
      issuedAtMs: 1_700_000_000_000,
      signature: 'a'.repeat(64),
      adUnit: 'rewarded-main',
    },
    secret: 'top-secret',
    now: 1_700_000_010_000,
  });

  assert.deepStrictEqual(result, {
    ok: false,
    code: 'invalid_proof',
  });
}

function testExpiredRewardedAdProof() {
  const issuedAtMs = 1_700_000_000_000;
  const signature = __testables.createRewardedAdProofSignature({
    uid: 'user_1',
    eventId: 'evt_expired',
    issuedAtMs,
    adUnit: '',
    secret: 'top-secret',
  });

  const result = __testables.verifyRewardedAdProof({
    uid: 'user_1',
    proof: {
      eventId: 'evt_expired',
      issuedAtMs,
      signature,
      adUnit: '',
    },
    secret: 'top-secret',
    now: issuedAtMs + __testables.DEFAULT_REWARDED_AD_PROOF_MAX_AGE_MS + 1,
  });

  assert.deepStrictEqual(result, {
    ok: false,
    code: 'expired_proof',
  });
}

function testQuestProgressDefaultsClosed() {
  const settings = __testables.buildQuestProgressSettings({
    allowPublicQuestProgress: 'false',
    publicQuestProgressIds: 'diary_entry,map_checkin',
  });

  assert.strictEqual(
    __testables.canAcceptPublicQuestProgress({
      questId: 'diary_entry',
      allowPublicQuestProgress: settings.allowPublicQuestProgress,
      allowedQuestIds: settings.allowedQuestIds,
    }),
    false,
  );
}

function testQuestProgressAllowList() {
  const settings = __testables.buildQuestProgressSettings({
    allowPublicQuestProgress: 'true',
    publicQuestProgressIds: 'diary_entry,unknown,map_checkin',
  });

  assert.strictEqual(
    __testables.canAcceptPublicQuestProgress({
      questId: 'diary_entry',
      allowPublicQuestProgress: settings.allowPublicQuestProgress,
      allowedQuestIds: settings.allowedQuestIds,
    }),
    true,
  );
  assert.strictEqual(
    __testables.canAcceptPublicQuestProgress({
      questId: 'partner_interaction',
      allowPublicQuestProgress: settings.allowPublicQuestProgress,
      allowedQuestIds: settings.allowedQuestIds,
    }),
    false,
  );
}

function testExtractRewardedAdProofSupportsNestedAndFlatShapes() {
  const nested = __testables.extractRewardedAdProof({
    proof: {
      proofId: 'evt_nested',
      proofIssuedAtMs: '1700000000000',
      proofSignature: 'b'.repeat(64),
      adUnit: 'rewarded-main',
    },
  });
  const flat = __testables.extractRewardedAdProof({
    eventId: 'evt_flat',
    issuedAtMs: 1700000005000,
    signature: 'c'.repeat(64),
    ad_unit: 'rewarded-alt',
  });

  assert.deepStrictEqual(nested, {
    eventId: 'evt_nested',
    issuedAtMs: 1_700_000_000_000,
    signature: 'b'.repeat(64),
    adUnit: 'rewarded-main',
  });
  assert.deepStrictEqual(flat, {
    eventId: 'evt_flat',
    issuedAtMs: 1_700_000_005_000,
    signature: 'c'.repeat(64),
    adUnit: 'rewarded-alt',
  });
}

function run() {
  testValidRewardedAdProof();
  testInvalidRewardedAdProofSignature();
  testExpiredRewardedAdProof();
  testQuestProgressDefaultsClosed();
  testQuestProgressAllowList();
  testExtractRewardedAdProofSupportsNestedAndFlatShapes();
  console.log('rewards.test.js: all tests passed');
}

run();
