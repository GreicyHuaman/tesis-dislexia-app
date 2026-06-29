import 'package:hive_flutter/hive_flutter.dart';

import '../models/auth_user.dart';

class AuthSessionStorage {
  static const String _boxName = 'staff_auth_session';
  static const String _sessionKey = 'current_staff_session';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  static Future<void> saveSession({
    required AuthUser user,
    required int expiresInMinutes,
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(minutes: expiresInMinutes));

    await _box.put(_sessionKey, {
      'id': user.id,
      'nombres': user.nombres,
      'apellidos': user.apellidos,
      'email': user.email,
      'rol': user.rol,
      'grado_scope': user.gradoScope,
      'activo': user.activo,
      'access_token': user.accessToken,
      'saved_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    });
  }

  static AuthUser? getCurrentUserIfValid() {
    final raw = _box.get(_sessionKey);

    if (raw is! Map) {
      return null;
    }

    final data = raw.map(
      (key, dynamic value) => MapEntry(key.toString(), value),
    );

    final expiresAtRaw = data['expires_at']?.toString();
    final expiresAt = DateTime.tryParse(expiresAtRaw ?? '');

    if (expiresAt == null) {
      return null;
    }

    final now = DateTime.now().toUtc();

    if (!expiresAt.isAfter(now)) {
      clearSession();
      return null;
    }

    final token = data['access_token']?.toString();

    if (token == null || token.trim().isEmpty) {
      clearSession();
      return null;
    }

    return AuthUser.fromJson(data);
  }

  static String? getAccessTokenIfValid() {
    return getCurrentUserIfValid()?.accessToken;
  }

  static Future<void> clearSession() async {
    await _box.delete(_sessionKey);
  }

  static bool hasValidSession() {
    return getCurrentUserIfValid() != null;
  }
}
