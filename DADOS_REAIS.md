# Correção: valores reais em todas as telas financeiras

Início, Lançamentos e Relatórios usam a mesma lista carregada do Supabase para a conta autenticada. As somas são feitas em centavos inteiros. Receitas não entram na soma das despesas.

- Início e Lançamentos consideram o histórico completo da conta.
- Relatórios filtra os lançamentos pela data, pelo ano e pelo mês selecionado.
- As categorias são calculadas dos lançamentos presentes nesse mês. Não existem linhas de exemplo.
- Um mês sem despesas mostra zero. Falha ao carregar dados mostra erro, sem apresentar zero como se fosse um saldo real.
- Sem um limite cadastrado, aparece **Não definido** e o campo de edição abre vazio.
- O limite é salvo no Supabase para a combinação usuário + mês. Ele pode ser recuperado depois de sair, reiniciar ou entrar em outro dispositivo.
- A tela de Lançamentos e o formulário de adicionar receitas/despesas são preservados.

## 1. Instalar no Codespace

Pare o Flutter com Ctrl+C. Envie `financas_dados_reais.zip` para a raiz do projeto e execute:

```bash
python3 -m zipfile -e financas_dados_reais.zip .
bash financas_atualizado/instalar.sh
dart format lib test
flutter analyze
flutter test
```

A pasta extraída tem o mesmo nome da atualização anterior: `financas_atualizado/`. O instalador usa um manifesto novo e copia somente os arquivos desta correção. Antes de substituir, faz backup. Não altera `config/supabase.json`, os lançamentos salvos, o formulário de lançamentos ou os arquivos Android/iOS.

Não há novos pacotes; mantenha o `pubspec.yaml` atual.

## 2. Criar a tabela de limites no Supabase

**Pasta:** `supabase/migrations/`  
**Novo arquivo:** `002_monthly_limits.sql`

No terminal do Codespace, mostre o SQL:

```bash
cat supabase/migrations/002_monthly_limits.sql
```

Copie de `begin;` até `commit;` e execute no **SQL Editor** do mesmo projeto Supabase já configurado. O comando `cat ...` pertence ao terminal e fica fora do SQL Editor.

O resultado esperado é **Success. No rows returned**. O SQL cria somente a tabela de limites e as regras de acesso. Ele não altera nem apaga a tabela `transactions`, os usuários ou as despesas existentes, e não cadastra valores de exemplo.

Se a tabela não tiver sido criada, o app informa que o limite está indisponível. Essa falha não transforma o limite em zero nem impede a gravação dos lançamentos.

## 3. Abrir o app

Use a configuração que você já salvou:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta 8080 pelo painel PORTAS do Codespace.

## Conferência manual

1. Em uma conta de teste, cadastre uma despesa de R$ 200,00 com data no mês atual. Se ela já existir, confira o registro existente.
2. Em Relatórios, selecione esse mesmo mês. O total e a categoria devem refletir os R$ 200,00 registrados; se houver outras despesas, elas também entram na soma.
3. Toque em **Definir limite**. O campo deve começar vazio. Para testar o aviso, defina R$ 150,00.
4. Com somente a despesa de R$ 200,00, o resultado deve ser 133% e R$ 50,00 acima do limite.
5. Selecione um mês sem registros: despesa zero, tabela vazia e nenhum limite pré-definido.
6. Volte ao mês anterior, saia e entre novamente: o limite cadastrado deve continuar disponível naquele mês.
7. Entre em outra conta: valores e limites da primeira não aparecem.

O alerta é apresentado dentro do aplicativo. Após salvar uma nova despesa, o app confere o limite do mês dessa despesa e avisa se ele foi ultrapassado. O banner também acompanha o total real em Relatórios. Não há notificação de sistema com o app fechado nesta atualização.

## Arquivos

Consulte `ARQUIVOS_DADOS_REAIS.md`: cada arquivo está identificado por pasta e nome. A migração deve ser executada manualmente no seu painel Supabase; não foi aplicada automaticamente ao banco na nuvem.
