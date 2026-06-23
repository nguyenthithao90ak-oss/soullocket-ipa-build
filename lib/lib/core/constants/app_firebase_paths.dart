class AppFirebasePaths {
  // Collection nodes
  static const String users = 'users'; // user profiles and mapping
  static const String houses = 'houses'; // private house data
  static const String housesPublic = 'houses_public'; // public house data
  static const String houseProfiles = 'house_profiles'; // public profile data
  static const String friendRequests = 'friend_requests';
  static const String friends = 'friends';
  static const String notifications = 'notifications';
  static const String messages = 'messages'; // private messages
  static const String conversations = 'conversations';
  static const String groups = 'groups';
  static const String calls = 'calls'; // video/audio calls
  static const String feed = 'feed'; // personal feeds
  static const String appeals = 'appeals'; // user appeals
  static const String supportTickets = 'support_tickets';
  static const String presence =
      'presence'; // fallback presence node outside of house?
  static const String adminSystem =
      'admin_system'; // all admin control and logs
  static const String adminControls = 'admin_controls'; // broadcast and links
  static const String reports = 'reports'; // reported content
  static const String uploads = 'uploads'; // upload tracking (totals)
  static const String dailyQuestion = 'daily_question';
  static const String gps = 'gps';
  static const String invites = 'invites';
  static const String metrics = 'metrics';

  // Sub-paths logic
  static String userProfile(String uid) => '$users/$uid';
  static String houseDoc(String houseId) => '$houses/$houseId';
  static String houseSettings(String houseId) =>
      '${houseDoc(houseId)}/settings';
  static String houseSecurity(String houseId) =>
      '${houseDoc(houseId)}/security';
  static String housePresence(String houseId) =>
      '${houseDoc(houseId)}/presence';
  static String houseMembers(String houseId) => '${houseDoc(houseId)}/members';
  static String housePet(String houseId) => '${houseDoc(houseId)}/pet';
  static String houseBlockedUsers(String houseId) =>
      '${houseDoc(houseId)}/blocked_users';
  static String houseLoginHistory(String houseId) =>
      '${houseDoc(houseId)}/loginHistory';
  static String houseChatRooms(String houseId) =>
      '${houseDoc(houseId)}/chat_rooms';

  static String housePublicDoc(String houseId) => '$housesPublic/$houseId';
  static String houseProfileDoc(String houseId) => '$houseProfiles/$houseId';

  static String notificationsForHouse(String houseId) =>
      '$notifications/$houseId';

  static String friendRequestsPath() => friendRequests;
  static String friendsForHouse(String houseId) => '$friends/$houseId';

  static String callsForHouse(String houseId) => '$calls/$houseId';
  static String incomingCall(String houseId) =>
      '${callsForHouse(houseId)}/incoming';
}
