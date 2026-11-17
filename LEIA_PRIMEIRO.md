# Finanças: contas individuais e lançamentos

Esta atualização mantém o visual do aplicativo e troca os dados fixos por autenticação e persistência no Supabase. Cada pessoa entra com e-mail e senha e acessa somente os próprios lançamentos. A conta começa sem lançamentos: saldo, receitas e despesas são calculados como zero.

## 1. Instalar a atualização no Codespace

Baixe `financas_atualizado.zip` e envie o ZIP para a raiz do seu projeto, onde está o `pubspec.yaml`. Execute nesse diretório:

```bash
python3 -m zipfile -e financas_atualizado.zip .
bash financas_atualizado/instalar.sh
flutter pub get
```

O instalador cria um backup dos arquivos que substituir e preserva os arquivos de Android/iOS e outros arquivos que não fazem parte da atualização. A cópia extraída fica em `financas_atualizado/`; ela será ignorada pelo analisador e pelo Git.

Se existir o teste de contador padrão do Flutter em `test/widget_test.dart`, o instalador o arquiva junto ao backup: esse teste descreve o aplicativo de contador, que já não corresponde ao seu projeto. Testes próprios são preservados.

## 2. Criar o projeto Supabase

1. Entre em <https://supabase.com/dashboard> e crie um projeto.
2. Escolha uma região adequada e guarde a senha do banco no seu gerenciador de senhas. Essa senha não entra no aplicativo.
3. Aguarde o projeto ficar disponível.
4. Abra o **SQL Editor**, crie uma consulta e execute o conteúdo completo do arquivo abaixo.

**Pasta:** `supabase/migrations/`  
**Novo arquivo fornecido:** `001_initial.sql`

Esse SQL cria `public.transactions`, os índices, as validações e as regras de acesso. Os usuários e as senhas ficam no serviço Supabase Auth. Não existe tabela de senha no aplicativo nem lançamento de exemplo.

As regras de acesso do banco vinculam `transactions.user_id` ao usuário autenticado. Um cliente não consegue ler, cadastrar, alterar ou apagar lançamentos de outro usuário, mesmo se tentar chamar a API diretamente.

## 3. Configurar URL e chave pública

Nas configurações de API/Connect do Supabase, copie a **Project URL** e a chave **Publishable key**. Projetos antigos podem chamar a chave pública de `anon`.

No terminal do Codespace:

```bash
python3 scripts/configurar_supabase.py
```

**Pasta:** `config/`  
**Novo arquivo local:** `supabase.json`

Use apenas a chave pública. As chaves `service_role`, `sb_secret_...` e a senha do banco pertencem ao servidor e não devem entrar nesse arquivo ou no Flutter. O aplicativo rejeita as chaves administrativas conhecidas. A proteção dos dados depende das regras do SQL, que precisam ser executadas antes do cadastro de lançamentos.

`config/supabase.json` fica no `.gitignore`. A chave pública será incluída no aplicativo compilado, como previsto pelo Supabase; ela não substitui as regras de acesso do servidor.

## 4. Configurar confirmação de e-mail

O aplicativo respeita a configuração de confirmação do Supabase:

- Com confirmação habilitada, o cadastro mostra a orientação para confirmar o e-mail; a pessoa entra depois de confirmar.
- Para confirmação e entrega de e-mails em uso real, configure um provedor SMTP no Supabase e coloque a URL pública do app em **Authentication > URL Configuration > Site URL**. No Codespace, use a URL HTTPS encaminhada da porta 8080. Confira também as URLs de redirecionamento permitidas.
- Para testar inicialmente sem configurar o envio de e-mails, é possível desabilitar **Confirm email** nas configurações do provedor Email. Nesse modo de teste, o cadastro autentica imediatamente. Habilite a confirmação e configure o envio antes de usar contas que dependam da verificação do e-mail.

O login nesta versão é por e-mail e senha. Login Google e recuperação de senha não fazem parte desta atualização; os controles que não executavam essas ações foram retirados das telas.

## 5. Rodar e testar

Na raiz do projeto:

```bash
dart format lib test
flutter analyze
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta **8080** pelo painel **PORTAS/PORTS** do Codespace. Após modificar a configuração, encerre e execute novamente o comando `flutter run`; hot reload não altera os valores de `--dart-define`.

O comando serve os recursos do renderizador pelo próprio aplicativo. As fontes Poppins também estão incluídas nos arquivos, reduzindo as dependências externas na abertura da página.

Para Android/iOS conectado, use o dispositivo disponível mantendo `--dart-define-from-file=config/supabase.json`. Para publicar uma build Android com acesso à internet, confira a permissão `android.permission.INTERNET` no manifesto principal do seu projeto Android; os arquivos de Android/iOS não estavam no ZIP enviado e foram preservados.

### Conferência manual com duas contas

1. Cadastre a conta A e entre. Confira saldo, receitas e despesas em zero e lista vazia.
2. Toque em **+**. Adicione uma receita de `100,50`, categoria Salário e uma descrição.
3. Adicione uma despesa de `25,10`, categoria Alimentação e uma descrição.
4. Confira receita `R$ 100,50`, despesa `R$ 25,10`, saldo `R$ 75,40` e Alimentação em 100% das despesas.
5. Em **Perfil**, toque em **Sair da conta**.
6. Cadastre ou entre na conta B. Confira que não aparecem os valores nem os lançamentos de A.
7. Entre novamente em A: os lançamentos devem continuar disponíveis.
8. Abra a mesma versão configurada do aplicativo em outro navegador ou dispositivo. Entre em A e confira os mesmos lançamentos.

Os valores acima são apenas entradas para seu teste; não são cadastrados automaticamente pelo SQL ou pelo aplicativo.

Os dados são buscados ao abrir a conta, ao voltar ao aplicativo, ao puxar para atualizar e a cada 30 segundos com a tela aberta. O mesmo projeto Supabase deve ser usado nas versões de todos os dispositivos. Esta versão precisa de internet para autenticar e salvar; ela não implementa uma fila de lançamentos offline.

## Inicialização solicitada

**Pasta:** `lib/core/`  
**Novo arquivo:** `app_database.dart`

`AppDatabase.instance.database` retorna um `SupabaseClient`. Não é um banco SQLite local. A classe foi criada porque não existia no ZIP recebido.

**Pasta:** `lib/`  
**Arquivo existente atualizado:** `main.dart`

O `main()` chama `WidgetsFlutterBinding.ensureInitialized()`, aguarda `AppDatabase.instance.database` e só então executa `runApp()`. Falhas de inicialização são registradas no terminal e exibem uma mensagem na tela, em vez de deixar a página branca.

Veja `ARQUIVOS.md` para a relação de arquivos, sempre com pasta e nome separados, e `VALIDACAO.md` para os testes realizados.
