# Pessoal e Empresa no mesmo login

O cabeçalho agora tem duas opções visíveis: **Pessoal | Empresa**. Toque na
opção desejada para mudar os dados de Início, Relatórios, Lançamentos e Perfil.
A aba que você estava usando permanece selecionada.

Cada perfil mantém seus próprios lançamentos e limites mensais. O nome de
usuário e o login continuam sendo os da mesma conta. O perfil Empresa
representa o negócio desta conta; esta versão não adiciona acesso para equipes.

A seleção fica salva no Supabase e é restaurada ao abrir o aplicativo de novo,
inclusive em outro dispositivo com o mesmo login. A consulta automática dos
lançamentos continua a cada 30 segundos para o perfil aberto. Para atualizar
os dados imediatamente, puxe a tela para baixo.

## Antes de começar

Esta atualização precisa da migração **003** no mesmo projeto Supabase das
migrações 001 e 002. A migração preserva todos os valores e datas existentes,
classificando os lançamentos e limites antigos como **Pessoal**. Cria os
espaços Pessoal e Empresa, mas não cria lançamentos nem limites de exemplo.

Se o Flutter estiver rodando, pressione `q` no terminal dele antes de instalar.

## 1. Instalar os arquivos pelo terminal

Envie `financas_perfis.zip` para a raiz do Codespace, junto de `pubspec.yaml`.
Execute a partir dessa raiz:

```bash
python3 -m zipfile -e financas_perfis.zip .
bash financas_atualizado/instalar.sh
```

O instalador cria um backup em `backups_financas/`. A configuração
`config/supabase.json`, os arquivos de fontes e o formulário de adicionar
lançamentos são preservados. Nenhuma dependência nova é necessária.

## 2. Executar a migração no Supabase

**Pasta:** `supabase/migrations/`  
**Novo arquivo:** `003_financial_profiles.sql`

Abra esse arquivo no explorador do Codespace, selecione todo o conteúdo e
copie. Você também pode exibi-lo pelo terminal:

```bash
cat supabase/migrations/003_financial_profiles.sql
```

Abra o SQL Editor do projeto correto:

https://supabase.com/dashboard/project/hoarqhhielhwxwoyatoy/sql/new

Cole o conteúdo completo do arquivo, desde os comentários iniciais até
`notify pgrst, 'reload schema';`, e clique em **Run**. O comando `cat` apenas
mostra o arquivo; a alteração do banco acontece quando você executa o SQL no
painel do Supabase. Não execute os comandos Dart ou Bash no SQL Editor.

Depois da execução sem erros, confira no mesmo SQL Editor:

```sql
select
  to_regclass('public.financial_profiles') as perfis,
  to_regclass('public.financial_profile_preferences') as preferencias;
```

Os dois campos devem mostrar os nomes das tabelas, em vez de `NULL`.
O SQL de migração pode ser executado novamente sem criar lançamentos ou
redefinir o nome da empresa, o perfil escolhido e os limites já salvos.

## 3. Validar e abrir o aplicativo

No terminal do Codespace:

```bash
dart format lib test
flutter analyze
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta 8080 na aba **Portas** e atualize a página. O aplicativo usa
os mesmos dados de conexão já configurados em `config/supabase.json`.

## Usar a troca de perfil

1. Entre na sua conta. Os dados antigos aparecem em Pessoal.
2. Toque em Empresa. Esse perfil começa sem receitas, despesas ou limite.
3. Toque no `+` para cadastrar um lançamento empresarial.
4. Em Relatórios, defina o limite mensal da empresa.
5. Volte para Pessoal e confira que seus valores e seu limite continuam iguais.

Para dar um nome ao negócio, selecione Empresa e abra **Perfil → Editar nome
da empresa**. O nome aceita de 1 a 60 caracteres e só muda na tela depois da
confirmação do servidor. Ele também aparece abaixo do seletor no cabeçalho.

Durante a troca, os valores ficam ocultos até que a seleção seja confirmada.
Se a troca falhar, o aplicativo continua no perfil anterior e mostra a mensagem
de erro. Se a leitura dos dados falhar, mostra o erro em vez de apresentar um
saldo fictício. Um formulário aberto em um perfil não grava em outro perfil.

## Se aparecer erro ao carregar os perfis

Confira se executou o arquivo **003_financial_profiles.sql** no projeto
**hoarqhhielhwxwoyatoy**. A instalação do ZIP não executa SQL na nuvem.
Depois de executar a migração sem erros, clique em **Tentar novamente** no
aplicativo. Se o SQL mostrar um erro, guarde a mensagem completa para corrigir
a configuração do banco antes de tentar salvar novos registros.

Os nomes e pastas dos arquivos estão em `ARQUIVOS_PERFIS.md`.
