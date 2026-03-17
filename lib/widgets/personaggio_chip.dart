import 'package:flutter/material.dart';

class PersonaggioChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const PersonaggioChip({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(name),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
