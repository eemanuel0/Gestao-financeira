# Validação: dados reais e limites mensais

- Flutter 3.47.9 / Dart 3.13.7.
- Análise estática: **No issues found!**
- **75 testes** de modelos, serviços e interface, incluindo o fluxo financeiro completo.
- Build web release concluída.
- **8 verificações do SQL** passaram em PostgreSQL local (PGlite): isolamento entre usuários e meses, upsert independente, acesso anônimo negado, limite obrigatório e positivo, impossibilidade de transferir propriedade.

## Casos principais

- Uma despesa digitada de R$ 200,00 gera 20.000 centavos no repositório; Início e Relatórios exibem os valores registrados.
- Receita de R$ 50,00 e despesas de R$ 0,10 e R$ 0,20 resultam em despesa de R$ 0,30 e saldo de R$ 49,70.
- O mês selecionado filtra por `occurredOn`, ano, mês e usuário. Receita e dados de outra pessoa não entram nas despesas.
- Conta e mês sem orçamento não recebem R$ 1.500,00 ou outro valor de exemplo; aparece **Não definido** e o editor abre vazio.
- Salvar R$ 150,00 de limite para R$ 200,00 de despesas mostra 133% e R$ 50,00 excedentes.
- Alterar mês e trocar de usuário não reutiliza limites nem dados da conta anterior.
- Sair e voltar recupera os limites do repositório persistente de teste.
- Falhas ao carregar dados não são confundidas com ausência de dados.
- Uma falha ao consultar o limite depois de adicionar a despesa não duplica o lançamento e não mostra que a gravação da despesa falhou.
- O cliente Supabase real foi validado contra HTTP local para conferir filtros, payload do upsert, sessão e respostas inválidas.
- O bloco de código que desenha a aba Lançamentos foi comparado com a versão anterior e permaneceu igual. O formulário `add_transaction_screen.dart` não integra o pacote de correção.

## Limite da verificação

Os testes de autenticação, dados e persistência usam servidores/repositórios locais e contextos de autenticação simulados. Não foram criadas contas ou despesas fictícias no Supabase do usuário. A migração `002_monthly_limits.sql` ainda precisa ser executada no SQL Editor do projeto real; depois disso, o fluxo deve ser conferido com a conta e os lançamentos existentes.
