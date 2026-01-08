import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_in_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_up_use_case.dart';
import 'package:counter_schmounter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';

/// Mock for SupabaseClient
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock for GoTrueClient (auth client)
class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Mock for AuthRepository
class MockAuthRepository extends Mock implements AuthRepository {}

/// Mock for SignInUseCase
class MockSignInUseCase extends Mock implements SignInUseCase {}

/// Mock for SignUpUseCase
class MockSignUpUseCase extends Mock implements SignUpUseCase {}

/// Mock for SignOutUseCase
class MockSignOutUseCase extends Mock implements SignOutUseCase {}

/// Mock for User
class MockUser extends Mock implements User {}

/// Mock for ClientIdentityService
class MockClientIdentityService extends Mock implements ClientIdentityService {}

/// Mock for IncrementCounterUseCase
class MockIncrementCounterUseCase extends Mock implements IncrementCounterUseCase {}

/// Mock for LocalOpLogRepository
class MockLocalOpLogRepository extends Mock implements LocalOpLogRepository {}

/// Helper to register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(Uri());
  // AuthResponse doesn't have a const constructor, so we register a mock
  registerFallbackValue(AuthResponse(user: null, session: null));
  // CounterOperation fallback for mocktail
  registerFallbackValue(
    IncrementOperation(
      opId: const Uuid().v4(),
      clientId: 'fallback-client-id',
      createdAt: DateTime.now(),
    ),
  );
}

