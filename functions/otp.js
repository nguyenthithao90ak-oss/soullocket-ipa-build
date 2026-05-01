const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const OTP_EXPIRY_MS = 5 * 60 * 1000;
const OTP_REQUEST_COOLDOWN_MS = 60 * 1000;
const OTP_MAX_FAILED_ATTEMPTS = 5;
const OTP_LOCKOUT_MS = 15 * 60 * 1000;
const OTP_SECRET = String(process.env.OTP_SECRET ?? '').trim();
const IS_FUNCTIONS_EMULATOR = process.env.FUNCTIONS_EMULATOR === 'true';
const EMULATOR_OTP_SECRET =
  String(process.env.GCLOUD_PROJECT ?? '').trim() || 'local-emulator-otp-secret';

function getMailerAccounts() {
  const rawAccounts = [];
  const groupedAccounts = String(process.env.GMAIL_ACCOUNTS ?? '').trim();
  if (groupedAccounts) {
    rawAccounts.push(...groupedAccounts.split(','));
  }

  const singleUser = String(process.env.GMAIL_EMAIL ?? '').trim();
  const singlePass = String(process.env.GMAIL_APP_PASSWORD ?? '').trim();
  if (singleUser && singlePass) {
    rawAccounts.push(`${singleUser}:${singlePass}`);
  } else if (singleUser || singlePass) {
    console.warn('[otp] Bỏ qua cấu hình Gmail lẻ vì thiếu email hoặc app password.');
  }

  return rawAccounts
    .map((account) => {
      const parts = String(account ?? '').split(':');
      return {
        user: parts[0]?.trim(),
        pass: parts.slice(1).join(':').trim(),
      };
    })
    .filter((account) => {
      if (!account.user || !account.pass) {
        return false;
      }

      return (
        account.user.toLowerCase() !== 'undefined' &&
        account.pass.toLowerCase() !== 'undefined'
      );
    });
}

const accounts = getMailerAccounts();

const transporters = accounts.map((acc) => ({
  user: acc.user,
  transporter: nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: acc.user,
      pass: acc.pass,
    },
  }),
}));

const strictCallableOptions = { enforceAppCheck: true };
const OTP_EMAIL_ENFORCE_APP_CHECK =
  String(process.env.OTP_EMAIL_ENFORCE_APP_CHECK ?? '')
    .trim()
    .toLowerCase() === 'true';
const otpEmailCallableOptions = {
  enforceAppCheck: OTP_EMAIL_ENFORCE_APP_CHECK,
};

if (!OTP_EMAIL_ENFORCE_APP_CHECK) {
  console.warn(
    '[otp] OTP email callables are running without enforced App Check (OTP_EMAIL_ENFORCE_APP_CHECK!=true).',
  );
}

if (!OTP_SECRET && !IS_FUNCTIONS_EMULATOR) {
  console.error(
    '[otp] Thiếu OTP_SECRET. Các hàm OTP sẽ từ chối request cho tới khi được cấu hình.',
  );
}

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

function normalizeText(value) {
  return String(value ?? '').trim();
}

function normalizeHouseId(value) {
  return normalizeText(value).toUpperCase().slice(0, 120);
}

function sanitizeEmailKey(email) {
  return normalizeEmail(email).replace(/\./g, ',');
}

function toTimestamp(value) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? Math.trunc(normalized) : 0;
}

function hashHousePin(pin) {
  return crypto.createHash('sha256').update(normalizeText(pin)).digest('hex');
}

function getOtpSecretOrThrow() {
  if (OTP_SECRET) {
    return OTP_SECRET;
  }

  if (IS_FUNCTIONS_EMULATOR) {
    return EMULATOR_OTP_SECRET;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Máy chủ chưa cấu hình OTP_SECRET an toàn để xử lý OTP.',
  );
}

function hashOtp(email, otp) {
  return crypto
    .createHmac('sha256', getOtpSecretOrThrow())
    .update(`${normalizeEmail(email)}:${String(otp ?? '').trim()}`)
    .digest('hex');
}

