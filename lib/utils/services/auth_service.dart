import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';

import 'auth/auth_admin_service.dart';
import 'auth/auth_house_context_service.dart';
import 'auth/play_integrity_service.dart';
import 'auth/auth_recovery_service.dart';
import 'auth/auth_sign_in_service.dart';
import 'auth/auth_support.dart' as auth_support;
import 'consent_service.dart';

export 'auth/play_integrity_service.dart'
    show
        PlayIntegrityAssessment,
        PlayIntegrityAssessmentStatus,
        PlayIntegrityRiskLevel;

class AuthService {
  AuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseRef,
    ConsentService? consentService,
    auth_support.SharedPreferencesProvider? sharedPreferencesProvider,
    auth_support.GoogleSignInBuilder? googleSignInBuilder,
    FirebaseFunctions? firebaseFunctions,
    auth_support.HttpGet? httpGet,
    auth_support.HttpPost? httpPost,
    auth_support.NowProvider? nowProvider,
  })  : _firebaseAuth = firebaseAuth,
        _databaseRef = databaseRef {
    _adminService = AuthAdminService(
      firebaseAuth: firebaseAuth,
      databaseRef: databaseRef,
    );
    _houseContextService = AuthHouseContextService(
      firebaseAuth: firebaseAuth,
      databaseRef: databaseRef,
      consentService: consentService,
      sharedPreferencesProvider: sharedPreferencesProvider,
      httpGet: httpGet,
      nowProvider: nowProvider,
    );
    _playIntegrityService = PlayIntegrityService(
      firebaseAuth: firebaseAuth,
      httpPost: httpPost,
      nowProvider: nowProvider,
    );
    _recoveryService = AuthRecoveryService(
      firebaseAuth: firebaseAuth,
      databaseRef: databaseRef,
      firebaseFunctions: firebaseFunctions,
    );
    _signInService = AuthSignInService(
      firebaseAuth: firebaseAuth,
      databaseRef: databaseRef,
      sharedPreferencesProvider: sharedPreferencesProvider,
      googleSignInBuilder: googleSignInBuilder,
      firebaseFunctions: firebaseFunctions,
      httpPost: httpPost,
      nowProvider: nowProvider,
      adminService: _adminService,
      houseContextService: _houseContextService,
    );
  }

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;

  late final AuthAdminService _adminService;
  late final AuthHouseContextService _houseContextService;
  late final PlayIntegrityService _playIntegrityService;
  late final AuthRecoveryService _recoveryService;
  late final AuthSignInService _signInService;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();

  String normalizeEmailKey(String email) =>
      auth_support.normalizeEmailKey(email);

  String normalizeSecurityEmail(String email) =>
      auth_support.normalizeSecurityEmail(email);

  String relationshipModePrefsKey(String email) =>
      auth_support.relationshipModePrefsKey(email);

  String? normalizeRelationshipMode(String? value) =>
      auth_support.normalizeRelationshipMode(value);

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) {
    return _adminService.isCurrentUserAdmin(forceRefresh: forceRefresh);
  }

  Future<bool> isUserAdmin(
    firebase_auth.User? user, {
    bool forceRefresh = false,
  }) {
    return _adminService.isUserAdmin(user, forceRefresh: forceRefresh);
  }

  Future<bool> isMaintenanceModeEnabled() {
    return _adminService.isMaintenanceModeEnabled();
  }

  Future<String?> getSystemBlockReason(
    String email, {
    bool allowAdminBypass = false,
    bool forceRefreshAdmin = false,
  }) {
    return _adminService.getSystemBlockReason(
      email,
      allowAdminBypass: allowAdminBypass,
      forceRefreshAdmin: forceRefreshAdmin,
    );
  }

  Future<String?> getCurrentUserBlockReason() {
    return _adminService.getCurrentUserBlockReason();
  }

  Future<String?> getCachedRelationshipModeForEmail(String email) {
    return _houseContextService.getCachedRelationshipModeForEmail(email);
  }

  Future<void> cacheRelationshipModeForEmail(String email, String mode) {
    return _houseContextService.cacheRelationshipModeForEmail(email, mode);
  }

  Future<void> savePendingRelationshipModeForCurrentUser(String mode) {
    return _houseContextService.savePendingRelationshipModeForCurrentUser(mode);
  }

  Future<String?> syncRelationshipModeForCurrentUser({
    firebase_auth.User? user,
    String? houseId,
  }) {
    return _houseContextService.syncRelationshipModeForCurrentUser(
      user: user,
      houseId: houseId,
    );
  }

  Future<String?> getDeviceId() {
    return _houseContextService.getDeviceId();
  }

  Future<void> checkBanStatus(String? houseId) {
    return _houseContextService.checkBanStatus(
      houseId,
      onForcedSignOut: signOut,
    );
  }

  Future<bool> checkDailyLoginLimit(String email) {
    return _signInService.checkDailyLoginLimit(email);
  }

  Future<bool> recordDailyLoginLimit(String email) {
    return _signInService.recordDailyLoginLimit(email);
  }

  Future<String> detectAutoRole(String? houseId) {
    return _houseContextService.detectAutoRole(houseId);
  }

  Map<String, dynamic> buildPublicRecoveryMeta(String email) {
    return _houseContextService.buildPublicRecoveryMeta(email);
  }

  Future<String?> resolveCurrentHouseId({firebase_auth.User? user}) {
    return _houseContextService.resolveCurrentHouseId(user: user);
  }

  Future<void> syncSecurityEmailForCurrentUser({
    firebase_auth.User? user,
    String? email,
    String? houseId,
  }) {
    return _houseContextService.syncSecurityEmailForCurrentUser(
      user: user,
      email: email,
      houseId: houseId,
    );
  }

  Future<bool> isGoogleLinkedCurrentUser() {
    return _signInService.isGoogleLinkedCurrentUser();
  }

  Future<bool> isAppleLinkedCurrentUser() {
    return _signInService.isAppleLinkedCurrentUser();
  }

  Future<bool> isPasswordLinkedCurrentUser() {
    return _signInService.isPasswordLinkedCurrentUser();
  }

  Future<void> linkGoogleToCurrentUser() {
    return _signInService.linkGoogleToCurrentUser();
  }

  Future<void> linkAppleToCurrentUser() {
    return _signInService.linkAppleToCurrentUser();
  }

  Future<void> createPasswordForCurrentUser(String newPassword) {
    return _signInService.createPasswordForCurrentUser(newPassword);
  }

  Future<String> resolveLoginEmailAlias(
    String email, {
    bool allowFallbackOnFailure = false,
  }) {
    return _signInService.resolveLoginEmailAlias(
      email,
      allowFallbackOnFailure: allowFallbackOnFailure,
    );
  }

  Future<void> validateLoginEmailAliasForCurrentUser(String email) {
    return _signInService.validateLoginEmailAliasForCurrentUser(email);
  }

  Future<firebase_auth.UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) {
    return _signInService.signInWithEmailPassword(email, password);
  }

  Future<firebase_auth.UserCredential?> signInWithGoogle() {
    return _signInService.signInWithGoogle();
  }

  Future<firebase_auth.UserCredential?> signInWithFacebook() {
    return _signInService.signInWithFacebook();
  }

  Future<firebase_auth.UserCredential?> signInWithApple() {
    return _signInService.signInWithApple();
  }

  Future<void> checkRollingRegisterLimit() {
    return _signInService.checkRollingRegisterLimit();
  }

  Future<Map<String, dynamic>?> getHouseSecurityData(String houseId) {
    return _recoveryService.getHouseSecurityData(houseId);
  }

  String maskEmail(String email) => _recoveryService.maskEmail(email);

  Future<String?> findEmailByHouseId(String houseId) {
    return _recoveryService.findEmailByHouseId(houseId);
  }

  Future<bool> verifySecurityAnswer(String houseId, String answer) {
    return _recoveryService.verifySecurityAnswer(houseId, answer);
  }

  bool matchesRecoveryAnswer(String? storedAnswer, String inputAnswer) {
    return _recoveryService.matchesRecoveryAnswer(storedAnswer, inputAnswer);
  }

  Future<bool> verifyPin(String houseId, String pin) {
    return _recoveryService.verifyPin(houseId, pin);
  }

  Future<firebase_auth.UserCredential?> registerWithEmailPassword(
    String email,
    String password,
  ) {
    return _signInService.registerWithEmailPassword(email, password);
  }

  Future<bool> rollbackIncompleteEmailSignup(String email) {
    return _signInService.rollbackIncompleteEmailSignup(email);
  }

  Future<void> signOut() {
    return _signInService.signOut();
  }

  Future<Map<String, dynamic>> deleteAccount() {
    return _signInService.deleteAccount();
  }

  Future<void> undoScheduledDeletion() {
    return _signInService.undoScheduledDeletion();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _recoveryService.sendPasswordResetEmail(email);
  }

  Future<void> sendOtpEmail(String email) {
    return _recoveryService.sendOtpEmail(email);
  }

  Future<String> verifyOtpAndGetToken(String email, String otp) {
    return _recoveryService.verifyOtpAndGetToken(email, otp);
  }

  Future<void> verifyPrimaryEmailOTP(String email, String otp) {
    return _recoveryService.verifyPrimaryEmailOTP(email, otp);
  }

  Future<void> validateEmailOTP(String email, String otp) {
    return _recoveryService.validateEmailOTP(email, otp);
  }

  Future<bool> warmUpPlayIntegrity({bool force = false}) {
    return _playIntegrityService.warmUp(force: force);
  }

  Future<PlayIntegrityAssessment> assessPlayIntegrity({
    required String flow,
    String? uid,
    String? houseId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    bool autoWarmUp = true,
  }) {
    return _playIntegrityService.assess(
      flow: flow,
      uid: uid,
      houseId: houseId,
      payload: payload,
      autoWarmUp: autoWarmUp,
    );
  }

  Future<void> signInWithCustomTokenAndSetPassword(
    String token,
    String newPassword,
  ) {
    return _recoveryService.signInWithCustomTokenAndSetPassword(
      token,
      newPassword,
    );
  }

  Future<String> verifyPasswordResetCode(String code) {
    return _recoveryService.verifyPasswordResetCode(code);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _recoveryService.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  firebase_auth.User? get currentUser => _auth.currentUser;

  DatabaseReference getDatabaseRef() => _db;

  String hashRecoveryAnswer(String input) {
    return _recoveryService.hashRecoveryAnswer(input);
  }

  String hashHousePin(String input) {
    return _recoveryService.hashHousePin(input);
  }
}
