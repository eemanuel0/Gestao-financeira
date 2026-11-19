import 'package:flutter/material.dart';

import '../core/app_settings.dart';

class PreferencesScreen extends StatelessWidget {
  final AppSettingsController settings;
  const PreferencesScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final choices = <(ThemeMode, String, String, IconData)>[
        (
          ThemeMode.light,
          'Claro',
          'Tons suaves de verde e fundos claros.',
          Icons.light_mode_outlined,
        ),
        (
          ThemeMode.dark,
          'Escuro',
          'Fundo escuro e detalhes verdes.',
          Icons.dark_mode_outlined,
        ),
        (
          ThemeMode.system,
          'Usar tema do dispositivo',
          'Acompanha a configuração do sistema.',
          Icons.settings_brightness,
        ),
      ];
      return Scaffold(
        appBar: AppBar(title: const Text('Preferências')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Aparência',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua escolha vale para todo o aplicativo e fica salva neste dispositivo.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  for (final choice in choices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        selected: settings.mode == choice.$1,
                        child: Card.outlined(
                          color: colors.surface,
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: ValueKey('theme-${choice.$1.name}'),
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(choice.$4, color: colors.primary),
                            title: Text(choice.$2),
                            subtitle: Text(choice.$3),
                            trailing: Icon(
                              settings.mode == choice.$1
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: colors.primary,
                            ),
                            enabled: !settings.saving,
                            onTap: () async {
                              try {
                                await settings.setMode(choice.$1);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Não foi possível salvar a preferência. Tente novamente.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
