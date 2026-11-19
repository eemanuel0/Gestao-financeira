# Perfil mais simples e limites dos campos

Esta atualização modifica somente o aplicativo. **Não precisa executar SQL
nem instalar pacotes novos.**

## O que mudou

- Perfil com fundo escuro liso, cartões neutros e bordas discretas.
- Removidos os brilhos, as ondas, as bordas verdes e os textos repetidos.
- Foto menor, dados ao lado e ações compactas. O verde fica nas ações
  principais e nos elementos de navegação já existentes no aplicativo.
- Menus de configurações mais compactos. Conta, Ajuda, edição, fotos e saída
  continuam funcionando; Segurança e Preferências continuam como Em breve.
- CNPJ limitado a **14 posições úteis**, com máscara automática de até
  **18 caracteres visíveis**. Aceita CNPJ numérico e alfanumérico.
- Telefone limitado a **15 dígitos**, incluindo DDD/DDI, e até **32 caracteres
  visíveis** para conservar a formatação já salva.

Os limites são aplicados enquanto você digita e cola. A validação dos dados
continua ativa antes de salvar. Os dados, fotos e limites financeiros já
cadastrados são preservados.

## Instalar pelo terminal do Codespace

Pare o Flutter com `q` no terminal em que ele estiver executando.
Envie `financas_perfil_minimalista.zip` para a raiz do projeto, junto de
`pubspec.yaml`, e execute:

```bash
python3 -m zipfile -e financas_perfil_minimalista.zip .
bash financas_atualizado/instalar.sh
dart format lib test
flutter analyze
flutter test
```

Depois, inicie novamente:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta 8080 pela aba Portas e atualize a página. O instalador faz backup
dos arquivos substituídos em `backups_financas/` e preserva sua configuração.

## Arquivos e pastas

**Pasta:** `lib/utils/`  
**Novo arquivo:** `profile_input_formatters.dart`  
Controla o limite, a formatação e o cursor dos campos de CNPJ e telefone.

**Pasta:** `lib/screens/`  
**Arquivo existente atualizado:** `profile_screen.dart`  
Simplifica o visual do Perfil, preservando os recursos existentes.

**Pasta:** `lib/widgets/`  
**Arquivo existente atualizado:** `edit_profile_sheet.dart`  
Aplica os limites reais nos campos de CNPJ e telefone.

**Pasta:** `test/`  
**Novo arquivo:** `profile_input_limits_test.dart`  
Verifica digitação, colagem, edição e conservação de dados válidos.

**Pasta:** `test/`  
**Arquivo existente atualizado:** `real_financial_flow_test.dart`  
Espera o aviso temporário de limite desaparecer antes de testar a saída da conta.

**Pasta:** raiz do projeto.  
**Novo arquivo:** `AJUSTES_PERFIL.md`, com estas instruções.