function safeOtpCompare(left, right) {
  try {
    const leftBuffer = Buffer.from(String(left || ''), 'hex');
    const rightBuffer = Buffer.from(String(right || ''), 'hex');
    if (
      leftBuffer.length === 0 ||
      rightBuffer.length === 0 ||
      leftBuffer.length !== rightBuffer.length
    ) {
      return false;
    }
    return crypto.timingSafeEqual(leftBuffer, rightBuffer);
  } catch (_) {
    return false;
  }
}

function isHouseMember(houseData, uid) {
  const normalizedUid = normalizeText(uid);
  if (!normalizedUid || !houseData || typeof houseData !== 'object') {
    return false;
  }

  if (normalizeText(houseData.owner_uid) === normalizedUid) {
    return true;
  }

  const members =
    houseData.members && typeof houseData.members === 'object'
      ? houseData.members
      : {};
  return Object.prototype.hasOwnProperty.call(members, normalizedUid);
}

async function storeOtpRecord({ db, email, otp }) {
  const now = Date.now();
  const key = sanitizeEmailKey(email);
  const recordRef = db.ref(`otp_codes/${key}`);
  let abortReason = '';

  const result = await recordRef.transaction((rawCurrent) => {
    const current =
      rawCurrent && typeof rawCurrent === 'object' ? rawCurrent : {};
    const lockedUntil = toTimestamp(current.lockedUntil);
    if (lockedUntil > now) {
      abortReason = 'otp_locked';
      return;
    }

    const lastSentAt = toTimestamp(current.lastSentAt);
    if (lastSentAt > 0 && now - lastSentAt < OTP_REQUEST_COOLDOWN_MS) {
      abortReason = 'otp_requested_too_soon';
      return;
    }

    return {
      codeHash: hashOtp(email, otp),
      expiresAt: now + OTP_EXPIRY_MS,
      lastSentAt: now,
      failedAttempts: 0,
      lockedUntil: 0,
    };
  });

  if (!result.committed) {
    const message =
      abortReason === 'otp_locked'
        ? 'Bạn đã nhập sai OTP quá nhiều lần. Vui lòng thử lại sau 15 phút.'
        : 'Vui lòng đợi ít nhất 60 giây trước khi yêu cầu mã mới.';
    throw new functions.https.HttpsError('resource-exhausted', message);
  }
}

async function clearOtpRecord({ db, email }) {
  const key = sanitizeEmailKey(email);
  const recordRef = db.ref(`otp_codes/${key}`);
  await recordRef.remove();
}

async function consumeOtpOrThrow({ db, email, otp }) {
  const key = sanitizeEmailKey(email);
  const recordRef = db.ref(`otp_codes/${key}`);
  const snap = await recordRef.once('value');
  const record = snap.val();
  const now = Date.now();

  if (!record) {
    throw new functions.https.HttpsError(
      'deadline-exceeded',
      'Mã OTP đã hết hạn hoặc chưa được cấp. Vui lòng yêu cầu mã mới.',
    );
  }

  const expiresAt = toTimestamp(record.expiresAt);
  if (expiresAt <= now) {
    await recordRef.remove();
    throw new functions.https.HttpsError(
      'deadline-exceeded',
      'Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.',
    );
  }

  const lockedUntil = toTimestamp(record.lockedUntil);
  if (lockedUntil > now) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Bạn đã nhập sai OTP quá nhiều lần. Vui lòng thử lại sau 15 phút.',
    );
  }

  const expectedHash = String(record.codeHash || '');
  const actualHash = hashOtp(email, otp);
  const legacyPlaintext = String(record.code || '').trim();
  const isValid =
    safeOtpCompare(expectedHash, actualHash) ||
    (legacyPlaintext && legacyPlaintext === String(otp).trim());

  if (!isValid) {
    let nextFailedAttempts = 0;
    await recordRef.transaction((rawCurrent) => {
      if (!rawCurrent || typeof rawCurrent !== 'object') {
        return rawCurrent;
      }

      const failedAttempts =
        Math.max(0, Math.trunc(Number(rawCurrent.failedAttempts) || 0)) + 1;
      nextFailedAttempts = failedAttempts;
      return {
        ...rawCurrent,
        failedAttempts,
        lockedUntil:
          failedAttempts >= OTP_MAX_FAILED_ATTEMPTS
            ? now + OTP_LOCKOUT_MS
            : 0,
      };
    });

    if (nextFailedAttempts >= OTP_MAX_FAILED_ATTEMPTS) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Bạn đã nhập sai OTP quá nhiều lần. Vui lòng thử lại sau 15 phút.',
      );
    }

    throw new functions.https.HttpsError(
      'permission-denied',
      'Mã OTP không đúng. Vui lòng kiểm tra lại.',
    );
  }

  await recordRef.remove();
}

