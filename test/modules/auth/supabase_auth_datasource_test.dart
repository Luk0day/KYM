import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/password_recovery_event.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/external/datasources/supabase_auth_datasource.dart';
import 'package:kym/modules/auth/infra/datasources/google_id_token_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockGoogleIdTokenProvider extends Mock
    implements GoogleIdTokenProvider {}

Matcher _failsWith(AuthFailureType type) =>
    throwsA(isA<AuthFailure>().having((f) => f.type, 'type', type));

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late SupabaseAuthDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OAuthProvider.google);
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    dataSource = SupabaseAuthDataSource(
      client,
      passwordResetRedirectUrl: 'br.edu.ifpe.mobile.kym://reset-password',
    );
  });

  group('sendPasswordResetEmail', () {
    void resetThrows(Object error) {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenThrow(error);
    }

    test('envia o deep link como redirectTo', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});

      await dataSource.sendPasswordResetEmail(email: ' tecnico@kym.test ');

      verify(
        () => auth.resetPasswordForEmail(
          'tecnico@kym.test',
          redirectTo: 'br.edu.ifpe.mobile.kym://reset-password',
        ),
      ).called(1);
    });

    test('status 429 vira rateLimited', () {
      resetThrows(AuthException('Too many requests', statusCode: '429'));

      expect(
        () => dataSource.sendPasswordResetEmail(email: 'tecnico@kym.test'),
        _failsWith(AuthFailureType.rateLimited),
      );
    });

    test('código over_email_send_rate_limit vira rateLimited', () {
      resetThrows(AuthException('limit', code: 'over_email_send_rate_limit'));

      expect(
        () => dataSource.sendPasswordResetEmail(email: 'tecnico@kym.test'),
        _failsWith(AuthFailureType.rateLimited),
      );
    });

    test('falha de rede vira network', () {
      resetThrows(AuthRetryableFetchException());

      expect(
        () => dataSource.sendPasswordResetEmail(email: 'tecnico@kym.test'),
        _failsWith(AuthFailureType.network),
      );
    });
  });

  group('updatePassword', () {
    void updateThrows(Object error) {
      when(() => auth.updateUser(any())).thenThrow(error);
    }

    test('chama updateUser com a nova senha', () async {
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({}));

      await dataSource.updatePassword(password: 'novaSenha1');

      final captured =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(captured.password, 'novaSenha1');
    });

    final cases = <String, (Object, AuthFailureType)>{
      'weak_password': (
        AuthException('weak', code: 'weak_password', statusCode: '422'),
        AuthFailureType.weakPassword,
      ),
      'AuthWeakPasswordException': (
        AuthWeakPasswordException(
          message: 'weak',
          statusCode: '422',
          reasons: const ['length'],
        ),
        AuthFailureType.weakPassword,
      ),
      'same_password': (
        AuthException('same', code: 'same_password', statusCode: '422'),
        AuthFailureType.samePassword,
      ),
      'sessão ausente': (
        AuthSessionMissingException(),
        AuthFailureType.recoveryLinkInvalid,
      ),
      'otp_expired': (
        AuthException('expired', code: 'otp_expired', statusCode: '403'),
        AuthFailureType.recoveryLinkInvalid,
      ),
      'session_not_found': (
        AuthException('gone', code: 'session_not_found', statusCode: '403'),
        AuthFailureType.recoveryLinkInvalid,
      ),
      '429': (
        AuthException('limit', statusCode: '429'),
        AuthFailureType.rateLimited,
      ),
      'erro desconhecido do servidor': (
        AuthException('boom', code: 'unexpected_failure', statusCode: '500'),
        AuthFailureType.unexpected,
      ),
      'sem internet': (AuthRetryableFetchException(), AuthFailureType.network),
    };

    for (final entry in cases.entries) {
      test('${entry.key} vira ${entry.value.$2.name}', () {
        updateThrows(entry.value.$1);

        expect(
          () => dataSource.updatePassword(password: 'novaSenha1'),
          _failsWith(entry.value.$2),
        );
      });
    }
  });

  group('signInWithEmail', () {
    void signInReturns(Future<AuthResponse> Function() answer) {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('credenciais inválidas viram invalidCredentials', () {
      signInReturns(
        () => throw AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );

      expect(
        () => dataSource.signInWithEmail(
          email: 'tecnico@kym.test',
          password: 'errada',
        ),
        _failsWith(AuthFailureType.invalidCredentials),
      );
    });

    test('resposta sem usuário vira unexpected', () {
      signInReturns(() async => AuthResponse());

      expect(
        () => dataSource.signInWithEmail(
          email: 'tecnico@kym.test',
          password: 'kym12345',
        ),
        _failsWith(AuthFailureType.unexpected),
      );
    });
  });

  group('signInWithGoogle', () {
    test('sem provedor configurado vira unexpected', () {
      expect(
        () => dataSource.signInWithGoogle(),
        _failsWith(AuthFailureType.unexpected),
      );
    });

    test('desistência na escolha da conta vira cancelled', () {
      final provider = _MockGoogleIdTokenProvider();
      when(provider.fetchIdToken)
          .thenThrow(const AuthFailure(AuthFailureType.cancelled));

      expect(
        () => SupabaseAuthDataSource(
          client,
          googleProvider: provider,
        ).signInWithGoogle(),
        _failsWith(AuthFailureType.cancelled),
      );
    });

    test('resposta sem usuário vira unexpected', () {
      final provider = _MockGoogleIdTokenProvider();
      when(provider.fetchIdToken).thenAnswer((_) async => 'id-token');
      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      expect(
        () => SupabaseAuthDataSource(
          client,
          googleProvider: provider,
        ).signInWithGoogle(),
        _failsWith(AuthFailureType.unexpected),
      );
    });
  });

  group('getCurrentUser e signOut', () {
    test('sem sessão devolve null', () async {
      when(() => auth.getSession()).thenAnswer((_) async => null);

      expect(await dataSource.getCurrentUser(), isNull);
    });

    test('sem internet vira network', () {
      when(() => auth.getSession()).thenThrow(const SocketException('offline'));

      expect(
        () => dataSource.getCurrentUser(),
        _failsWith(AuthFailureType.network),
      );
    });

    test('tempo esgotado vira network', () {
      when(() => auth.getSession()).thenThrow(TimeoutException('lento'));

      expect(
        () => dataSource.getCurrentUser(),
        _failsWith(AuthFailureType.network),
      );
    });

    test('erro desconhecido vira unexpected', () {
      when(() => auth.getSession()).thenThrow(StateError('boom'));

      expect(
        () => dataSource.getCurrentUser(),
        _failsWith(AuthFailureType.unexpected),
      );
    });

    test('sair encerra o Supabase e a conta Google', () async {
      final provider = _MockGoogleIdTokenProvider();
      when(provider.signOut).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      await SupabaseAuthDataSource(client, googleProvider: provider).signOut();

      verify(() => auth.signOut()).called(1);
      verify(provider.signOut).called(1);
    });
  });

  group('passwordRecoveryEvents', () {
    late StreamController<AuthState> authStates;

    setUp(() {
      authStates = StreamController<AuthState>.broadcast();
      when(() => auth.onAuthStateChange).thenAnswer((_) => authStates.stream);
    });

    tearDown(() => authStates.close());

    test('passwordRecovery vira started e ignora os outros eventos', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = dataSource.passwordRecoveryEvents.listen(events.add);

      authStates
        ..add(const AuthState(AuthChangeEvent.signedIn, null))
        ..add(const AuthState(AuthChangeEvent.passwordRecovery, null));
      await Future<void>.delayed(Duration.zero);

      expect(events, [PasswordRecoveryEvent.started]);
      await subscription.cancel();
    });

    test('erro do link expirado vira linkInvalid', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = dataSource.passwordRecoveryEvents.listen(events.add);

      authStates.addError(
        AuthException(
          'Email link is invalid or has expired',
          statusCode: 'otp_expired',
          code: 'access_denied',
        ),
      );
      authStates.addError(StateError('outro erro'));
      await Future<void>.delayed(Duration.zero);

      expect(events, [PasswordRecoveryEvent.linkInvalid]);
      await subscription.cancel();
    });

    test('link aberto em outro aparelho também vira linkInvalid', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = dataSource.passwordRecoveryEvents.listen(events.add);

      authStates
        ..addError(
          AuthException('invalid flow state', code: 'flow_state_not_found'),
        )
        ..addError(
          const AuthPKCEGrantCodeExchangeError(
            'Code verifier could not be found in local storage.',
          ),
        );
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        PasswordRecoveryEvent.linkInvalid,
        PasswordRecoveryEvent.linkInvalid,
      ]);
      await subscription.cancel();
    });

    test('renovação do token sem internet não vira linkInvalid', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = dataSource.passwordRecoveryEvents.listen(events.add);

      authStates
        ..addError(AuthRetryableFetchException(message: 'SocketException'))
        ..addError(
          AuthRetryableFetchException(message: 'gateway', statusCode: '503'),
        );
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await subscription.cancel();
    });

    test('sessão vencida ao restaurar não vira linkInvalid', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = dataSource.passwordRecoveryEvents.listen(events.add);

      authStates
        ..addError(AuthException('Session expired.', code: 'session_expired'))
        ..addError(
          AuthException(
            'Initial session is missing data.',
            code: 'session_not_found',
          ),
        )
        ..addError(AuthException('Invalid Refresh Token', statusCode: '400'));
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await subscription.cancel();
    });
  });
}
