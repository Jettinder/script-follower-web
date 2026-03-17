import '../models/battuta.dart';
import '../models/copione.dart';

class ParserService {
  // Common character name patterns
  final _characterPatterns = [
    // NOME: testo or Nome: testo
    RegExp(r'^([A-Z][A-Za-z0-9\s]{0,20}):\s*(.+)$'),
    // NOME : testo (with space before colon)
    RegExp(r'^([A-Z][A-Za-z0-9\s]{0,20})\s+:\s*(.+)$'),
    // CORO 1: or CORO 2: etc
    RegExp(r'^(CORO\s*\d*):\s*(.+)$', caseSensitive: false),
    // NARRATORE:
    RegExp(r'^(NARRATORE):\s*(.+)$', caseSensitive: false),
  ];

  // Lines to skip (stage directions, scene headers)
  final _skipPatterns = [
    RegExp(r'^(Scena|SCENA|I ATTO|II ATTO|III ATTO|ATTO)', caseSensitive: false),
    RegExp(r'^(COREOGRAFIA|CANZONE)\s', caseSensitive: false),
    RegExp(r'^\d+$'), // Just page numbers
    RegExp(r'^[\(\[].*[\)\]]$'), // Pure stage directions in parentheses
  ];

  Copione parseFromText({
    required String id,
    required String titolo,
    required String raw,
  }) {
    final cleaned = _preprocess(raw);
    final lines = cleaned.split('\n');
    
    // First pass: identify all character names
    final Set<String> discoveredCharacters = {};
    for (final line in lines) {
      final charName = _extractCharacterName(line);
      if (charName != null) {
        discoveredCharacters.add(_normalizeCharacterName(charName));
      }
    }
    
    // Second pass: parse battute
    final List<Battuta> battute = [];
    final Set<String> personaggi = {};
    
    String? currentCharacter;
    StringBuffer currentText = StringBuffer();
    int index = 0;
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_shouldSkipLine(trimmed)) continue;
      
      // Try to parse as new character line
      final parsed = _parseCharacterLine(trimmed, discoveredCharacters);
      
      if (parsed != null) {
        // Save previous battuta
        if (currentCharacter != null && currentText.isNotEmpty) {
          final cleanedText = _cleanBattutaText(currentText.toString());
          if (cleanedText.isNotEmpty) {
            personaggi.add(currentCharacter);
            battute.add(Battuta(
              index: index++,
              personaggio: currentCharacter,
              testo: cleanedText,
            ));
          }
        }
        currentCharacter = parsed.$1;
        currentText = StringBuffer(parsed.$2);
      } else if (currentCharacter != null) {
        // Continuation of previous battuta
        final continuation = _cleanContinuationLine(trimmed);
        if (continuation.isNotEmpty) {
          if (currentText.isNotEmpty) currentText.write(' ');
          currentText.write(continuation);
        }
      }
    }
    
    // Don't forget the last battuta
    if (currentCharacter != null && currentText.isNotEmpty) {
      final cleanedText = _cleanBattutaText(currentText.toString());
      if (cleanedText.isNotEmpty) {
        personaggi.add(currentCharacter);
        battute.add(Battuta(
          index: index++,
          personaggio: currentCharacter,
          testo: cleanedText,
        ));
      }
    }
    
    return Copione(
      id: id,
      titolo: titolo,
      personaggi: personaggi.toList()..sort(),
      battute: battute,
    );
  }

  String _preprocess(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        // Fix common PDF extraction issues
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('. ', '.\n')
        .replaceAll('? ', '?\n')
        .replaceAll('! ', '!\n')
        .replaceAll(': ', ':\n')
        .trim();
  }

  String? _extractCharacterName(String line) {
    for (final pattern in _characterPatterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim();
      }
    }
    
    // Check for known character names at start of line
    final knownNames = ['Regista', 'Mary', 'Tom', 'Victor', 'Sheila', 'Medea', 
                        'Giasone', 'Creonte', 'Lissa', 'Narratore'];
    for (final name in knownNames) {
      if (line.startsWith('$name:') || line.startsWith('$name ')) {
        return name;
      }
      if (line.toUpperCase().startsWith('${name.toUpperCase()}:') ||
          line.toUpperCase().startsWith('${name.toUpperCase()} ')) {
        return name;
      }
    }
    
    return null;
  }

  bool _shouldSkipLine(String line) {
    for (final pattern in _skipPatterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  (String, String)? _parseCharacterLine(String line, Set<String> knownCharacters) {
    // Try standard patterns first
    for (final pattern in _characterPatterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.groupCount >= 2) {
        final name = _normalizeCharacterName(match.group(1)!.trim());
        final text = match.group(2)!.trim();
        if (text.isNotEmpty) {
          return (name, text);
        }
      }
    }
    
    // Try matching known characters without colon
    for (final charName in knownCharacters) {
      final lowerLine = line.toLowerCase();
      final lowerChar = charName.toLowerCase();
      
      // Check "CharName text..." pattern
      if (lowerLine.startsWith(lowerChar)) {
        final afterName = line.substring(charName.length).trim();
        if (afterName.startsWith(':')) {
          final text = afterName.substring(1).trim();
          if (text.isNotEmpty) return (charName, text);
        } else if (afterName.isNotEmpty && !_looksLikeCharacterName(afterName)) {
          return (charName, afterName);
        }
      }
    }
    
    return null;
  }

  String _normalizeCharacterName(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return cleaned;
    
    // Handle CORO 1, CORO 2, etc
    if (cleaned.toUpperCase().startsWith('CORO')) {
      return cleaned.toUpperCase();
    }
    
    // Title case for others
    if (cleaned == cleaned.toUpperCase() && cleaned.length > 2) {
      return cleaned.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    
    // Capitalize first letter
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _cleanBattutaText(String text) {
    var cleaned = text.trim();
    // Remove stage directions in parentheses at start/end
    cleaned = cleaned.replaceAll(RegExp(r'^\([^)]+\)\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]+\)$'), '');
    // Keep inline stage directions but mark them
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  String _cleanContinuationLine(String line) {
    // Skip pure stage directions
    if (RegExp(r'^\([^)]+\)$').hasMatch(line.trim())) {
      return '';
    }
    return line.trim();
  }

  bool _looksLikeCharacterName(String s) {
    if (s.length > 30) return false;
    // Check if it starts with uppercase and is short
    final firstWord = s.split(' ').first;
    return firstWord.length <= 15 && 
           firstWord[0] == firstWord[0].toUpperCase() &&
           !s.contains('.') && !s.contains(',') && !s.contains('!') && !s.contains('?');
  }
}
