import 'package:flutter/material.dart';

class GenreSelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const GenreSelectionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.teal,
      checkmarkColor: Colors.white,
    );
  }
}
