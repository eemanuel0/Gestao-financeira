import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/core/app_settings.dart';
import 'package:gestao_financeira/core/app_theme.dart';
import 'package:gestao_financeira/models/services/password_service.dart';
import 'package:gestao_financeira/screens/forgot_password_screen.dart';
import 'package:gestao_financeira/screens/password_screen.dart';
import 'package:gestao_financeira/screens/preferences_screen.dart';

void main() {
  test('paletas mantêm contraste de texto >=4.5 e bordas de campos >=3', () {
    for (final brightness in Brightness.values) {
      final theme = createAppTheme(brightness);
      final c = theme.colorScheme;
      for (final pair in [
        (c.onSurface, c.surface),
        (c.onSurfaceVariant, c.surface),
        (c.primary, c.surface),
        (c.onPrimary, c.primary),
        (c.error, c.surface),
      ]) {
        expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(
        _contrast(c.outline, c.surfaceContainerLow),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(c.outline, theme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(3),
      );
    }
  });
  test(
    'preferência só confirma após gravar e preserva modo anterior na falha',
    () async {
      final gate = Completer<void>();
      String? written;
      final settings = AppSettingsController(
        persist: (value) {
          written = value;
          return gate.future;
        },
      );
      final pending = settings.setMode(ThemeMode.light);
      expect(settings.saving, true);
      expect(settings.mode, ThemeMode.dark);
      expect(written, 'light');
      gate.complete();
      await pending;
      expect(settings.mode, ThemeMode.light);
      expect(settings.saving, false);
      final broken = AppSettingsController(
        persist: (_) async => throw StateError('quota'),
      );
      await expectLater(broken.setMode(ThemeMode.light), throwsStateError);
      expect(broken.mode, ThemeMode.dark);
      expect(broken.saving, false);
      settings.dispose();
      broken.dispose();
    },
  );
  testWidgets('preferências mudam tema e preservam navegação', (tester) async {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          theme: createAppTheme(Brightness.light),
          darkTheme: createAppTheme(Brightness.dark),
          themeMode: settings.mode,
          home: PreferencesScreen(settings: settings),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(settings.mode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(PreferencesScreen))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(settings.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
  testWidgets('alteração exige confirmação e impede envio duplicado', (
    tester,
  ) async {
    final service = _Passwords();
    await _mount(tester, PasswordScreen(passwordService: service));
    await _enter(tester, 'current-password-input', ' atual 123 ');
    await _enter(tester, 'new-password-input', ' nova 123 ');
    await _enter(tester, 'confirm-password-input', 'diferente');
    await _tap(tester, 'change-password-submit');
    expect(service.changes, 0);
    await _enter(tester, 'confirm-password-input', ' nova 123 ');
    service.gate = Completer<void>();
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();
    expect(service.changes, 1);
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();
    expect(service.changes, 1);
    expect(service.current, ' atual 123 ');
    expect(service.password, ' nova 123 ');
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PasswordScreen), findsNothing);
    expect(find.text('Senha alterada com sucesso.'), findsOneWidget);
  });
  testWidgets(
    'recuperação valida email/código e permite reenviar sem enumerar contas',
    (tester) async {
      final service = _Passwords();
      await _mount(tester, ForgotPasswordScreen(passwordService: service));
      await _enter(tester, 'recovery-email-input', 'BIA@Example.com');
      await _tap(tester, 'send-recovery-code');
      expect(service.email, 'BIA@Example.com');
      await _tap(tester, 'resend-recovery-code');
      expect(service.sends, 2);
      await _enter(tester, 'recovery-code-input', '123456789');
      final code = tester.widget<TextFormField>(
        find.byKey(const ValueKey('recovery-code-input')),
      );
      expect(code.controller!.text, '12345678');
      await _enter(tester, 'recovery-new-password-input', ' senha nova ');
      await _enter(tester, 'recovery-confirm-password-input', ' senha nova ');
      await _tap(tester, 'reset-password-submit');
      expect(service.code, '12345678');
      expect(service.password, ' senha nova ');
      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(
        find.text('Senha redefinida. Entre com a nova senha.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
}

Future<void> _mount(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: createAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester t, String key, String value) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.enterText(f, value);
  await t.pump();
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

class _Passwords extends PasswordService {
  int changes = 0, sends = 0;
  String? email, current, password, code;
  Completer<void>? gate;
  @override
  bool get recoveryInProgress => false;
  @override
  Future<void> sendRecoveryCode(String value) async {
    email = value;
    sends++;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    this.email = email;
    this.code = code;
    password = newPassword;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changes++;
    current = currentPassword;
    password = newPassword;
    await gate?.future;
  }
}
