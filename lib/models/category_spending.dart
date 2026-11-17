import 'package:flutter/material.dart';

// Guarda as informações de uma categoria de gastos.
class CategorySpending {
  final String name;
  final IconData icon;
  final double percentage;

  const CategorySpending({
    required this.name,
    required this.icon,
    required this.percentage,
  }) : assert(percentage >= 0 && percentage <= 100);
}
