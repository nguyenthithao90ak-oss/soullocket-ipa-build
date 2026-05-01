import 'package:firebase_auth/firebase_auth.dart';

class SpecialAccessService {
  SpecialAccessService._();

  static const String specialUid = '';

  static const int privilegedExpiryMs = 4102444800000;

  static bool isPrivilegedUid(String? uid) {
    return false;
  }

  static bool isCurrentUserPrivileged([FirebaseAuth? auth]) {
    return false;
  }
}
