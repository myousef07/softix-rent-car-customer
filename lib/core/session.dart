import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'config.dart';

/// Result of checking an SMS code: either signed in, or a new number that must register.
class VerifyResult {
  VerifyResult.signedIn() : registrationToken = null;
  VerifyResult.mustRegister(this.registrationToken);

  final String? registrationToken;

  bool get isNew => registrationToken != null;
}

/// The signed-in renter. The token lives in the platform keystore, never in plain preferences.
class Session extends ChangeNotifier {
  Session(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'customer_token';

  final ApiClient api;
  final FlutterSecureStorage _storage;

  Profile? profile;
  bool restoring = true;

  bool get isSignedIn => profile != null;

  String get _device => 'SOftiX (${defaultTargetPlatform.name})';

  Future<void> restore() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        api.token = token;
        await reloadProfile();
      }
    } catch (_) {
      await _clear();
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    profile = Profile.fromJson(Map<String, dynamic>.from((await api.get('/me'))['data']));
    notifyListeners();
  }

  Future<void> requestCode(String mobile) =>
      api.post('/auth/otp', data: {'company_id': AppConfig.companyId, 'mobile': mobile.trim()});

  Future<VerifyResult> verify(String mobile, String code) async {
    final response = await api.post('/auth/verify', data: {
      'company_id': AppConfig.companyId,
      'mobile': mobile.trim(),
      'code': code.trim(),
      'device_name': _device,
    });

    if (response['is_new'] == true) return VerifyResult.mustRegister(response['registration_token'] as String);

    await _signedIn(response);
    return VerifyResult.signedIn();
  }

  Future<void> register(String registrationToken, Map<String, dynamic> profile) async {
    final response = await api.post('/auth/register', data: {...profile, 'registration_token': registrationToken, 'device_name': _device});
    await _signedIn(response);
  }

  Future<void> signOut() async {
    try {
      if (api.hasToken) await api.post('/auth/logout');
    } catch (_) {
      // The token is dropped locally either way.
    }
    await _clear();
    notifyListeners();
  }

  /// Called when the server no longer accepts the token.
  void expire() {
    if (profile == null) return;
    _clear();
    notifyListeners();
  }

  Future<void> _signedIn(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    api.token = token;
    profile = Profile.fromJson(Map<String, dynamic>.from(response['customer']));
    notifyListeners();
  }

  Future<void> _clear() async {
    profile = null;
    api.token = null;
    await _storage.delete(key: _tokenKey);
  }
}
