# Arquivos da tela de Perfil e das fotos

O instalador cria os arquivos novos e substitui os existentes automaticamente.

## Novos arquivos de código

| Pasta | Novo arquivo | Responsabilidade |
| --- | --- | --- |
| `lib/screens/` | `profile_screen.dart` | Tela de Perfil baseada na referência, com foto e menus. |
| `lib/widgets/` | `edit_profile_sheet.dart` | Formulários pessoais e empresariais. |
| `lib/models/` | `business_profile_data.dart` | Dados da empresa e validações. |
| `lib/models/` | `picked_profile_image.dart` | Imagem selecionada antes de salvar. |
| `lib/models/services/` | `profile_details_repository.dart` | Contrato para editar dados e fotos. |
| `lib/models/services/` | `supabase_profile_details_repository.dart` | Gravação dos dados e fotos privadas. |
| `lib/utils/` | `profile_image_picker.dart` | Seleção da foto com `image_picker`. |
| `lib/utils/` | `profile_validators.dart` | Normalização e validação do CNPJ. |
| `supabase/migrations/` | `004_profile_details_and_business.sql` | Campos empresariais, fotos e categorias no banco. |

## Arquivos existentes atualizados

| Pasta | Arquivo existente | Alteração |
| --- | --- | --- |
| raiz | `pubspec.yaml` e `pubspec.lock` | Adiciona `image_picker` e suas dependências. |
| `lib/` | `main.dart` e `app.dart` | Inicializa e fornece os serviços de perfil e foto. |
| `lib/screens/` | `financial_workspace.dart` | Atualiza os dados confirmados e protege a troca de conta/perfil. |
| `lib/screens/` | `home_screen.dart` | Integra a tela de Perfil e o Caixa empresarial. |
| `lib/screens/` | `add_transaction_screen.dart` | Categorias e rótulos de Pessoal ou Empresa. |
| `lib/models/` | `financial_profile.dart` | Dados empresariais e referência privada da foto. |
| `lib/models/` | `finance_transaction.dart` | Categorias empresariais sem reclassificar o histórico. |
| `lib/models/` | `finance_summary.dart` | Faturamento a partir de vendas e serviços. |
| `lib/models/services/` | `supabase_financial_profile_repository.dart` | Carrega os dados e URLs temporárias das fotos. |
| `lib/widgets/` | `balance_card.dart` | Permite o título Saldo em caixa para a empresa. |

## Testes

**Pasta:** `test/`

Novos arquivos nesta etapa:

- `add_transaction_business_test.dart`
- `business_financial_models_test.dart`
- `profile_details_models_test.dart`
- `profile_screen_flow_test.dart`
- `supabase_profile_details_repository_test.dart`

O arquivo existente `financial_profile_flow_test.dart` foi adaptado aos
novos controles de edição e aos rótulos Entrada/Saída da empresa, mantendo
as verificações de isolamento e preservação dos dados.

## Documentação

**Pasta:** raiz do projeto.

- `PERFIL_FOTOS.md`: instalação, SQL e uso.
- `ARQUIVOS_PERFIL_FOTOS.md`: nomes e pastas.
- `VALIDACAO_PERFIL_FOTOS.md`: verificações realizadas.

O pacote também inclui os demais arquivos atuais de código e testes para
manter as funções anteriores de login, lançamentos, relatórios e troca de perfil.
