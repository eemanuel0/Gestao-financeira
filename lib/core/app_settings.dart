import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/services/password_service.dart';

class AppSettingsController extends ChangeNotifier {
  ThemeMode _mode;
  final Future<void> Function(String)? persist;
  bool _saving = false;
  ThemeMode get mode => _mode;
  bool get saving => _saving;

  AppSettingsController({ThemeMode initialMode = ThemeMode.dark, this.persist})
    : _mode = initialMode;

  static Future<AppSettingsController> load() async {
    final preferences = SharedPreferencesAsync();
    String? value;
    try {
      value = await preferences.getString('financas.theme');
    } catch (_) {
      // Uma preferência indisponível não impede o usuário de abrir o app.
    }
    return AppSettingsController(
      initialMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.dark,
      ),
      persist: (value) => preferences.setString('financas.theme', value),
    );
  }

  Future<void> setMode(ThemeMode value) async {
    if (_saving || value == _mode) return;
    _saving = true;
    notifyListeners();
    try {
      // Só confirma a seleção após salvar; a tela trata falhas de armazenamento.
      await persist?.call(value.name);
      _mode = value;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}

// Disponível no navegador inteiro, inclusive Login e páginas abertas por push.
class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  final PasswordService? passwords;
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
    this.passwords,
  }) : super(notifier: controller);

  AppSettingsController get settings => notifier!;
  static AppSettingsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
}
