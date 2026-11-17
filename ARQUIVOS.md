# Arquivos da atualização

As pastas são relativas à raiz do projeto. O instalador salva os arquivos anteriores no backup antes de substituir.

| Pasta | Nome do arquivo | Situação nesta entrega |
|---|---|---|
| `lib/` | `app.dart` | Novo |
| `lib/core/` | `app_colors.dart` | Mantido |
| `lib/core/` | `app_config.dart` | Novo |
| `lib/core/` | `app_database.dart` | Novo |
| `lib/` | `main.dart` | Atualizado |
| `lib/models/` | `app_user.dart` | Novo |
| `lib/models/` | `category_spending.dart` | Mantido |
| `lib/models/` | `finance_summary.dart` | Novo |
| `lib/models/` | `finance_transaction.dart` | Novo |
| `lib/models/services/` | `account_service.dart` | Novo |
| `lib/models/services/` | `finance_repository.dart` | Novo |
| `lib/models/services/` | `supabase_account_service.dart` | Novo |
| `lib/models/services/` | `supabase_finance_repository.dart` | Novo |
| `lib/screens/` | `add_transaction_screen.dart` | Novo |
| `lib/screens/` | `home_screen.dart` | Atualizado |
| `lib/screens/` | `login_screen.dart` | Atualizado |
| `lib/screens/` | `register_screen.dart` | Atualizado |
| `lib/screens/` | `welcome_screen.dart` | Atualizado |
| `lib/utils/` | `formatters.dart` | Atualizado |
| `lib/widgets/` | `app_bottom_nav.dart` | Atualizado |
| `lib/widgets/` | `balance_card.dart` | Atualizado |
| `lib/widgets/` | `category_item.dart` | Mantido |
| `lib/widgets/` | `glow_background.dart` | Mantido |
| `lib/widgets/` | `summary_card.dart` | Atualizado |
| `assets/fonts/` | `OFL.txt` | Novo |
| `assets/fonts/` | `Poppins-Bold.ttf` | Novo |
| `assets/fonts/` | `Poppins-Medium.ttf` | Novo |
| `assets/fonts/` | `Poppins-Regular.ttf` | Novo |
| `assets/fonts/` | `Poppins-SemiBold.ttf` | Novo |
| `config/` | `supabase.example.json` | Novo |
| `scripts/` | `configurar_supabase.py` | Novo |
| `supabase/migrations/` | `001_initial.sql` | Novo |
| `test/` | `account_flow_test.dart` | Novo |
| `test/` | `app_config_test.dart` | Novo |
| `test/` | `finance_models_test.dart` | Novo |
| `test/` | `formatters_test.dart` | Novo |
| `test/` | `supabase_services_test.dart` | Novo |
| `./` | `pubspec.yaml` | Atualizado |
| `./` | `pubspec.lock` | Atualizado |
| `./` | `analysis_options.yaml` | Novo |
| `./` | `LEIA_PRIMEIRO.md` | Novo |
| `./` | `ARQUIVOS.md` | Novo |
| `./` | `VALIDACAO.md` | Novo |

**Instalador:** `instalar.sh`, dentro da pasta extraída `financas_atualizado/`.
**Lista usada pelo instalador:** `MANIFESTO.json`, na mesma pasta.

Os arquivos `config/supabase.json`, `build/` e `.dart_tool/` não estão na entrega.
As pastas Android/iOS do projeto original são preservadas.
