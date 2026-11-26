# Gestao-financeira
Aplicativo de gestão financeira desenvolvido em Flutter e Dart

## Gestão familiar

A aba **Familiar** reúne os lançamentos, o saldo e o limite mensal de um grupo.
Cada pessoa entra com sua própria conta e o Supabase controla o acesso ao grupo.
Os históricos de **Pessoal** e **Empresa** são privados.

1. No SQL Editor do mesmo projeto Supabase, execute [005_family_group.sql](supabase/migrations/005_family_group.sql) após as migrações 001 a 004.
2. Abra o app atualizado, selecione **Familiar** e toque em **Criar grupo familiar**.
3. Em **Grupo familiar**, gere um convite e compartilhe o código com a pessoa convidada. Ela deve entrar na própria conta e escolher **Familiar → Entrar com convite**.
4. Use o botão **+** para registrar uma contribuição ou despesa e **Relatórios** para definir o limite mensal compartilhado.

O convite vale por sete dias e pode ser usado uma vez. Gerar outro código invalida
o anterior. O responsável pode remover membros e cada convidado pode sair do
grupo. Os registros permanecem no grupo depois da saída de um membro.
