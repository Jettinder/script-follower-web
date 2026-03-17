import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/copioni_provider.dart';
import '../services/file_import_service.dart';
import '../services/smart_parser_service.dart';
import '../models/copione.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  Copione? _preview;
  bool _isLoading = false;
  String? _errorMsg;
  final _fileService = FileImportService();
  final _smartParser = SmartParserService();
  
  // Personaggi selezionati/deselezionati dall'utente
  Set<String> _selectedCharacters = {};
  Set<String> _allDetectedCharacters = {};

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final result = await _fileService.pickAndReadFile();
      if (result != null) {
        _titleCtrl.text = result.title;
        _textCtrl.text = result.text;
        await _analyze();
      }
    } catch (e) {
      setState(() => _errorMsg = 'Errore lettura file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _analyze() async {
    if (_textCtrl.text.trim().isEmpty) {
      setState(() {
        _preview = null;
        _errorMsg = 'Inserisci il testo del copione';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Usa lo smart parser
      final parsed = _smartParser.parseFromText(
        id: 'preview',
        titolo: _titleCtrl.text.isEmpty ? 'Anteprima' : _titleCtrl.text,
        raw: _textCtrl.text,
      );
      
      setState(() {
        _preview = parsed;
        _allDetectedCharacters = parsed.personaggi.toSet();
        _selectedCharacters = parsed.personaggi.toSet(); // tutti selezionati di default
        _errorMsg = parsed.battute.isEmpty 
            ? 'Nessuna battuta trovata. Verifica il formato del testo.'
            : null;
      });
    } catch (e) {
      setState(() => _errorMsg = 'Errore analisi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleCharacter(String char) {
    setState(() {
      if (_selectedCharacters.contains(char)) {
        _selectedCharacters.remove(char);
      } else {
        _selectedCharacters.add(char);
      }
      _updatePreviewWithSelectedCharacters();
    });
  }

  void _updatePreviewWithSelectedCharacters() {
    if (_preview == null) return;
    
    // Filtra le battute per includere solo i personaggi selezionati
    final filteredBattute = _preview!.battute
        .where((b) => _selectedCharacters.contains(b.personaggio))
        .toList();
    
    // Rinumera gli indici
    for (int i = 0; i < filteredBattute.length; i++) {
      filteredBattute[i] = filteredBattute[i].copyWith(index: i);
    }
    
    setState(() {
      _preview = Copione(
        id: _preview!.id,
        titolo: _preview!.titolo,
        personaggi: _selectedCharacters.toList()..sort(),
        battute: filteredBattute,
      );
    });
  }

  Future<void> _addCustomCharacter() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aggiungi personaggio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nome del personaggio',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _allDetectedCharacters.add(result);
        _selectedCharacters.add(result);
      });
      // Ri-analizza con il nuovo personaggio
      _reanalyzeWithCharacters();
    }
  }

  void _reanalyzeWithCharacters() {
    if (_textCtrl.text.isEmpty) return;
    
    final parsed = _smartParser.parseFromText(
      id: 'preview',
      titolo: _titleCtrl.text.isEmpty ? 'Anteprima' : _titleCtrl.text,
      raw: _textCtrl.text,
    );
    
    // Unisci i personaggi rilevati con quelli aggiunti manualmente
    _allDetectedCharacters.addAll(parsed.personaggi);
    
    setState(() {
      _preview = Copione(
        id: parsed.id,
        titolo: parsed.titolo,
        personaggi: _selectedCharacters.toList()..sort(),
        battute: parsed.battute.where((b) => _selectedCharacters.contains(b.personaggio)).toList(),
      );
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo')),
      );
      return;
    }
    if (_preview == null || _preview!.battute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analizza prima il copione')),
      );
      return;
    }
    
    final provider = context.read<CopioniProvider>();
    
    // Salva usando il preview filtrato
    final copione = await provider.importParsedCopione(
      titolo: _titleCtrl.text.trim(),
      personaggi: _selectedCharacters.toList(),
      battute: _preview!.battute,
    );
    
    if (mounted) Navigator.of(context).pop(copione);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa Copione'),
        actions: [
          if (_preview != null && _preview!.battute.isNotEmpty)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salva'),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File picker card
                Card(
                  child: InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Carica da PDF o TXT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tocca per selezionare un file',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                Text(
                  'Oppure incolla il testo:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Title field
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titolo copione',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Text field
                TextField(
                  controller: _textCtrl,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Testo del copione',
                    hintText: 'Incolla qui il testo del copione...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Analyze button
                FilledButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Analizza Automaticamente'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                
                // Error message
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMsg!)),
                      ],
                    ),
                  ),
                ],
                
                // Preview section
                if (_allDetectedCharacters.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildCharacterSelectionSection(),
                ],
                
                if (_preview != null && _preview!.battute.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPreviewSection(),
                ],
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analisi in corso...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Personaggi Rilevati',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addCustomCharacter,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deseleziona i personaggi da escludere:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDetectedCharacters.map((char) {
                final isSelected = _selectedCharacters.contains(char);
                final count = _preview?.battute.where((b) => b.personaggio == char).length ?? 0;
                return FilterChip(
                  label: Text('$char ($count)'),
                  selected: isSelected,
                  onSelected: (_) => _toggleCharacter(char),
                  avatar: isSelected 
                      ? const Icon(Icons.check, size: 16)
                      : const Icon(Icons.close, size: 16),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              '${_selectedCharacters.length} personaggi selezionati',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final p = _preview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${p.battute.length} battute pronte per ${_selectedCharacters.length} personaggi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        const Text(
          'Anteprima:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        // Preview list
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: p.battute.take(10).length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, i) {
              final b = p.battute[i];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${b.personaggio}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: b.testo.length > 100 
                            ? '${b.testo.substring(0, 100)}...' 
                            : b.testo,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        if (p.battute.length > 10) ...[
          const SizedBox(height: 8),
          Text(
            '... e altre ${p.battute.length - 10} battute',
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Save button
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Salva Copione'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }
}
