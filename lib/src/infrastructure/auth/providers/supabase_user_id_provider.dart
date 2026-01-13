import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_user_id_provider.g.dart';

/// Стрим текущего `user_id` из Supabase auth.
///
/// Значения:
/// - `null` если нет авторизации
/// - `String` если user залогинен
///
/// Используется для триггера initial sync при переходе из неавторизованного состояния в авторизованное.
@riverpod
Stream<String?> supabaseUserId(Ref ref) {
  final controller = StreamController<String?>();

  // Первое значение — текущее состояние.
  controller.add(Supabase.instance.client.auth.currentUser?.id);

  final subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
    event,
  ) {
    controller.add(event.session?.user.id);
  }, onError: controller.addError);

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
}
