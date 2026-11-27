# Gestao-financeira

Aplicativo de gestão financeira em Flutter e Dart. Use **Pessoal** para as finanças
individuais, **Empresa** para o caixa do negócio e **Familiar** para compartilhar
receitas, despesas, saldo e limite mensal com um grupo. O Supabase Auth gerencia
as contas e o PostgreSQL do Supabase armazena os dados financeiros. Os perfis
Pessoal e Empresa são privados, e o acesso ao Familiar depende da participação
no grupo.

## Guia de reprodução e configuração

### 1. Prepare o ambiente

- Tenha acesso a este repositório no GitHub e a um projeto Supabase onde possa usar o **SQL Editor**.
- Instale Git, Python 3 e um navegador para o teste web.
- Instale o Flutter **3.47.9**, versão de referência deste guia. O SDK já inclui o Dart **3.13.7**, compatível com o [`pubspec.yaml`](pubspec.yaml). Adicione a pasta `bin` do Flutter ao `PATH`. [Instalação do Flutter](https://docs.flutter.dev/install/manual) · [Versões do SDK](https://docs.flutter.dev/install/archive)

No GitHub Codespaces, abra **Code → Codespaces → Create codespace on main**.
Se o Flutter ainda não estiver instalado no Codespace, rode o bloco abaixo no
terminal. Em uma nova sessão do terminal, execute o `export` novamente.

```bash
git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git "$HOME/flutter-3.47.9"
export PATH="$HOME/flutter-3.47.9/bin:$PATH"
```

Confira se o terminal encontra o SDK.

```bash
flutter --version
flutter doctor
```

### 2. Baixe o projeto e instale as dependências

No seu computador, clone o repositório. No Codespaces, o GitHub já disponibiliza
o código. Nesse caso, rode apenas `flutter pub get` na pasta que contém o
`pubspec.yaml`.

```bash
git clone https://github.com/eemanuel0/Gestao-financeira.git
cd Gestao-financeira
flutter pub get
```

### 3. Configure o banco e a autenticação

Crie um projeto de teste no Supabase ou abra o projeto que você já usa com o app.
No **SQL Editor**, cole o conteúdo completo de cada migração em uma consulta
separada e clique em **Run**. Em um banco novo, execute os cinco arquivos na ordem
abaixo. Em um banco existente, aplique somente as migrações pendentes, na mesma
ordem. [Painel do Supabase](https://supabase.com/dashboard)

1. [001_initial.sql](supabase/migrations/001_initial.sql) cria a tabela de lançamentos.
2. [002_monthly_limits.sql](supabase/migrations/002_monthly_limits.sql) cria os limites mensais.
3. [003_financial_profiles.sql](supabase/migrations/003_financial_profiles.sql) adiciona os perfis Pessoal e Empresa.
4. [004_profile_details_and_business.sql](supabase/migrations/004_profile_details_and_business.sql) adiciona os dados, as fotos de perfil e as categorias da empresa.
5. [005_family_group.sql](supabase/migrations/005_family_group.sql) adiciona os grupos familiares, os convites e as permissões de compartilhamento.

`Success. No rows returned` é o retorno esperado após executar a migração.

Em **Authentication → Sign In / Providers**, confira se o provedor **Email** está
habilitado. Em um projeto dedicado à demonstração, desative **Confirm email** se
quiser cadastrar contas de teste sem envio de e-mail. Para testar a confirmação por
e-mail, mantenha a opção ativa, configure o SMTP e coloque o endereço web do app
em **Authentication → URL Configuration → Site URL**. No Codespaces, use o
endereço HTTPS da porta encaminhada. [Autenticação por e-mail e senha](https://supabase.com/docs/guides/auth/passwords) · [Configuração de SMTP](https://supabase.com/docs/guides/auth/auth-smtp)

Para usar **Esqueci minha senha**, configure **Email OTP Length** como **8** no
provedor **Email** e use o [modelo de recuperação](supabase/templates/reset_password.html)
em **Authentication → Email Templates → Reset Password**. Esse modelo inclui o
código que a tela do app pede. [Modelos de e-mail do Supabase](https://supabase.com/docs/guides/auth/auth-email-templates)

### 4. Conecte o app ao Supabase

No painel do projeto Supabase, copie a **Project URL** e a chave pública
**Publishable key**. Se o projeto usa as chaves antigas, copie a chave pública
`anon`. Rode o configurador na pasta do projeto e cole os valores quando ele
pedir.

```bash
python3 scripts/configurar_supabase.py
```

No Windows, use `py -3 scripts/configurar_supabase.py` se o Python estiver
disponível como `py`. O script cria `config/supabase.json`, arquivo local ignorado
pelo Git. Consulte o [arquivo de exemplo](config/supabase.example.json) para ver
o formato.

### 5. Rode o app no navegador

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

No seu computador, abra `http://localhost:8080`. No Codespaces, abra a aba
**Portas** e clique em **Abrir no navegador** na linha da porta **8080**.
Depois de alterar `config/supabase.json`, encerre o Flutter com `Ctrl+C` e execute
o comando novamente.

### 6. Verifique a instalação

1. Crie uma conta e entre. Em **Pessoal**, registre uma receita com o botão **+** e confirme que o saldo foi atualizado.
2. Abra **Empresa** e confira que o lançamento pessoal fica em **Pessoal**.
3. Em **Familiar**, escolha **Criar grupo familiar** e registre uma despesa. Em **Relatórios**, defina o limite mensal do grupo.
4. Em **Grupo familiar**, toque em **Gerar convite**. Entre com uma segunda conta e cole o código em **Familiar → Entrar com convite**. Confira se ela vê a despesa e o limite do grupo.

O convite vale por sete dias e pode ser usado uma vez. Gerar outro código
invalida o anterior. O responsável pode remover membros, e cada convidado pode
sair do grupo. Os registros permanecem no grupo depois da saída de um membro.

Para verificar o código e rodar a suíte de testes, use os comandos abaixo.

```bash
flutter analyze
flutter test
```

## Gerar um APK Android

O workflow prepara o SDK Android e compila o app com a configuração do Supabase
informada no formulário. [Gerar APK Android no GitHub Actions](https://github.com/eemanuel0/Gestao-financeira/actions/workflows/android-apk.yml)

1. Clique em **Run workflow** e selecione a branch `main`.
2. Preencha `supabase_url` e `supabase_publishable_key` com a URL e a chave pública usadas em `config/supabase.json`. Clique em **Run workflow** para iniciar.
3. Na execução concluída, baixe **financas-apk** em **Artifacts**, extraia o ZIP e instale o arquivo `app-release.apk` no Android.
4. Entre com a mesma conta usada no navegador para conferir o grupo e os lançamentos no celular.

## Problemas comuns

- **Falha ao iniciar o aplicativo.** Confira se `config/supabase.json` existe e se o comando inclui `--dart-define-from-file=config/supabase.json`.
- **Não foi possível carregar seus perfis.** Verifique se a migração `005_family_group.sql` foi aplicada no mesmo projeto Supabase usado pelo app. Depois, clique em **Tentar novamente**.
- **E-mail ou senha incorretos.** Confira se a conta aparece em **Authentication → Users** no projeto da URL configurada. Se estiver confirmada, use **Esqueci minha senha** para redefinir a senha.
