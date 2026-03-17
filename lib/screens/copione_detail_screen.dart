import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/copione.dart';
import '../providers/prova_provider.dart';
import '../widgets/battuta_card.dart';
import 'prova_screen.dart';

class CopioneDetailScreen extends StatefulWidget {
  final Copione copione;
  const CopioneDetailScreen({super.key, required this.copione});

  @override
  State<CopioneDetailScreen> createState() => _CopioneDetailScreenState();
}

class _CopioneDetailScreenState extends State<CopioneDetailScreen> {
  String? _selected;
  bool _showAllBattute = false;

  @override
  void initState() {
    super.initState();
    final prova = context.read<ProvaProvider>();
    prova.loadCopione(widget.copione);
  }

  int _countBattuteForCharacter(String personaggio) {
    return widget.copione.battute.where((b) => b.personaggio == personaggio).length;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.copione;
    final battuteDaMostrare = _showAllBattute ? c.battute : c.battute.take(20).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(c.titolo),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(c),
          ),
        ],
      ),
      body: Column(
        children: [
          // Character selection header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Seleziona il tuo personaggio',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: c.personaggi.map((p) {
                    final count = _countBattuteForCharacter(p);
                    final isSelected = _selected == p;
                    return FilterChip(
                      label: Text('$p ($count)'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selected = p);
                        context.read<ProvaProvider>().selectPersonaggio(p);
                      },
                      avatar: isSelected ? const Icon(Icons.check, size: 18) : null,
                    );
                  }).toList(),
                ),
                if (_selected != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Interpreti: $_selected (${_countBattuteForCharacter(_selected!)} battute)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Preview section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Anteprima copione',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _showAllBattute = !_showAllBattute),
                  child: Text(_showAllBattute ? 'Mostra meno' : 'Mostra tutto'),
                ),
              ],
            ),
          ),
          
          // Battute list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: battuteDaMostrare.length + (_showAllBattute ? 0 : 1),
              itemBuilder: (_, i) {
                if (!_showAllBattute && i == battuteDaMostrare.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '... e altre ${c.battute.length - 20} battute',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                final b = battuteDaMostrare[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: BattutaCard(
                    battuta: b,
                    isCurrent: false,
                    isUserCharacter: _selected != null && b.personaggio == _selected,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _selected == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProvaScreen()),
                    );
                  },
            icon: const Icon(Icons.play_arrow),
            label: const Text('INIZIA PROVA'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(Copione c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.titolo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.people, '${c.personaggi.length} personaggi'),
            const SizedBox(height: 8),
            _infoRow(Icons.format_quote, '${c.battute.length} battute totali'),
            const SizedBox(height: 16),
            const Text('Personaggi:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...c.personaggi.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $p (${_countBattuteForCharacter(p)} battute)'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
