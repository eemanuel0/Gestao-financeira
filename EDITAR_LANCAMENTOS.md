# Editar descrições de lançamentos

Na tela **Lançamentos**, toque no lápis ao lado de uma receita ou despesa.
Corrija o campo **Descrição** e toque em **Salvar alteração**.
O aplicativo fecha o editor depois da confirmação do Supabase.
Em caso de erro, o texto digitado permanece disponível para tentar novamente.

O aplicativo atualiza somente a descrição. Valor, tipo, categoria e data
permanecem nos dados do lançamento. O registro é localizado pelo ID e pelo
usuário autenticado; as políticas do banco também protegem cada conta.
O nome corrigido fica salvo para os outros dispositivos, que o recebem na
próxima atualização dos dados (consulta automática a cada 30 segundos).

## Instalação pelo terminal do Codespace

Envie `financas_editar_lancamentos.zip` para a raiz do projeto, na mesma pasta
de `pubspec.yaml`. Execute nessa raiz:

```bash
python3 -m zipfile -e financas_editar_lancamentos.zip .
bash financas_atualizado/instalar.sh
dart format lib test
flutter analyze
flutter test
```

O instalador cria um backup dos arquivos substituídos em `backups_financas/`.
A configuração `config/supabase.json` e o formulário de adicionar lançamentos
não fazem parte dos arquivos substituídos nesta atualização.
Nenhum pacote novo é necessário.

Pare a execução anterior com `q` no terminal do Flutter e inicie novamente:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta 8080 pela aba **Portas** do Codespace e atualize a página.

## Corrigir “Limite indisponível”

O erro `PGRST205` indica que a API não encontra `public.monthly_limits`.
Essa tabela guarda o limite que cada usuário define para cada mês.
A instalação de arquivos no Codespace não cria tabelas no Supabase.

1. No terminal do Codespace, execute:

   ```bash
   cat supabase/migrations/002_monthly_limits.sql
   ```

2. Abra o projeto correto no painel do Supabase, entre em **SQL Editor**
   e clique em **New query**.
3. Copie o conteúdo completo do arquivo, desde o comentário inicial até
   `notify pgrst, 'reload schema';`, cole no editor e clique em **Run**.
4. Depois da execução sem erros, volte ao aplicativo e clique em
   **Tentar novamente**. Se necessário, recarregue a página.
5. Clique em **Definir limite**, informe o valor que você deseja e salve.

O SQL cria a tabela com proteção por conta e atualiza o cache da API.
Não cria limites nem lançamentos de exemplo. A edição das descrições usa a
tabela `transactions` já existente e suas políticas da migração 001.

## Arquivos e pastas

### Novo arquivo de código

**Pasta:** `lib/widgets/`  
**Novo arquivo:** `edit_transaction_description_sheet.dart`  
**Caminho completo:** `lib/widgets/edit_transaction_description_sheet.dart`

É o editor da descrição, com validação, cancelamento e salvamento no banco.

### Arquivos de código existentes atualizados

| Pasta | Arquivo existente | Alteração |
| --- | --- | --- |
| `lib/screens/` | `home_screen.dart` | Lápis nos lançamentos e atualização da lista com a resposta do banco. |
| `lib/models/services/` | `finance_repository.dart` | Define a operação de editar a descrição. |
| `lib/models/services/` | `supabase_finance_repository.dart` | Salva somente a descrição do lançamento da conta autenticada. |
| `supabase/migrations/` | `002_monthly_limits.sql` | Inclui a atualização do cache da API após a criação da tabela de limites. |

### Testes

**Pasta:** `test/`

- Novos arquivos: `edit_transaction_description_sheet_test.dart` e
  `transaction_description_flow_test.dart`.
- Arquivos existentes atualizados: `account_flow_test.dart`,
  `real_financial_flow_test.dart` e `supabase_services_test.dart`.

Os testes verificam salvamento, erros, validação, troca de conta e manutenção
dos valores financeiros. As chamadas do SDK usam um servidor HTTP local para
validar os filtros e o conteúdo enviado sem modificar dados reais.

## Conferência no seu aplicativo

1. Entre na sua conta e abra **Lançamentos**.
2. Edite a descrição de um registro. O novo nome deve aparecer após salvar.
3. Atualize a página e confirme que o nome corrigido permanece.
4. Confira que o valor do lançamento e os totais em Início e Relatórios continuam iguais.
5. Entre com outra conta e confirme que ela vê apenas os próprios registros.

Esta atualização foi verificada localmente; a aplicação do SQL e a conferência
com suas contas reais são feitas no seu Supabase e no seu Codespace.
