import 'package:flutter/material.dart';

import '../utils/formatters.dart';

enum TransactionType {
  income,
  expense;

  String get label => switch (this) {
    income => 'Receita',
    expense => 'Despesa',
  };

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
  other;

  String get label => switch (this) {
    salary => 'Salário',
    services => 'Serviços',
    food => 'Alimentação',
    housing => 'Moradia',
    transport => 'Transporte',
    health => 'Saúde',
    leisure => 'Lazer',
    other => 'Outros',
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
  };

  // Impede usar categorias de receita em despesas e vice-versa.
  static List<TransactionCategory> allowedFor(TransactionType type) {
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
  final TransactionType type;
  final int amountCents;
  final TransactionCategory category;
  final String description;
  final DateTime occurredOn;
  final DateTime createdAt;

  FinanceTransaction({
    required this.id,
    required this.userId,
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
    if (!TransactionCategory.allowedFor(type).contains(category)) {
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

  static DateTime _readDate(Map<String, dynamic> json, String key) {
    final date = DateTime.tryParse(_readString(json, key));
    if (date == null) {
      throw FormatException('O campo $key contém uma data inválida.');
    }
    return date;
  }
}
