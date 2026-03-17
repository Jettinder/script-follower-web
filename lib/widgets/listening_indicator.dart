import 'package:flutter/material.dart';

class ListeningIndicator extends StatelessWidget {
  final bool active;
  const ListeningIndicator({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.mic : Icons.mic_off,
          color: active ? Colors.red : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(active ? 'Microfono attivo' : 'Microfono disattivo'),
      ],
    );
  }
}
