# Validação da atualização

## Ambiente

- Flutter 3.47.9 / Dart 3.13.7, compatíveis com a restrição do `pubspec.yaml` recebido.
- `supabase_flutter` 2.18.3 e `google_fonts` 9.0.0.
- Nenhum projeto Supabase real ou credencial do usuário foi utilizado nesta etapa.

## Verificações concluídas

- **`flutter analyze`: No issues found!**
- **`flutter test`: 33 testes passaram.**
- **Build web release: concluída.** Compilação também passou no Flutter 3.50.0; a análise principal usa a versão 3.47.9 compatível com o projeto recebido.
- **Chromium em 360 × 720:** a build web abriu as boas-vindas e o login e exibiu a validação de campos vazios sem erros JavaScript. O teste usou recursos do renderizador servidos pelo próprio app, como no comando do guia, e uma configuração pública fictícia, sem autenticar em um serviço real.
- **Instalação e reinstalação:** ZIP conferido; instalador preservou arquivos fora da atualização, configuração existente e regras anteriores do Git; backup dos arquivos substituídos conferido.
- **Banco PostgreSQL de teste: 9 verificações passaram.** O SQL foi executado em uma instância local PGlite, com o contexto de autenticação simulado para duas pessoas. A migração foi executada duas vezes para conferir sua reaplicação.

### Testes do aplicativo

- Conversão de moeda em centavos, limites e entradas inválidas.
- Saldo zerado, receitas, despesas, saldo negativo e percentuais por categoria.
- Login/cadastro: validação, tratamento de erros, confirmação de e-mail e proteção contra envio duplicado.
- Conta A adiciona receitas/despesas; B começa zerada; retornar a A preserva seus dados no repositório de teste.
- Falha ao salvar mantém os campos preenchidos para uma nova tentativa.
- Layout em 360 px, teclado aberto e tela de boas-vindas com pouca altura.
- Cliente Supabase real contra servidor HTTP local: autenticação, usuário da sessão no lançamento, filtro de proprietário, paginação de 1.001 registros, rejeição de registros de outra conta e descarte de resposta pendente após logout.
- Configuração rejeita chaves administrativas.

### Testes das regras do banco

- Uma conta nova não vê lançamentos.
- A cadastra um lançamento próprio.
- A não consegue cadastrar para B nem transferir a propriedade de um lançamento.
- B não lê os dados de A, mesmo consultando a tabela sem filtro no cliente.
- B não altera nem apaga registros de A.
- Valores zero, negativos, acima do limite e categorias incompatíveis são rejeitados.
- Após B cadastrar seus próprios dados, A continua vendo apenas os próprios registros.
- Acesso anônimo é negado.

## Etapa que depende do seu projeto Supabase

O banco na nuvem ainda precisa ser criado e receber a migração. Após configurar a URL e a chave pública, faça a conferência manual com duas contas e outro dispositivo descrita em `LEIA_PRIMEIRO.md`. Essa etapa confirma também a configuração de e-mail e o serviço real; os testes locais não substituem essa conexão.

As contas e os valores usados nos testes são fixtures locais. O aplicativo entregue e o SQL não criam dados financeiros de exemplo.
