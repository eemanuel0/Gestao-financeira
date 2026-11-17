import 'category_spending.dart';
import 'finance_transaction.dart';

class FinanceSummary {
  final int incomeCents;
  final int expenseCents;
  final List<CategorySpending> categories;

  int get balanceCents => incomeCents - expenseCents;

  const FinanceSummary._({
    required this.incomeCents,
    required this.expenseCents,
    required this.categories,
  });

  factory FinanceSummary.fromTransactions(
    List<FinanceTransaction> transactions,
  ) {
    var income = 0;
    var expenses = 0;
    final totalsByCategory = <TransactionCategory, int>{};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amountCents;
      } else {
        expenses += transaction.amountCents;
        totalsByCategory.update(
          transaction.category,
          (total) => total + transaction.amountCents,
          ifAbsent: () => transaction.amountCents,
        );
      }
    }

    // Ordena os maiores gastos primeiro; empates seguem a ordem do enum.
    final sortedCategories = totalsByCategory.entries.toList()
      ..sort((first, second) {
        final byAmount = second.value.compareTo(first.value);
        return byAmount != 0
            ? byAmount
            : first.key.index.compareTo(second.key.index);
      });

    return FinanceSummary._(
      incomeCents: income,
      expenseCents: expenses,
      categories: List<CategorySpending>.unmodifiable(
        sortedCategories.map(
          (entry) => CategorySpending(
            name: entry.key.label,
            icon: entry.key.icon,
            percentage: entry.value / expenses * 100,
          ),
        ),
      ),
    );
  }
}