async function verifyPrimaryEmailOtpOrThrow({ uid, email, otp, db }) {
  const normalizedUid = normalizeText(uid);
  const normalizedEmail = normalizeEmail(email);
  const normalizedOtp = normalizeText(otp);
  if (!normalizedUid || !normalizedEmail || !normalizedOtp) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Thiếu thông tin xác thực email chính.',
    );
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUser(normalizedUid);
  } catch (error) {
    console.error('verifyPrimaryEmailOtpOrThrow getUser failed', {
      uid: normalizedUid,
      error: error?.message || String(error),
    });
    throw new functions.https.HttpsError(
      'internal',
      'Không thể tải thông tin tài khoản hiện tại để xác thực email.',
    );
  }

  const primaryEmail = normalizeEmail(userRecord?.email);
  if (!primaryEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Tài khoản hiện tại không có email chính để xác thực.',
    );
  }

  if (primaryEmail !== normalizedEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Email OTP không khớp email chính của tài khoản đang đăng nhập.',
    );
  }

  await consumeOtpOrThrow({
    db,
    email: normalizedEmail,
    otp: normalizedOtp,
  });

  await admin.auth().updateUser(normalizedUid, { emailVerified: true });
}

function pickTransporter() {
  if (transporters.length === 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Máy chủ chưa được cấu hình để gửi email OTP.',
    );
  }

  return transporters[Math.floor(Math.random() * transporters.length)];
}

exports.verifyHousePin = functions
  .runWith(strictCallableOptions)
  .https.onCall(async (data, context) => {
    const houseId = normalizeHouseId(data?.houseId);
    const pin = normalizeText(data?.pin);
    if (!houseId || !pin) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing houseId or PIN',
      );
    }
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to verify house PIN',
      );
    }

    const db = admin.database();
    const [houseSnap, privateSecuritySnap] = await Promise.all([
      db.ref(`houses/${houseId}`).once('value'),
      db.ref(`house_private_security/${houseId}`).once('value'),
    ]);

    if (!houseSnap.exists()) {
      throw new functions.https.HttpsError('not-found', 'House not found');
    }

    const houseData = houseSnap.val();
    if (!isHouseMember(houseData, context.auth.uid)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You are not allowed to verify this house PIN',
      );
    }

    const securityData =
      privateSecuritySnap.exists() && typeof privateSecuritySnap.val() === 'object'
        ? privateSecuritySnap.val()
        : {};
    const storedPinHash = normalizeText(securityData.pinHash).toLowerCase();
    const legacyPin = normalizeText(houseData?.security?.pin);
    const incomingPinHash = hashHousePin(pin);
    const isValid =
      (storedPinHash && safeOtpCompare(storedPinHash, incomingPinHash)) ||
      (legacyPin && legacyPin === pin);

    if (!isValid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'House PIN is invalid',
      );
    }

    if (!storedPinHash || legacyPin) {
      await db.ref().update({
        [`house_private_security/${houseId}/pinHash`]: incomingPinHash,
        [`house_private_security/${houseId}/updatedAt`]:
          admin.database.ServerValue.TIMESTAMP,
        [`houses/${houseId}/security/pin`]: null,
        [`houses/${houseId}/security/pinConfigured`]: true,
        [`houses/${houseId}/security/pinUpdatedAt`]:
          admin.database.ServerValue.TIMESTAMP,
        [`houses/${houseId}/security/updatedAt`]:
          admin.database.ServerValue.TIMESTAMP,
      });
    }

    return { success: true };
  });

