import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import 'financial_profile.dart';

enum TransactionType {
  income,
  expense;

  String get label => switch (this) {
    income => 'Receita',
    expense => 'Despesa',
  };

  String labelForProfile(String profileId) {
    if (!FinancialProfile.isBusinessId(profileId)) return label;
    return this == income ? 'Entrada' : 'Saída';
  }

  IconData get icon => switch (this) {
    income => Icons.arrow_upward,
    expense => Icons.arrow_downward,
  };
}

enum TransactionCategory {
  salary,
  services,
  food,
  housing,
  transport,
  health,
  leisure,
  other,
  sales,
  suppliers,
  payroll,
  businessRent,
  utilities,
  taxes,
  contribution,
  householdBills,
  education;

  String get label => switch (this) {
    salary => 'Salário',
    services => 'Serviços',
    food => 'Alimentação',
    housing => 'Moradia',
    transport => 'Transporte',
    health => 'Saúde',
    leisure => 'Lazer',
    other => 'Outros',
    sales => 'Vendas',
    suppliers => 'Fornecedores',
    payroll => 'Salários da equipe',
    businessRent => 'Aluguel',
    utilities => 'Contas da empresa',
    taxes => 'Impostos',
    contribution => 'Contribuição',
    householdBills => 'Contas da casa',
    education => 'Educação',
  };

  IconData get icon => switch (this) {
    salary => Icons.payments_outlined,
    services => Icons.work_outline,
    food => Icons.restaurant,
    housing => Icons.home_outlined,
    transport => Icons.directions_car_outlined,
    health => Icons.health_and_safety_outlined,
    leisure => Icons.sports_esports_outlined,
    other => Icons.category_outlined,
    sales => Icons.point_of_sale_outlined,
    suppliers => Icons.inventory_2_outlined,
    payroll => Icons.groups_outlined,
    businessRent => Icons.storefront_outlined,
    utilities => Icons.receipt_long_outlined,
    taxes => Icons.account_balance_outlined,
    contribution => Icons.volunteer_activism_outlined,
    householdBills => Icons.receipt_long_outlined,
    education => Icons.school_outlined,
  };

  // Oferece as categorias adequadas ao espaço financeiro do formulário.
  static List<TransactionCategory> allowedFor(
    TransactionType type, {
    String profileId = FinancialProfile.personalId,
  }) {
    if (profileId == FinancialProfile.familyId) {
      return switch (type) {
        TransactionType.income => const [contribution, salary, services, other],
        TransactionType.expense => const [
          food,
          housing,
          householdBills,
          transport,
          health,
          education,
          leisure,
          other,
        ],
      };
    }
    if (FinancialProfile.isBusinessId(profileId)) {
      return switch (type) {
        TransactionType.income => const [sales, services, other],
        TransactionType.expense => const [
          suppliers,
          payroll,
          businessRent,
          utilities,
          taxes,
          transport,
          other,
        ],
      };
    }
    return _personalCategories(type);
  }

  // Mantém legíveis os lançamentos empresariais criados antes da separação
  // de categorias, sem mudar a classificação ou qualquer valor já salvo.
  bool isValidFor(
    TransactionType type, {
    String profileId = FinancialProfile.personalId,
  }) {
    return allowedFor(type, profileId: profileId).contains(this) ||
        (FinancialProfile.isBusinessId(profileId) &&
            _personalCategories(type).contains(this));
  }

  static List<TransactionCategory> _personalCategories(TransactionType type) {
    return switch (type) {
      TransactionType.income => const [salary, services, other],
      TransactionType.expense => const [
        food,
        housing,
        transport,
        health,
        leisure,
        other,
      ],
    };
  }
}

class FinanceTransaction {
  static const int maxAmountCents = maxMoneyCents;

  final String id;
  final String userId;
  final String profileId;
  final TransactionType type;
  final int amountCents;
  final TransactionCategory category;
  final String description;
  final DateTime occurredOn;
  final DateTime createdAt;

  FinanceTransaction({
    required this.id,
    required this.userId,
    this.profileId = FinancialProfile.personalId,
    required this.type,
    required this.amountCents,
    required this.category,
    required this.description,
    required this.occurredOn,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty || userId.trim().isEmpty) {
      throw ArgumentError('O lançamento precisa de um ID e de um usuário.');
    }
    if (profileId.trim().isEmpty || profileId != profileId.trim()) {
      throw ArgumentError('O lançamento precisa de um perfil válido.');
    }
    if (amountCents <= 0 || amountCents > maxAmountCents) {
      throw ArgumentError.value(amountCents, 'amountCents', 'Valor inválido.');
    }
    if (description.trim().isEmpty || description.length > 120) {
      throw ArgumentError.value(
        description,
        'description',
        'A descrição deve ter entre 1 e 120 caracteres.',
      );
    }
    if (!category.isValidFor(type, profileId: profileId)) {
      throw ArgumentError('A categoria não é permitida para esse tipo.');
    }
  }

  // Converte a resposta do banco sem transformar centavos em double.
  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    final amount = json['amount_cents'];
    if (amount is! int) {
      throw const FormatException('amount_cents precisa ser um inteiro.');
    }

    return FinanceTransaction(
      id: _readString(json, 'id'),
      userId: _readString(json, 'user_id'),
      profileId: _readProfileId(json),
      type: TransactionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () =>
            throw const FormatException('Tipo de lançamento inválido.'),
      ),
      amountCents: amount,
      category: TransactionCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => throw const FormatException('Categoria inválida.'),
      ),
      description: _readString(json, 'description'),
      occurredOn: _readDate(json, 'occurred_on'),
      createdAt: _readDate(json, 'created_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'profile_id': profileId,
      'type': type.name,
      'amount_cents': amountCents,
      'category': category.name,
      'description': description,
      // A data do lançamento não sofre conversão de fuso horário.
      'occurred_on':
          '${occurredOn.year.toString().padLeft(4, '0')}-'
          '${occurredOn.month.toString().padLeft(2, '0')}-'
          '${occurredOn.day.toString().padLeft(2, '0')}',
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('O campo $key precisa ser um texto.');
    }
    return value;
  }

  static String _readProfileId(Map<String, dynamic> json) {
    if (!json.containsKey('profile_id')) {
      return FinancialProfile.personalId;
    }
    final value = json['profile_id'];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw const FormatException(
        'O campo profile_id precisa ser um ID válido.',
      );
    }
    return value;
  }

  static DateTime _readDate(Map<String, dynamic> json, String key) {
    final date = DateTime.tryParse(_readString(json, key));
    if (date == null) {
      throw FormatException('O campo $key contém uma data inválida.');
    }
    return date;
  }
}
