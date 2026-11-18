import 'package:flutter/material.dart';

// Total monetário de uma categoria no relatório.
class CategoryTotal {
  final String name;
  final IconData icon;
  final double total;

  const CategoryTotal({
    required this.name,
    required this.icon,
    required this.total,
  }) : assert(total >= 0);
}
