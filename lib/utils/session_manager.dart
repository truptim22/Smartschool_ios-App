// ignore_for_file: avoid_print, duplicate_ignore

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import 'package:uuid/uuid.dart';

class SessionManager {

  static const String _prefsName    = 'MyDschool_V3';
  static const String _keyCurrentUser = 'currentUser';
  static const String _keyUserId    = 'user_id';
  static const String _keyClassId   = 'classId';
  static const String _keyUsername  = 'username';
  static const String _keyStudentId = 'student_id';
  static const String _keyFcmToken  = 'fcm_token';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keySiblings  = 'siblings_session';
  static const String _keyAppInstallId = 'app_install_id';

  // ─────────────────────────────────────────────────────────
  // FIX: bump this number every time you update Flutter/deps
  // that touch shared_preferences. When the stored version
  // doesn't match, we force a clean session wipe.
  // ─────────────────────────────────────────────────────────
  static const int    _currentSessionVersion = 3; // ← increment if issue recurs
  static const String _keySessionVersion     = 'session_version';

  // ─────────────────────────────────────────────────────────
  // REINSTALL / VERSION CHECK
  // Called once in main() before runApp()
  // ─────────────────────────────────────────────────────────
  static Future<void> checkAndHandleReinstall() async {
    final prefs = await SharedPreferences.getInstance();

    final savedInstallId      = prefs.getString(_keyAppInstallId);
    final savedSessionVersion = prefs.getInt(_keySessionVersion);

    // Case 1: brand-new install — no install ID at all
    if (savedInstallId == null) {
      print('🆕 Fresh install detected — generating install ID & clearing data');
      await _setupFreshInstall(prefs);
      return;
    }

    // Case 2: Flutter/deps update changed prefs internals → version mismatch
    // This is the bug you hit: old data survives because the install ID
    // was found, so forceDeleteSession() was never called.
    if (savedSessionVersion == null ||
        savedSessionVersion < _currentSessionVersion) {
      print('⚠️  Session version mismatch '
            '(stored: $savedSessionVersion, current: $_currentSessionVersion)');
      print('   Clearing stale session from old app version...');
      await _setupFreshInstall(prefs);
      return;
    }
    print('✅ Session OK — version $_currentSessionVersion, '
          'install: $savedInstallId');
  }

  // Internal helper — wipes data, writes fresh install markers
  static Future<void> _setupFreshInstall(SharedPreferences prefs) async {
    final newInstallId = const Uuid().v4();

    // Save FCM token if it exists before clearing
    final oldFcm = prefs.getString(_keyFcmToken);

    await prefs.clear();

    await prefs.setString(_keyAppInstallId,   newInstallId);
    await prefs.setInt(   _keySessionVersion, _currentSessionVersion);

    if (oldFcm != null) {
      await prefs.setString(_keyFcmToken, oldFcm);
    }

    print('✅ Fresh install setup complete — ID: $newInstallId');
  }

  // ─────────────────────────────────────────────────────────
  // FORCE DELETE (used by logout + reinstall detection)
  // ─────────────────────────────────────────────────────────
  static Future<void> forceDeleteSession() async {
    print('💣 FORCE DELETE — removing all session data');
    final prefs = await SharedPreferences.getInstance();

    final installId      = prefs.getString(_keyAppInstallId);
    final sessionVersion = prefs.getInt(_keySessionVersion);
    final fcmToken       = prefs.getString(_keyFcmToken);

    await prefs.clear();

    // Always restore structural keys so reinstall logic still works
    if (installId      != null) await prefs.setString(_keyAppInstallId,   installId);
    if (sessionVersion != null) await prefs.setInt(   _keySessionVersion, sessionVersion);
    if (fcmToken       != null) await prefs.setString(_keyFcmToken,       fcmToken);

    print('✅ Session deleted');
  }

  // ─────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────
  static Future<void> logout() async {
    print('🚪 LOGOUT — clearing session');
    await forceDeleteSession();
  }

