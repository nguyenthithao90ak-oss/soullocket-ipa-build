const crypto = require('crypto');
const zlib = require('zlib');

const EXPORT_RATE_LIMIT_MS = 15 * 60 * 1000;
const EXPORT_URL_TTL_DAYS = 7;
const EXPORT_URL_TTL_MS = EXPORT_URL_TTL_DAYS * 24 * 60 * 60 * 1000;
const MEMORY_IMAGE_LIMIT = 100;
const MEMORY_IMAGE_TOTAL_BYTES_LIMIT = 500 * 1024 * 1024;
const EXPORT_RANGE_DAY_OPTIONS = [7, 30, 180];
const EXPORT_RANGE_LABELS = {
  7: '1 tuần gần nhất',
  30: '1 tháng gần nhất',
  180: '6 tháng gần nhất',
};
const EXPORT_TIMESTAMP_KEYS = [
  'createdAt',
  'created_at',
  'updatedAt',
  'updated_at',
  'deletedAt',
  'deleted_at',
  'timestamp',
  'ts',
  'time',
  'date',
  'sentAt',
  'sent_at',
  'lastSeen',
  'lastSeenAt',
  'lastActiveAt',
  'capturedAt',
  'expiresAt',
];

const REDACT_KEY_PARTS = [
  'token',
  'fcmtoken',
  'pushtoken',
  'refreshtoken',
  'idtoken',
  'appcheck',
  'integrity',
  'receipt',
  'rawreceipt',
  'password',
  'secret',
  'apikey',
  'privatekey',
  'fingerprint',
  'devicefingerprint',
  'installationid',
  'ip',
  'ipaddress',
  'risk',
  'riskscore',
  'admin',
  'moderation',
  'debug',
  'internal',
  'nonce',
  'otp',
  'verificationcode',
  'session',
  'connection',
];

