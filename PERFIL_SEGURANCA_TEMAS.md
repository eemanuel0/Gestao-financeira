# Perfil, segurança e temas

Esta atualização já contém o formulário maior de Perfil, alteração de senha,
recuperação por código e temas claro, escuro e do dispositivo.

## Instalar no Codespace

1. Pare o Flutter com `q` no terminal onde ele está executando.
2. Envie `financas_perfil_seguranca_temas.zip` para a raiz do projeto,
   junto de `pubspec.yaml`.
3. Execute pela raiz do projeto:

```bash
python3 -m zipfile -e financas_perfil_seguranca_temas.zip .
bash financas_atualizado/instalar.sh
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Depois:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

O instalador faz backup dos arquivos substituídos em `backups_financas/`.
Sua configuração `config/supabase.json` é preservada. O pacote não contém
credenciais do seu projeto nem dados financeiros de exemplo.

## Supabase: e-mail de recuperação

**Esta etapa não precisa de SQL.**

No painel Supabase, abra **Authentication → Email Templates → Reset Password**
(em algumas versões, os templates ficam em **Authentication → Emails**).
Copie o conteúdo de `supabase/templates/reset_password.html` para o corpo
do e-mail de recuperação e salve. O template usa `{{ .Token }}`.

Este fluxo espera um OTP de **6 dígitos**. Mantenha esse tamanho nas
configurações de e-mail/OTP do projeto.

Para enviar a usuários fora da equipe do projeto, configure um provedor SMTP
no Supabase. O remetente padrão tem restrições de envio.

O teste local usa um servidor simulado: nenhum e-mail real foi enviado durante
a validação. Após configurar o template e o envio, teste com uma conta sua.

## O que mudou

- Perfil: avatar tocável, formulário visível e botão de salvar com altura de 52 dp.
- Nome e e-mail da conta pessoal; razão social, CNPJ e contatos no perfil Empresa.
- Segurança: confirmação da senha atual antes de alterar a senha da conta.
- Login: recuperação por código de e-mail, sem abrir uma sessão na Home.
- Preferências: claro, escuro e tema do sistema, salvos neste dispositivo.
- Temas aplicados também a Início, Relatórios, Lançamentos e formulários.

A senha pertence à conta de acesso e protege os perfis Pessoal e Empresa.
Os lançamentos, limites e fotos existentes continuam no Supabase.

## Onde alterar depois

- `lib/core/app_theme.dart`: cores, tamanhos e bordas dos temas.
- `lib/core/app_settings.dart`: armazenamento da preferência de aparência.
- `lib/screens/profile_screen.dart`: organização da página de Perfil.
- `lib/widgets/profile_data_form.dart`: campos e salvamento do perfil.
- `lib/screens/password_screen.dart`: troca de senha autenticada.
- `lib/screens/forgot_password_screen.dart`: recuperação por código.
- `lib/models/services/supabase_password_service.dart`: chamadas de autenticação.

O código contém comentários nos pontos de manutenção. Os testes de autenticação
usam HTTP simulado; os testes de interface verificam confirmação de senha,
bloqueio de envios duplicados, persistência e contraste da paleta.

## Conferência após instalar

1. Salve um nome no Perfil e confira o resultado em Início.
2. Abra Segurança e altere a senha informando a senha atual.
3. Escolha Claro em Preferências e navegue pelas telas financeiras.
4. Atualize a página para conferir a preferência salva.
5. Saia, abra Esqueci minha senha no login e use o código recebido por e-mail.
