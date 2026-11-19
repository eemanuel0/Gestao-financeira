# Arquivos da troca de perfil

O instalador cria e substitui os arquivos automaticamente. Os caminhos abaixo
servem para localizar o código no explorador do Codespace.

## Novos arquivos do aplicativo

| Pasta | Novo arquivo | Função |
| --- | --- | --- |
| `lib/models/` | `financial_profile.dart` | Representa o perfil financeiro e a seleção da conta. |
| `lib/models/services/` | `financial_profile_repository.dart` | Define o carregamento, a seleção e a edição do nome empresarial. |
| `lib/models/services/` | `supabase_financial_profile_repository.dart` | Salva os perfis e a seleção no Supabase. |
| `lib/screens/` | `financial_workspace.dart` | Mantém os serviços de cada perfil separados e restaura a seleção salva. |
| `lib/widgets/` | `edit_business_name_sheet.dart` | Editor do nome da empresa com confirmação de gravação. |
| `supabase/migrations/` | `003_financial_profiles.sql` | Cria os perfis e separa os registros existentes sem alterar seus valores. |

## Arquivos existentes atualizados

| Pasta | Arquivo existente | Alteração |
| --- | --- | --- |
| `lib/` | `main.dart` | Inicializa os serviços de perfis e os repositórios de cada espaço financeiro. |
| `lib/` | `app.dart` | Mostra o espaço financeiro da conta autenticada. |
| `lib/models/` | `finance_transaction.dart` | Identifica o perfil a que pertence cada lançamento. |
| `lib/models/` | `monthly_limit.dart` | Identifica o perfil a que pertence cada limite mensal. |
| `lib/models/` | `finance_summary.dart` | Filtra os relatórios por usuário, perfil e mês. |
| `lib/models/services/` | `supabase_finance_repository.dart` | Consulta e grava lançamentos somente no perfil escolhido. |
| `lib/models/services/` | `supabase_monthly_limit_repository.dart` | Consulta e grava um limite por conta, perfil e mês. |
| `lib/screens/` | `home_screen.dart` | Integra a troca em todas as abas e a edição do nome empresarial. |
| `lib/screens/` | `reports_screen.dart` | Consulta o limite e soma os gastos do perfil ativo. |
| `lib/widgets/` | `app_header.dart` | Exibe os segmentos Pessoal e Empresa, com troca em um toque. |

## Testes e documentação

**Pasta dos testes:** `test/`. O manifesto do pacote relaciona os testes novos
e atualizados entregues nesta versão.

**Pasta da documentação:** raiz do projeto. Novos arquivos:

- `PERFIS.md`: instalação, migração SQL e uso.
- `ARQUIVOS_PERFIS.md`: este mapa de arquivos e pastas.
- `VALIDACAO_PERFIS.md`: verificações realizadas e conferência no seu aplicativo.