exports.requestEmailOTP = functions
  .runWith(otpEmailCallableOptions)
  .https.onCall(async (data) => {
    const email = normalizeEmail(data?.email);
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'Thiếu email.');
    }

    getOtpSecretOrThrow();
    const picker = pickTransporter();

    const otp = generateOTP();
    const db = admin.database();
    await storeOtpRecord({ db, email, otp });

    const mailOptions = {
      from: `"SoulLocket App" <${picker.user}>`,
      to: email,
      subject: 'Mã xác nhận SoulLocket (6 số)',
      text: `Mã xác nhận của bạn là: ${otp}\n\nMã này sẽ hết hạn sau 5 phút.`,
      html: `<div style="font-family:sans-serif;text-align:center;padding:20px;">
        <h2>Mã xác nhận SoulLocket</h2>
        <p>Mã xác nhận của bạn là:</p>
        <h1 style="color:#D81B60;letter-spacing:5px;">${otp}</h1>
        <p>Mã này sẽ hết hạn sau 5 phút.</p>
      </div>`,
    };

    try {
      await picker.transporter.sendMail(mailOptions);
      return { success: true, message: `OTP sent via ${picker.user}` };
    } catch (error) {
      console.error('Error sending email:', error);
      try {
        await clearOtpRecord({ db, email });
      } catch (rollbackError) {
        console.error('Error rolling back OTP record after send failure:', {
          email,
          error: rollbackError?.message || String(rollbackError),
        });
      }
      throw new functions.https.HttpsError(
        'internal',
        'Không thể gửi email OTP.',
      );
    }
  });

exports.verifyEmailOTP = functions
  .runWith(otpEmailCallableOptions)
  .https.onCall(async (data) => {
    const email = normalizeEmail(data?.email);
    const otp = String(data?.otp ?? '').trim();
    if (!email || !otp) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu email hoặc OTP.',
      );
    }

    const db = admin.database();
    await consumeOtpOrThrow({ db, email, otp });

    let uid;
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      uid = userRecord.uid;
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        throw new functions.https.HttpsError(
          'not-found',
          'Không tìm thấy tài khoản tương ứng với email này.',
        );
      }
      throw new functions.https.HttpsError(
        'internal',
        'Không thể xác thực OTP lúc này.',
      );
    }

    const customToken = await admin.auth().createCustomToken(uid);
    return { success: true, customToken };
  });

exports.validateEmailOTP = functions
  .runWith(otpEmailCallableOptions)
  .https.onCall(async (data) => {
    const email = normalizeEmail(data?.email);
    const otp = String(data?.otp ?? '').trim();
    if (!email || !otp) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu email hoặc OTP.',
      );
    }

    const db = admin.database();
    await consumeOtpOrThrow({ db, email, otp });
    return { success: true };
  });

exports.verifyPrimaryEmailOTP = functions
  .runWith(otpEmailCallableOptions)
  .https.onCall(async (data, context) => {
    const email = normalizeEmail(data?.email);
    const otp = String(data?.otp ?? '').trim();
    if (!email || !otp) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Thiếu email hoặc OTP.',
      );
    }

    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to verify primary email',
      );
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUser(context.auth.uid);
    } catch (error) {
      console.error('verifyPrimaryEmailOTP getUser failed', {
        uid: context.auth.uid,
        error: error?.message || String(error),
      });
      throw new functions.https.HttpsError(
        'internal',
        'Không thể tải thông tin tài khoản hiện tại để xác thực email.',
      );
    }

    const primaryEmail = normalizeEmail(userRecord?.email);
    if (!primaryEmail) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Tài khoản hiện tại không có email chính để xác thực.',
      );
    }

    if (primaryEmail !== email) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Email OTP không khớp email chính của tài khoản đang đăng nhập.',
      );
    }

    const db = admin.database();
    await consumeOtpOrThrow({ db, email, otp });
    await admin.auth().updateUser(context.auth.uid, { emailVerified: true });
    return { success: true };
  });

exports.verifyPrimaryEmailOtpOrThrow = verifyPrimaryEmailOtpOrThrow;
