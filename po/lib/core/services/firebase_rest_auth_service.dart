import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'firestore_rest_service.dart';

class AuthState {
  final String? idToken;
  final bool isLoading;

  AuthState({this.idToken, this.isLoading = false});

  AuthState copyWith({String? idToken, bool? isLoading}) {
    return AuthState(
      idToken: idToken ?? this.idToken,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthRestNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  String? _refreshToken;
  DateTime? _expiresAt;

  Future<bool> ensureSession() async {
    if (state.idToken != null && _expiresAt?.isAfter(DateTime.now()) == true)
      return true;
    return signInAnonymously();
  }

  Future<bool> signInAnonymously() async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);
    try {
      // Use a hardcoded API key or get it from the other provider
      const apiKey = 'AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws';
      final url = _refreshToken != null
          ? 'https://securetoken.googleapis.com/v1/token?key=$apiKey'
          : 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';

      final response = await http.post(
        Uri.parse(url),
        body: _refreshToken == null
            ? json.encode({'returnSecureToken': true})
            : {'grant_type': 'refresh_token', 'refresh_token': _refreshToken!},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _refreshToken = data['refreshToken'] ?? data['refresh_token'];
        _expiresAt = DateTime.now().add(
          Duration(
            seconds:
                (int.tryParse('${data['expiresIn'] ?? data['expires_in']}') ??
                    3600) -
                60,
          ),
        );
        state = state.copyWith(
          idToken: data['idToken'] ?? data['id_token'],
          isLoading: false,
        );
        debugPrint('REST AUTH: Signed in anonymously.');
        return true;
      } else {
        debugPrint('REST AUTH ERROR: ${response.statusCode}: ${response.body}');
        state = state.copyWith(isLoading: false);
        return false;
      }
    } catch (e) {
      debugPrint('REST AUTH ERROR: $e');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

final authRestServiceProvider = NotifierProvider<AuthRestNotifier, AuthState>(
  AuthRestNotifier.new,
);