function createDataExportModule({ functions, admin }) {
  const db = admin.database();
  const bucket = admin.storage().bucket();

  async function getValue(path) {
    const snap = await db.ref(path).once('value');
    return snap.exists() ? snap.val() : null;
  }

  function asObject(value) {
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  }

  function normalizeText(value) {
    return String(value ?? '').trim();
  }

  function readHouseId(userData) {
    const user = asObject(userData);
    return normalizeText(user.houseId || user.house_id || user.currentHouseId || user.current_house_id);
  }

  function readUserRole(uid, houseData) {
    const house = asObject(houseData);
    const members = asObject(house.members);
    const member = asObject(members[uid]);
    if (member.role) return normalizeText(member.role);
    if (house.user1 === uid || house.ownerUid === uid || house.owner === uid) return 'user1';
    if (house.user2 === uid || house.partnerUid === uid || house.partner === uid) return 'user2';
    return normalizeText(member.memberRole || member.type || '');
  }

  function isHouseMember(uid, houseData) {
    const house = asObject(houseData);
    const members = asObject(house.members);
    if (Object.prototype.hasOwnProperty.call(members, uid)) return true;
    return [house.user1, house.user2, house.ownerUid, house.owner, house.partnerUid, house.partner]
      .map(normalizeText)
      .includes(uid);
  }

  function shouldRedactKey(key) {
    const normalized = normalizeText(key).toLowerCase().replace(/[^a-z0-9]/g, '');
    return REDACT_KEY_PARTS.some((part) => normalized.includes(part));
  }

  function redact(value) {
    if (Array.isArray(value)) return value.map(redact);
    if (!value || typeof value !== 'object') return value;
    const output = {};
    for (const [key, child] of Object.entries(value)) {
      if (shouldRedactKey(key)) continue;
      output[key] = redact(child);
    }
    return output;
  }

  function pickConsent(rawConsent) {
    const values = asObject(asObject(rawConsent).values);
    const allowedKeys = [
      'il_tos_accepted',
      'il_privacy_accepted',
      'il_cookie_storage_consent',
      'il_security_device_signals_consent',
    ];
    return {
      capturedAt: normalizeText(asObject(rawConsent).capturedAt) || new Date().toISOString(),
      values: Object.fromEntries(
        allowedKeys
          .filter((key) => Object.prototype.hasOwnProperty.call(values, key))
          .map((key) => [key, values[key]]),
      ),
    };
  }

  function readTimestamp(value) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
      const date = Date.parse(value);
      if (Number.isFinite(date)) return date;
    }
    return 0;
  }

  function normalizeExportRangeDays(data) {
    const body = asObject(data);
    const options = asObject(body.options);
    const value = Number(
      body.rangeDays ||
      body.exportRangeDays ||
      body.dataRangeDays ||
      options.rangeDays ||
      options.exportRangeDays ||
      options.dataRangeDays ||
      30,
    );
    return EXPORT_RANGE_DAY_OPTIONS.includes(value) ? value : 30;
  }

  function exportRangeLabel(days) {
    return EXPORT_RANGE_LABELS[days] || EXPORT_RANGE_LABELS[30];
  }

  function readObjectTimestampInfo(value, key = '') {
    const object = asObject(value);
    let found = false;
    let timestamp = 0;
    const keyTimestamp = readTimestamp(key);
    if (keyTimestamp > 100000000000) {
      found = true;
      timestamp = Math.max(timestamp, keyTimestamp);
    }
    for (const timestampKey of EXPORT_TIMESTAMP_KEYS) {
      if (!Object.prototype.hasOwnProperty.call(object, timestampKey)) {
        continue;
      }
      const nextTimestamp = readTimestamp(object[timestampKey]);
      if (nextTimestamp > 0) {
        found = true;
        timestamp = Math.max(timestamp, nextTimestamp);
      }
    }
    return { found, timestamp };
  }

  function isEmptyFilteredValue(value) {
    if (value == null) return true;
    if (Array.isArray(value)) return value.length === 0;
    if (typeof value === 'object') return Object.keys(value).length === 0;
    return false;
  }

  function hasRecentTimestamp(value, startAt, key = '') {
    if (!value || typeof value !== 'object') return false;
    if (Array.isArray(value)) {
      return value.some((item, index) => hasRecentTimestamp(item, startAt, String(index)));
    }
    const timestampInfo = readObjectTimestampInfo(value, key);
    if (timestampInfo.found && timestampInfo.timestamp >= startAt) return true;
    return Object.entries(asObject(value)).some(([childKey, child]) =>
      child && typeof child === 'object' && hasRecentTimestamp(child, startAt, childKey));
  }

  function filterRecentValue(value, startAt, key = '') {
    if (!startAt) return value;
    if (Array.isArray(value)) {
      return value
        .map((item, index) => filterRecentValue(item, startAt, String(index)))
        .filter((item) => !isEmptyFilteredValue(item));
    }
    if (!value || typeof value !== 'object') {
      return value;
    }

    const object = asObject(value);
    const timestampInfo = readObjectTimestampInfo(object, key);
    const filtered = {};
    let hasKeptChild = false;
    let hasRecentChild = false;

    for (const [childKey, child] of Object.entries(object)) {
      if (child && typeof child === 'object') {
        const filteredChild = filterRecentValue(child, startAt, childKey);
        if (!isEmptyFilteredValue(filteredChild)) {
          filtered[childKey] = filteredChild;
          hasKeptChild = true;
          if (hasRecentTimestamp(child, startAt, childKey)) {
            hasRecentChild = true;
          }
        }
      }
    }

    if (timestampInfo.found && timestampInfo.timestamp >= startAt) {
      for (const [childKey, child] of Object.entries(object)) {
        if (!child || typeof child !== 'object') {
          filtered[childKey] = child;
        }
      }
      return filtered;
    }

    if (hasRecentChild) {
      for (const [childKey, child] of Object.entries(object)) {
        if (!child || typeof child !== 'object') {
          filtered[childKey] = child;
        }
      }
      return filtered;
    }

    if (timestampInfo.found) {
      return null;
    }

    for (const [childKey, child] of Object.entries(object)) {
      if (!child || typeof child !== 'object') {
        filtered[childKey] = child;
      }
    }
    return hasKeptChild || Object.keys(filtered).length > 0 ? filtered : null;
  }

  function filterRecentPayload(value, startAt) {
    const filtered = filterRecentValue(value, startAt);
    if (filtered != null) return filtered;
    if (Array.isArray(value)) return [];
    if (value && typeof value === 'object') return {};
    return null;
  }

  function readMemoryCreatedAt(memory) {
    const data = asObject(memory);
    return readTimestamp(data.createdAt || data.created_at || data.ts || data.timestamp || data.updatedAt);
  }

  function collectMediaCandidates(memories, trash) {
    const candidates = [];
    for (const [scope, collection] of [
      ['active', asObject(memories)],
      ['trash', asObject(trash)],
    ]) {
      for (const [memoryId, rawMemory] of Object.entries(collection)) {
        const memory = asObject(rawMemory);
        const mediaItems = [];
        if (Array.isArray(memory.media)) mediaItems.push(...memory.media);
        if (Array.isArray(memory.images)) mediaItems.push(...memory.images);
        if (memory.imageUrl || memory.storagePath || memory.path) mediaItems.push(memory);
        for (const rawMedia of mediaItems) {
          const media = asObject(rawMedia);
          const storagePath = normalizeText(media.storagePath || media.path || media.fullPath || media.filePath);
          const url = normalizeText(media.url || media.imageUrl || media.downloadUrl);
          if (!storagePath && !url) continue;
          candidates.push({
            memoryId,
            scope,
            storagePath,
            url,
            thumbUrl: normalizeText(media.thumbUrl || media.thumbnailUrl || media.previewUrl),
            fileName: normalizeText(media.fileName || media.name) || `${memoryId}.jpg`,
            sizeBytes: Number(media.sizeBytes || media.bytes || media.size || 0) || 0,
            createdAt: readTimestamp(media.createdAt || media.ts || media.timestamp) || readMemoryCreatedAt(memory),
            caption: normalizeText(media.caption || memory.caption || memory.title || memory.note),
            favorite: media.favorite === true || memory.favorite === true || memory.pinned === true || media.pinned === true,
          });
        }
      }
    }
    return candidates.sort((a, b) => {
      if (a.scope !== b.scope) return a.scope === 'active' ? -1 : 1;
      if (a.favorite !== b.favorite) return a.favorite ? -1 : 1;
      return b.createdAt - a.createdAt;
    });
  }

  async function signedUrlForCandidate(candidate, expiresAt) {
    if (!candidate.storagePath) return candidate.url || '';
    const [downloadUrl] = await bucket.file(candidate.storagePath).getSignedUrl({
      action: 'read',
      expires: expiresAt,
    });
    return downloadUrl;
  }

  async function fetchChatsForHouse(houseId) {
    if (!houseId) return null;
    const snap = await db
      .ref('chats')
      .orderByChild(`participants/${houseId}`)
      .equalTo(true)
      .once('value');
    const rooms = asObject(snap.val());
    if (Object.keys(rooms).length > 0) return rooms;

    const membersSnap = await db
      .ref('chats')
      .orderByChild(`members/${houseId}`)
      .equalTo(true)
      .once('value');
    return membersSnap.exists() ? membersSnap.val() : null;
  }

  async function buildMediaManifest(memories, trash, expiresAt) {
    const candidates = collectMediaCandidates(memories, trash);
    const included = [];
    let totalBytes = 0;
    for (const candidate of candidates) {
      if (included.length >= MEMORY_IMAGE_LIMIT) break;
      const sizeBytes = candidate.sizeBytes > 0 ? candidate.sizeBytes : 0;
      if (sizeBytes > 0 && totalBytes + sizeBytes > MEMORY_IMAGE_TOTAL_BYTES_LIMIT) break;
      try {
        included.push({
          memoryId: candidate.memoryId,
          fileName: candidate.fileName,
          storagePath: candidate.storagePath,
          downloadUrl: await signedUrlForCandidate(candidate, expiresAt),
          thumbUrl: candidate.thumbUrl,
          createdAt: candidate.createdAt,
          caption: candidate.caption,
          scope: candidate.scope,
          sizeBytes,
        });
        totalBytes += sizeBytes;
      } catch (error) {
        console.warn(`data export signed url failed for ${candidate.storagePath}:`, error);
      }
    }
    return {
      memoryImages: {
        mode: 'temporary_signed_urls',
        limitCount: MEMORY_IMAGE_LIMIT,
        limitBytes: MEMORY_IMAGE_TOTAL_BYTES_LIMIT,
        includedCount: included.length,
        skippedCount: Math.max(0, candidates.length - included.length),
        totalCandidateCount: candidates.length,
        expiresAt: expiresAt.toISOString(),
        note: 'Ảnh Kỷ niệm được giới hạn để tránh file quá lớn. Các link tải có thời hạn.',
        items: included,
      },
    };
  }

  function crc32(buffer) {
    let crc = 0xffffffff;
    for (let i = 0; i < buffer.length; i += 1) {
      crc ^= buffer[i];
      for (let bit = 0; bit < 8; bit += 1) {
        crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
      }
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  function dosDateTime(date) {
    const year = Math.max(1980, date.getFullYear());
    const dosTime =
      (date.getHours() << 11) |
      (date.getMinutes() << 5) |
      Math.floor(date.getSeconds() / 2);
    const dosDate =
      ((year - 1980) << 9) |
      ((date.getMonth() + 1) << 5) |
      date.getDate();
    return { dosDate, dosTime };
  }

  function createZip(files, generatedAt) {
    const localParts = [];
    const centralParts = [];
    let offset = 0;
    const { dosDate, dosTime } = dosDateTime(generatedAt);

    for (const file of files) {
      const nameBuffer = Buffer.from(file.name, 'utf8');
      const sourceBuffer = Buffer.isBuffer(file.content)
        ? file.content
        : Buffer.from(String(file.content ?? ''), 'utf8');
      const compressed = zlib.deflateRawSync(sourceBuffer);
      const checksum = crc32(sourceBuffer);

      const localHeader = Buffer.alloc(30);
      localHeader.writeUInt32LE(0x04034b50, 0);
      localHeader.writeUInt16LE(20, 4);
      localHeader.writeUInt16LE(0x0800, 6);
      localHeader.writeUInt16LE(8, 8);
      localHeader.writeUInt16LE(dosTime, 10);
      localHeader.writeUInt16LE(dosDate, 12);
      localHeader.writeUInt32LE(checksum, 14);
      localHeader.writeUInt32LE(compressed.length, 18);
      localHeader.writeUInt32LE(sourceBuffer.length, 22);
      localHeader.writeUInt16LE(nameBuffer.length, 26);
      localHeader.writeUInt16LE(0, 28);

      localParts.push(localHeader, nameBuffer, compressed);

      const centralHeader = Buffer.alloc(46);
      centralHeader.writeUInt32LE(0x02014b50, 0);
      centralHeader.writeUInt16LE(20, 4);
      centralHeader.writeUInt16LE(20, 6);
      centralHeader.writeUInt16LE(0x0800, 8);
      centralHeader.writeUInt16LE(8, 10);
      centralHeader.writeUInt16LE(dosTime, 12);
      centralHeader.writeUInt16LE(dosDate, 14);
      centralHeader.writeUInt32LE(checksum, 16);
      centralHeader.writeUInt32LE(compressed.length, 20);
      centralHeader.writeUInt32LE(sourceBuffer.length, 24);
      centralHeader.writeUInt16LE(nameBuffer.length, 28);
      centralHeader.writeUInt16LE(0, 30);
      centralHeader.writeUInt16LE(0, 32);
      centralHeader.writeUInt16LE(0, 34);
      centralHeader.writeUInt16LE(0, 36);
      centralHeader.writeUInt32LE(0, 38);
      centralHeader.writeUInt32LE(offset, 42);
      centralParts.push(centralHeader, nameBuffer);

      offset += localHeader.length + nameBuffer.length + compressed.length;
    }

    const centralDirectory = Buffer.concat(centralParts);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(0, 4);
    end.writeUInt16LE(0, 6);
    end.writeUInt16LE(files.length, 8);
    end.writeUInt16LE(files.length, 10);
    end.writeUInt32LE(centralDirectory.length, 12);
    end.writeUInt32LE(offset, 16);
    end.writeUInt16LE(0, 20);

    return Buffer.concat([...localParts, centralDirectory, end]);
  }

  function textFile(name, title, value) {
    return {
      name,
      content: `${title}\n${'='.repeat(title.length)}\n\n${formatTextValue(value)}\n`,
    };
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function formatExportDate(value) {
    const timestamp = readTimestamp(value);
    if (!timestamp) return normalizeText(value);
    try {
      return new Date(timestamp).toLocaleString('vi-VN', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch (_) {
      return new Date(timestamp).toISOString();
    }
  }

  const readableLabels = {
    uid: 'Mã người dùng',
    email: 'Email',
    profile: 'Hồ sơ',
    displayName: 'Tên hiển thị',
    photoURL: 'Ảnh đại diện',
    phoneNumber: 'Số điện thoại',
    houseId: 'Mã nhà',
    house: 'Thông tin nhà',
    public: 'Thông tin công khai',
    houses: 'Nhà / ghép đôi',
    diary: 'Nhật ký',
    diaries: 'Danh sách nhật ký',
    memories: 'Kỷ niệm',
    active: 'Đang dùng',
    trash: 'Thùng rác',
    album: 'Album',
    chats: 'Tin nhắn',
    gps_history: 'Lịch sử vị trí',
    current: 'Hiện tại',
    history: 'Lịch sử',
    presence: 'Trạng thái hiện diện',
    devices: 'Thiết bị',
    purchases: 'Gói dịch vụ',
    userVip: 'VIP tài khoản',
    houseVip: 'VIP nhà',
    local_consent: 'Quyền riêng tư trên máy',
    capturedAt: 'Ghi nhận lúc',
    values: 'Giá trị',
    manifest: 'Thông tin bản tải',
    exportId: 'Mã bản tải',
    generatedAt: 'Tạo lúc',
    expiresAt: 'Hết hạn lúc',
    range: 'Khoảng dữ liệu',
    label: 'Nhãn',
    days: 'Số ngày',
    startAt: 'Bắt đầu lúc',
    endAt: 'Kết thúc lúc',
    format: 'Định dạng',
    sections: 'Các phần dữ liệu',
    createdAt: 'Ngày tạo',
    updatedAt: 'Cập nhật lúc',
    deletedAt: 'Ngày xóa',
    timestamp: 'Thời gian',
    ts: 'Thời gian',
    title: 'Tiêu đề',
    name: 'Tên',
    text: 'Nội dung',
    message: 'Tin nhắn',
    content: 'Nội dung',
    body: 'Nội dung',
    caption: 'Chú thích',
    note: 'Ghi chú',
    imageUrl: 'Link ảnh',
    downloadUrl: 'Link tải',
    url: 'Link',
    thumbUrl: 'Ảnh thu nhỏ',
    thumbnailUrl: 'Ảnh thu nhỏ',
    storagePath: 'Đường dẫn lưu trữ',
    fileName: 'Tên file',
    sizeBytes: 'Dung lượng',
    senderId: 'Người gửi',
    senderName: 'Tên người gửi',
    authorId: 'Người viết',
    authorName: 'Tên người viết',
    role: 'Vai trò',
    members: 'Thành viên',
    participants: 'Người tham gia',
    status: 'Trạng thái',
    favorite: 'Đã đánh dấu yêu thích',
    pinned: 'Đã ghim',
    latitude: 'Vĩ độ',
    longitude: 'Kinh độ',
    lat: 'Vĩ độ',
    lng: 'Kinh độ',
    accuracy: 'Độ chính xác',
    address: 'Địa chỉ',
    includedCount: 'Số ảnh đã thêm',
    skippedCount: 'Số ảnh bỏ qua',
    totalCandidateCount: 'Tổng số ảnh tìm thấy',
    limitCount: 'Giới hạn số ảnh',
    limitBytes: 'Giới hạn dung lượng',
    memoryImages: 'Ảnh Kỷ niệm',
    items: 'Danh sách',
    mode: 'Chế độ',
    il_tos_accepted: 'Đã chấp nhận điều khoản',
    il_privacy_accepted: 'Đã chấp nhận quyền riêng tư',
    il_cookie_storage_consent: 'Đồng ý lưu cookie/dữ liệu cục bộ',
    il_security_device_signals_consent: 'Đồng ý tín hiệu bảo mật thiết bị',
  };

  function readableLabel(key) {
    const raw = normalizeText(key);
    if (!raw) return 'Mục';
    if (readableLabels[raw]) return readableLabels[raw];
    const spaced = raw
      .replace(/[_-]+/g, ' ')
      .replace(/([a-z])([A-Z])/g, '$1 $2')
      .trim();
    if (!spaced) return raw;
    return spaced.charAt(0).toUpperCase() + spaced.slice(1);
  }

  function shouldFormatAsDate(key, value) {
    const normalized = normalizeText(key).toLowerCase();
    if (typeof value === 'number' && value > 100000000000) return true;
    const dateKeys = new Set([
      'createdat',
      'updatedat',
      'deletedat',
      'capturedat',
      'expiresat',
      'joinedat',
      'lastseenat',
      'lastactiveat',
      'pinnedat',
    ]);
    return (
      dateKeys.has(normalized.replace(/[^a-z0-9]/g, '')) ||
      normalized.includes('date') ||
      normalized.includes('time') ||
      normalized.includes('timestamp')
    );
  }

  function formatPrimitive(key, value) {
    if (value == null || value === '') return '(không có)';
    if (typeof value === 'boolean') return value ? 'Có' : 'Không';
    if (shouldFormatAsDate(key, value)) {
      const formatted = formatExportDate(value);
      return formatted || String(value);
    }
    if (typeof value === 'number' && String(key).toLowerCase().includes('bytes')) {
      return formatBytes(value);
    }
    return String(value);
  }

  function formatBytes(value) {
    const bytes = Number(value) || 0;
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    let size = bytes;
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
  }

  function looksLikeGeneratedId(key) {
    const raw = normalizeText(key);
    return raw.length >= 16 && /^[A-Za-z0-9_-]+$/.test(raw);
  }

  function readableItemTitle(value, fallback) {
    const item = asObject(value);
    return normalizeText(
      item.title ||
      item.name ||
      item.displayName ||
      item.caption ||
      item.text ||
      item.message ||
      item.content ||
      fallback,
    );
  }

  function formatObjectHeader(key, value) {
    const title = readableItemTitle(value, '');
    const date = formatExportDate(
      asObject(value).createdAt ||
      asObject(value).updatedAt ||
      asObject(value).timestamp ||
      asObject(value).ts,
    );
    if (looksLikeGeneratedId(key)) {
      return title ? `${title}${date ? ` (${date})` : ''}` : `Mục ${key}`;
    }
    return readableLabel(key);
  }

  function formatTextValue(value, depth = 0, key = '') {
    const indent = '  '.repeat(depth);
    if (value == null) return `${indent}(không có dữ liệu)`;
    if (typeof value !== 'object') {
      return `${indent}${formatPrimitive(key, value)}`;
    }
    if (Array.isArray(value)) {
      if (value.length === 0) return `${indent}(trống)`;
      return value
        .map((item, index) => {
          if (item && typeof item === 'object') {
            const title = readableItemTitle(item, '');
            const line = title ? `${index + 1}. ${title}` : `${index + 1}.`;
            return `${indent}${line}\n${formatTextValue(item, depth + 1, key)}`;
          }
          return `${indent}${index + 1}. ${formatTextValue(item, 0, key).trim()}`;
        })
        .join('\n');
    }

    const entries = Object.entries(value);
    if (entries.length === 0) return `${indent}(trống)`;
    return entries
      .map(([key, child]) => {
        if (child && typeof child === 'object') {
          return `${indent}${formatObjectHeader(key, child)}:\n${formatTextValue(child, depth + 1, key)}`;
        }
        return `${indent}${readableLabel(key)}: ${formatTextValue(child, 0, key).trim()}`;
      })
      .join('\n');
  }

  function countTopLevel(value) {
    if (Array.isArray(value)) return value.length;
    if (value && typeof value === 'object') return Object.keys(value).length;
    return value == null ? 0 : 1;
  }

  function buildMediaText(mediaManifest) {
    const media = asObject(mediaManifest.memoryImages);
    const items = Array.isArray(media.items) ? media.items : [];
    if (items.length === 0) {
      return 'Chưa có ảnh Kỷ niệm nào được đưa vào bản tải xuống này.\n';
    }
    return items
      .map((item, index) => {
        const mediaItem = asObject(item);
        return [
          `${index + 1}. ${normalizeText(mediaItem.caption) || normalizeText(mediaItem.fileName) || 'Ảnh kỷ niệm'}`,
          `   Ngày tạo: ${formatExportDate(mediaItem.createdAt) || '(không rõ)'}`,
          `   Trạng thái: ${normalizeText(mediaItem.scope) || '(không rõ)'}`,
          `   Link tải tạm thời: ${normalizeText(mediaItem.downloadUrl) || '(không có)'}`,
          mediaItem.storagePath ? `   Đường dẫn lưu trữ: ${mediaItem.storagePath}` : '',
        ]
          .filter(Boolean)
          .join('\n');
      })
      .join('\n\n');
  }

  function buildIndexHtml(payload, mediaManifest) {
    const media = asObject(mediaManifest.memoryImages);
    const items = Array.isArray(media.items) ? media.items : [];
    const sectionCards = [
      ['account.txt', 'Tài khoản', payload.account],
      ['houses.txt', 'Nhà / ghép đôi', payload.houses],
      ['diary.txt', 'Nhật ký', payload.diary],
      ['memories.txt', 'Kỷ niệm', payload.memories],
      ['album.txt', 'Album', payload.album],
      ['chats.txt', 'Tin nhắn', payload.chats],
      ['gps_history.txt', 'Vị trí', payload.gps_history],
      ['purchases.txt', 'Gói dịch vụ', payload.purchases],
      ['devices.txt', 'Thiết bị', payload.devices],
      ['privacy_consent.txt', 'Quyền riêng tư', payload.local_consent],
    ];

    const cardsHtml = sectionCards
      .map(([href, title, value]) => `
        <a class="card" href="${href}">
          <strong>${escapeHtml(title)}</strong>
          <span>${countTopLevel(value)} mục</span>
        </a>`)
      .join('');

    const galleryHtml = items.length === 0
      ? '<p class="empty">Không có ảnh Kỷ niệm trong bản tải này.</p>'
      : items.map((item) => {
        const mediaItem = asObject(item);
        const title = normalizeText(mediaItem.caption) || normalizeText(mediaItem.fileName) || 'Ảnh kỷ niệm';
        const url = normalizeText(mediaItem.downloadUrl);
        return `
          <figure>
            ${url ? `<a href="${escapeHtml(url)}" target="_blank" rel="noopener"><img src="${escapeHtml(url)}" alt="${escapeHtml(title)}" loading="lazy"></a>` : '<div class="missing">Không có link ảnh</div>'}
            <figcaption>
              <strong>${escapeHtml(title)}</strong>
              <span>${escapeHtml(formatExportDate(mediaItem.createdAt) || '')}</span>
            </figcaption>
          </figure>`;
      }).join('');

    return `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SoulLocket - Bản tải dữ liệu</title>
  <style>
    body{margin:0;font-family:Arial,sans-serif;background:#f4f8fb;color:#223044;line-height:1.55}
    main{max-width:1080px;margin:0 auto;padding:28px 18px 48px}
    header{background:#fff;border:1px solid #dbe7f2;border-radius:22px;padding:24px;box-shadow:0 12px 34px rgba(31,77,116,.08)}
    h1{margin:0 0 10px;color:#1565c0;font-size:30px}
    h2{margin:30px 0 14px;color:#164b73}
    .meta{color:#5b6b80;font-weight:700}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px}
    .card{display:block;text-decoration:none;color:#223044;background:#fff;border:1px solid #dbe7f2;border-radius:16px;padding:16px;box-shadow:0 8px 24px rgba(31,77,116,.06)}
    .card strong{display:block;font-size:17px}.card span{color:#607287;font-size:13px}
    .gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px}
    figure{margin:0;background:#fff;border:1px solid #dbe7f2;border-radius:16px;overflow:hidden}
    img{display:block;width:100%;height:190px;object-fit:cover;background:#eaf2f8}
    figcaption{padding:10px 12px}figcaption strong,figcaption span{display:block}figcaption span{font-size:12px;color:#607287}
    .note,.empty{background:#fff;border:1px solid #dbe7f2;border-radius:16px;padding:14px;color:#4e6176}
    .missing{height:190px;display:grid;place-items:center;background:#eaf2f8;color:#607287}
  </style>
</head>
<body>
  <main>
    <header>
      <h1>Bản tải dữ liệu SoulLocket</h1>
      <div class="meta">Tạo lúc: ${escapeHtml(formatExportDate(payload.manifest.generatedAt))}</div>
      <div class="meta">Khoảng dữ liệu: ${escapeHtml(asObject(payload.manifest.range).label || '')}</div>
      <div class="meta">Link ảnh hết hạn: ${escapeHtml(formatExportDate(payload.manifest.expiresAt))}</div>
      <p class="note">File này có thể chứa tin nhắn, vị trí và dữ liệu riêng tư. Chỉ chia sẻ với người bạn tin tưởng.</p>
    </header>
    <h2>Các phần dữ liệu dạng TXT</h2>
    <section class="grid">${cardsHtml}</section>
    <h2>Ảnh Kỷ niệm</h2>
    <p class="note">Ảnh bên dưới dùng link tải tạm thời, tối đa ${media.limitCount || MEMORY_IMAGE_LIMIT} ảnh mỗi lần export.</p>
    <section class="gallery">${galleryHtml}</section>
  </main>
</body>
</html>`;
  }

  async function assertRateLimit(uid, now) {
    const requestsSnap = await db
      .ref(`data_exports/${uid}/requests`)
      .orderByChild('createdAt')
      .limitToLast(1)
      .once('value');
    const requests = asObject(requestsSnap.val());
    const latest = Object.values(requests)
      .map(asObject)
      .map((entry) => Number(entry.createdAt || 0) || 0)
      .sort((a, b) => b - a)[0];
    if (latest && now - latest < EXPORT_RATE_LIMIT_MS) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Bạn vừa tạo bản tải xuống gần đây. Hãy thử lại sau khoảng 15 phút.',
      );
    }
  }

  async function requestUserDataExport(data, context) {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Bạn cần đăng nhập để tải dữ liệu.');
    }

    const uid = context.auth.uid;
    const now = Date.now();
    const rangeDays = normalizeExportRangeDays(data);
    const exportStartAt = now - rangeDays * 24 * 60 * 60 * 1000;
    await assertRateLimit(uid, now);

    const userData = await getValue(`users/${uid}`);
    const houseId = readHouseId(userData);
    const houseData = houseId ? await getValue(`houses/${houseId}`) : null;
    if (houseId && !isHouseMember(uid, houseData)) {
      throw new functions.https.HttpsError('permission-denied', 'Bạn không có quyền tải dữ liệu nhà này.');
    }
    const role = houseId ? readUserRole(uid, houseData) : '';
    const expiresAt = new Date(now + EXPORT_URL_TTL_MS);

    const [
      housesPublic,
      houseProfiles,
      diary,
      diaries,
      memories,
      memoriesTrash,
      album,
      albumTrash,
      chats,
      gpsCurrent,
      gpsHistory,
      presence,
      devices,
      userVip,
      houseVip,
    ] = await Promise.all([
      houseId ? getValue(`houses_public/${houseId}`) : null,
      houseId ? getValue(`house_profiles/${houseId}`) : null,
      houseId ? getValue(`houses/${houseId}/diary`) : null,
      houseId ? getValue(`houses/${houseId}/diaries`) : null,
      houseId ? getValue(`houses/${houseId}/memories`) : null,
      houseId ? getValue(`houses/${houseId}/memories_trash`) : null,
      houseId ? getValue(`houses/${houseId}/album`) : null,
      houseId ? getValue(`houses/${houseId}/album_trash`) : null,
      houseId ? fetchChatsForHouse(houseId) : null,
      houseId && role ? getValue(`gps/${houseId}/${role}`) : null,
      houseId && role ? getValue(`gps_history/${houseId}/${role}`) : null,
      houseId && role ? getValue(`houses/${houseId}/presence/${role}`) : null,
      houseId ? getValue(`houses/${houseId}/security/devices/${uid}`) : null,
      getValue(`users/${uid}/vip`),
      houseId ? getValue(`houses/${houseId}/vip`) : null,
    ]);

    const filteredDiary = filterRecentPayload(diary, exportStartAt);
    const filteredDiaries = filterRecentPayload(diaries, exportStartAt);
    const filteredMemories = filterRecentPayload(memories, exportStartAt);
    const filteredMemoriesTrash = filterRecentPayload(memoriesTrash, exportStartAt);
    const filteredAlbum = filterRecentPayload(album, exportStartAt);
    const filteredAlbumTrash = filterRecentPayload(albumTrash, exportStartAt);
    const filteredChats = filterRecentPayload(chats, exportStartAt);
    const filteredGpsCurrent = filterRecentPayload(gpsCurrent, exportStartAt);
    const filteredGpsHistory = filterRecentPayload(gpsHistory, exportStartAt);
    const filteredPresence = filterRecentPayload(presence, exportStartAt);
    const filteredDevices = filterRecentPayload(devices, exportStartAt);

    const mediaManifest = await buildMediaManifest(filteredMemories, filteredMemoriesTrash, expiresAt);
    const exportId = `${now}-${crypto.randomBytes(6).toString('hex')}`;
    const sections = [
      'account',
      'houses',
      'diary',
      'memories',
      'album',
      'chats',
      'gps_history',
      'presence',
      'purchases',
      'devices',
      'local_consent',
      'media_manifest',
    ];
    const manifest = {
      exportId,
      generatedAt: new Date(now).toISOString(),
      expiresAt: expiresAt.toISOString(),
      range: {
        days: rangeDays,
        label: exportRangeLabel(rangeDays),
        startAt: new Date(exportStartAt).toISOString(),
        endAt: new Date(now).toISOString(),
      },
      format: 'zip_html_txt',
      sections,
    };
    const readme = [
      'SoulLocket Data Export',
      '',
      'Mở index.html để xem bản dễ đọc.',
      'Các phần dữ liệu còn lại được ghi thành file .txt.',
      'Ảnh Kỷ niệm hiển thị trong index.html bằng link tải tạm thời.',
      '',
      'File này có thể chứa dữ liệu nhạy cảm như tin nhắn và vị trí.',
      'Chỉ chia sẻ với người bạn tin tưởng.',
      '',
      `Export ID: ${exportId}`,
      `Generated At: ${manifest.generatedAt}`,
      `Data Range: ${manifest.range.label} (${manifest.range.startAt} - ${manifest.range.endAt})`,
      `Link Expires At: ${manifest.expiresAt}`,
      `Memory Images Included: ${mediaManifest.memoryImages.includedCount}`,
      `Memory Images Skipped: ${mediaManifest.memoryImages.skippedCount}`,
    ].join('\n');

    const payloadByFile = redact({
      manifest,
      account: { uid, email: context.auth.token.email || null, profile: userData },
      houses: { houseId, house: houseData, public: housesPublic, profile: houseProfiles },
      diary: { diary: filteredDiary, diaries: filteredDiaries },
      memories: { active: filteredMemories, trash: filteredMemoriesTrash },
      album: { active: filteredAlbum, trash: filteredAlbumTrash },
      chats: filteredChats,
      gps_history: { current: filteredGpsCurrent, history: filteredGpsHistory },
      presence: filteredPresence,
      devices: filteredDevices,
      purchases: { userVip, houseVip },
      local_consent: pickConsent(asObject(data).localConsent),
      media_manifest: mediaManifest,
    });

    const indexHtml = buildIndexHtml(payloadByFile, mediaManifest);
    const files = [
      { name: 'README.txt', content: `${readme}\n` },
      { name: 'index.html', content: indexHtml },
      textFile('manifest.txt', 'Thông tin bản tải', payloadByFile.manifest),
      textFile('account.txt', 'Tài khoản', payloadByFile.account),
      textFile('houses.txt', 'Nhà / ghép đôi', payloadByFile.houses),
      textFile('diary.txt', 'Nhật ký', payloadByFile.diary),
      textFile('memories.txt', 'Kỷ niệm', payloadByFile.memories),
      textFile('album.txt', 'Album', payloadByFile.album),
      textFile('chats.txt', 'Tin nhắn', payloadByFile.chats),
      textFile('gps_history.txt', 'Vị trí', payloadByFile.gps_history),
      textFile('purchases.txt', 'Gói dịch vụ', payloadByFile.purchases),
      textFile('devices.txt', 'Thiết bị', payloadByFile.devices),
      textFile('privacy_consent.txt', 'Quyền riêng tư', payloadByFile.local_consent),
      textFile('presence.txt', 'Trạng thái hiện diện', payloadByFile.presence),
      {
        name: 'media_links.txt',
        content: `Ảnh Kỷ niệm\n===========\n\n${buildMediaText(payloadByFile.media_manifest)}\n`,
      },
    ];

    const zipBuffer = createZip(files, new Date(now));
    const exportFolderPath = `exports/user-data/${uid}/${exportId}`;
    const storagePath = `${exportFolderPath}/soullocket-data-export.zip`;
    const file = bucket.file(storagePath);
    await file.save(zipBuffer, {
      contentType: 'application/zip',
      resumable: false,
      metadata: {
        cacheControl: 'private, max-age=0, no-transform',
      },
    });

    const htmlStoragePath = `${exportFolderPath}/index.html`;
    const htmlFile = bucket.file(htmlStoragePath);
    await htmlFile.save(indexHtml, {
      contentType: 'text/html; charset=utf-8',
      resumable: false,
      metadata: {
        cacheControl: 'private, max-age=0, no-transform',
      },
    });

    const [downloadUrl] = await file.getSignedUrl({ action: 'read', expires: expiresAt });
    const [htmlUrl] = await htmlFile.getSignedUrl({ action: 'read', expires: expiresAt });
    const sizeBytes = zipBuffer.length;
    const record = {
      createdAt: now,
      status: 'ready',
      expiresAt: expiresAt.getTime(),
      sizeBytes,
      sections,
      storagePath,
      htmlStoragePath,
      memoryImageLimit: MEMORY_IMAGE_LIMIT,
      rangeDays,
      rangeStartAt: exportStartAt,
      rangeEndAt: now,
      memoryImagesIncluded: mediaManifest.memoryImages.includedCount,
      memoryImagesSkipped: mediaManifest.memoryImages.skippedCount,
    };
    await db.ref(`data_exports/${uid}/requests/${exportId}`).set(record);

    return {
      success: true,
      exportId,
      downloadUrl,
      htmlUrl,
      expiresAt: expiresAt.toISOString(),
      sizeBytes,
      sections,
      memoryImagesIncluded: mediaManifest.memoryImages.includedCount,
      memoryImagesSkipped: mediaManifest.memoryImages.skippedCount,
      rangeDays,
    };
  }

  return {
    requestUserDataExport: functions.https.onCall(requestUserDataExport),
  };
}

module.exports = { createDataExportModule };
