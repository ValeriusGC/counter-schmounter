import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';

part 'ulsync_client_provider.g.dart';

/// Клиент ulsync для текущего пользователя Supabase.
///
/// `null`, если пользователь не вошёл — локальная работа без сети.
/// [keepAlive] обязателен: контроллеры sync читают клиента через `ref.read`,
/// без keepAlive autoDispose закроет клиент после первого кадра.
@Riverpod(keepAlive: true)
Future<UlsyncClient?> ulsyncClient(Ref ref) async {
  final userId = ref.watch(supabaseUserIdProvider).asData?.value;
  if (userId == null) {
    return null;
  }

  final clientId = ref.watch(clientIdentityServiceProvider).clientId;
  final localOpLog = ref.watch(localOpLogRepositoryProvider);

  final client = await UlsyncClientFactory.open(
    userScope: userId,
    sourceId: clientId,
    localOpLog: localOpLog,
    tokenProvider: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );

  ref.onDispose(() {
    unawaited(client.close());
  });

  return client;
}
