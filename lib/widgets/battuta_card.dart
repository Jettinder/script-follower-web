import 'package:flutter/material.dart';
import '../models/battuta.dart';

class BattutaCard extends StatelessWidget {
  final Battuta battuta;
  final bool isCurrent;
  final bool isUserCharacter;

  const BattutaCard({
    super.key,
    required this.battuta,
    required this.isCurrent,
    required this.isUserCharacter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg = Colors.transparent;
    if (isCurrent) {
      bg = theme.colorScheme.primary.withOpacity(0.15);
    } else if (isUserCharacter) {
      bg = theme.colorScheme.secondary.withOpacity(0.12);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyLarge,
          children: [
            TextSpan(
              text: '${battuta.personaggio}: ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextSpan(
              text: battuta.testo,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
