import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

  Future<bool> signInAnonymously() async {
    state = state.copyWith(isLoading: true);
    try {
      // Use a hardcoded API key or get it from the other provider
      const apiKey = 'AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws';
      final url = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        body: json.encode({'returnSecureToken': true}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        state = state.copyWith(idToken: data['idToken'], isLoading: false);
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

final authRestServiceProvider = NotifierProvider<AuthRestNotifier, AuthState>(AuthRestNotifier.new);
