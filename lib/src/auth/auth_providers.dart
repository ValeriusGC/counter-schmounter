import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Listenable, который дергает GoRouter refresh при изменениях auth.
///
/// Важно: Supabase Flutter хранит сессию локально автоматически,
/// поэтому при запуске приложение уже может иметь currentSession.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _subscription;

  Session? get currentSession => _client.auth.currentSession;

  bool get isAuthenticated => currentSession != null;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authStateListenableProvider = Provider<AuthStateListenable>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final listenable = AuthStateListenable(client);
  ref.onDispose(listenable.dispose);
  return listenable;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateListenableProvider);
  return auth.isAuthenticated;
});