  // ─────────────────────────────────────────────────────────
  // SAVE USER
  // ─────────────────────────────────────────────────────────
  static Future<void> saveUser(User user) async {
  // ✅ Add this line at the top
  print('💾 SAVING USER — clearing previous session first');
  final prefs = await SharedPreferences.getInstance();
  
  // ✅ Clear user-specific keys before saving new user
  await prefs.remove(_keyCurrentUser);
  await prefs.remove(_keyStudentId);
  await prefs.remove(_keyUserId);
  await prefs.remove(_keyIsLoggedIn);
  
  // Then save fresh
  await prefs.setString(_keyCurrentUser, json.encode(user.toJson()));
  await prefs.setInt(_keyUserId, user.id);
  await prefs.setString(_keyUsername, user.username);
  await prefs.setInt(_keyStudentId, user.studentId ?? -1);
  await prefs.setBool(_keyIsLoggedIn, true);

  print('✅ User session saved — ${user.username} (studentId: ${user.studentId})');
}
  // ─────────────────────────────────────────────────────────
  // GET USER
  // ─────────────────────────────────────────────────────────
  static Future<User?> getUser() async {
    final prefs   = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCurrentUser);

    if (userJson == null) {
      print('⚠️  No user session found');
      return null;
    }

    try {
      return User.fromJson(json.decode(userJson) as Map<String, dynamic>);
    } catch (e) {
      print('❌ Failed to parse user session: $e');
      // Corrupt data — wipe it so the user isn't stuck
      await forceDeleteSession();
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // SIBLINGS
  // ─────────────────────────────────────────────────────────
  static Future<void> saveSiblings(List<dynamic> siblings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySiblings, json.encode(siblings));
    print('✅ Siblings saved (${siblings.length})');
  }

  static Future<List<dynamic>> getSiblings() async {
    final prefs        = await SharedPreferences.getInstance();
    final siblingsJson = prefs.getString(_keySiblings);
    if (siblingsJson == null) return [];
    try {
      return json.decode(siblingsJson) as List<dynamic>;
    } catch (e) {
      print('❌ Error parsing siblings: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────
  // QUICK GETTERS
  // ─────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<int?> getStudentId() async {
    final prefs     = await SharedPreferences.getInstance();
    final studentId = prefs.getInt(_keyStudentId);
    return studentId == -1 ? null : studentId;
  }

  static Future<int?> getClassId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyClassId);
  }

  // ─────────────────────────────────────────────────────────
  // FCM TOKEN
  // ─────────────────────────────────────────────────────────
  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFcmToken, token);
    print('🔑 FCM token saved');
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken);
  }

  // ─────────────────────────────────────────────────────────
  // DEBUG
  // ─────────────────────────────────────────────────────────
  static Future<void> debugPrintSession() async {
    final prefs    = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCurrentUser);

    print('══ SESSION DEBUG ══════════════════════');
    print('   Is Logged In   : ${prefs.getBool(_keyIsLoggedIn)}');
    print('   User ID        : ${prefs.getInt(_keyUserId)}');
    print('   Username       : ${prefs.getString(_keyUsername)}');
    print('   Student ID     : ${prefs.getInt(_keyStudentId)}');
    print('   Session Version: ${prefs.getInt(_keySessionVersion)}');
    print('   Install ID     : ${prefs.getString(_keyAppInstallId)}');
    print('   Has FCM Token  : ${prefs.getString(_keyFcmToken) != null}');

    if (userJson != null) {
      try {
        final user = User.fromJson(json.decode(userJson));
        print('   Full Name      : ${user.firstName} ${user.lastName}');
        print('   Class          : ${user.className}');
        print('   Section        : ${user.sectionName}');
      } catch (e) {
        print('   ❌ Error parsing user JSON: $e');
      }
    }
    print('═══════════════════════════════════════');
  }
}