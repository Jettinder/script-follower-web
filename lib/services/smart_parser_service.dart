import '../models/battuta.dart';
import '../models/copione.dart';

/// Parser intelligente che analizza qualsiasi formato di copione
/// e rileva automaticamente tutti i personaggi
class SmartParserService {
  
  // Lista di personaggi comuni nel teatro e nomi propri italiani
  static const _commonCharacters = [
    'narratore', 'regista', 'coro', 'coro 1', 'coro 2', 'coro 3',
    'voce', 'tutti', 'attore', 'attrice', 'protagonista',
    // Nomi propri comuni
    'mary', 'victor', 'tom', 'sheila', 'medea', 'giasone', 'lissa', 'creonte',
    'sara', 'pietro', 'jordan', 'giacomo', 'kate', 'david', 'giovanni',
    'jon', 'amad', 'alex', 'chiara', 'simone', 'john', 'glauce',
  ];

  /// Analizza il testo e restituisce il copione con tutti i personaggi rilevati
  Copione parseFromText({
    required String id,
    required String titolo,
    required String raw,
  }) {
    // Pre-processa il testo per fixare errori comuni di OCR
    final cleanedRaw = _fixOcrErrors(raw);
    final lines = _preprocessLines(cleanedRaw);
    
    // Step 1: Rileva tutti i possibili personaggi
    final characters = _detectAllCharacters(lines);
    
    // Step 2: Estrai le battute
    final battute = _extractBattute(lines, characters);
    
    // Step 3: Raccogli solo i personaggi che hanno effettivamente battute
    final activeCharacters = battute.map((b) => b.personaggio).toSet().toList()..sort();
    
    return Copione(
      id: id,
      titolo: titolo,
      personaggi: activeCharacters,
      battute: battute,
    );
  }

  /// Corregge errori comuni di OCR
  String _fixOcrErrors(String raw) {
    var text = raw;
    
    // Fix spazi dentro le parole comuni
    final ocrFixes = {
      'Vic tor': 'Victor',
      'vic tor': 'Victor',
      'VIC TOR': 'VICTOR',
      'She ila': 'Sheila',
      'she ila': 'Sheila',
      'Reg ista': 'Regista',
      'reg ista': 'Regista',
      'Nar ratore': 'Narratore',
      'NAR RATORE': 'NARRATORE',
      'Gia sone': 'Giasone',
      'GIA SONE': 'GIASONE',
      'Med ea': 'Medea',
      'MED EA': 'MEDEA',
      'Cre onte': 'Creonte',
      'CRE ONTE': 'CREONTE',
      'Lis sa': 'Lissa',
      'LIS SA': 'LISSA',
    };
    
    for (final entry in ocrFixes.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    
    // Fix spazi prima dei due punti
    text = text.replaceAll(RegExp(r'\s+:'), ':');
    
    // Fix doppi spazi
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    
    return text;
  }

  List<String> _preprocessLines(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Rileva tutti i possibili personaggi analizzando pattern nel testo
  Set<String> _detectAllCharacters(List<String> lines) {
    final candidates = <String, int>{};
    
    for (final line in lines) {
      // Salta intestazioni di scena e didascalie pure
      if (_isSceneHeader(line) || _isPureStageDirection(line)) continue;
      
      // Pattern 1: "NOME:" o "Nome:" all'inizio della riga
      final colonMatch = RegExp(r'^([A-ZÀ-Ú][A-Za-zÀ-ú0-9\s]{0,20}):\s*').firstMatch(line);
      if (colonMatch != null) {
        final name = _normalizeName(colonMatch.group(1)!);
        if (_isValidCharacterName(name)) {
          candidates[name] = (candidates[name] ?? 0) + 5; // peso alto per :
        }
      }
      
      // Pattern 2: "CORO 1:" "CORO 2:" etc
      final coroMatch = RegExp(r'^(CORO\s*\d+)\s*:', caseSensitive: false).firstMatch(line);
      if (coroMatch != null) {
        final name = coroMatch.group(1)!.toUpperCase();
        candidates[name] = (candidates[name] ?? 0) + 5;
      }
      
      // Pattern 3: Cerca nomi noti all'inizio della riga SENZA due punti
      // (es. "Mary Altrimenti l'area...")
      for (final knownName in _getKnownNames(lines)) {
        if (line.toLowerCase().startsWith(knownName.toLowerCase())) {
          final afterName = line.substring(knownName.length).trim();
          // Verifica che dopo il nome ci sia testo che sembra dialogo
          if (afterName.isNotEmpty && 
              !afterName.startsWith(':') && 
              _looksLikeDialogue(afterName)) {
            candidates[_normalizeName(knownName)] = (candidates[_normalizeName(knownName)] ?? 0) + 3;
          }
        }
      }
    }
    
    // Aggiungi nomi comuni del teatro se presenti nel testo
    final fullText = lines.join(' ').toLowerCase();
    for (final common in _commonCharacters) {
      if (fullText.contains(common)) {
        final normalized = _normalizeName(common);
        candidates[normalized] = (candidates[normalized] ?? 0) + 1;
      }
    }
    
    // Filtra candidati validi
    final confirmed = <String>{};
    for (final entry in candidates.entries) {
      if (entry.value >= 1) {
        confirmed.add(entry.key);
      }
    }
    
    return confirmed;
  }

  /// Estrae nomi che appaiono con ":" nel testo
  Set<String> _getKnownNames(List<String> lines) {
    final names = <String>{};
    final colonPattern = RegExp(r'^([A-ZÀ-Ú][A-Za-zÀ-ú0-9\s]{1,20}):', caseSensitive: false);
    
    for (final line in lines) {
      final match = colonPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (_isValidCharacterName(name)) {
          names.add(name);
        }
      }
    }
    
    // Aggiungi nomi comuni del copione
    names.addAll([
      'Mary', 'Tom', 'Victor', 'Sheila', 'Medea', 'Giasone', 
      'Creonte', 'Lissa', 'Regista', 'Narratore',
      'Sara', 'Pietro', 'Jordan', 'Giacomo', 'Kate', 'David', 'Giovanni',
      'Jon', 'Amad', 'Alex', 'Chiara', 'Simone', 'John', 'Glauce',
      'CORO 1', 'CORO 2', 'Coro 1', 'Coro 2',
    ]);
    
    return names;
  }

  /// Verifica se il testo sembra un dialogo
  bool _looksLikeDialogue(String text) {
    if (text.length < 5) return false;
    // Inizia con maiuscola o minuscola e contiene parole
    if (!RegExp(r'^[A-Za-zÀ-ú]').hasMatch(text)) return false;
    // Non è solo una didascalia
    if (text.startsWith('(') && text.endsWith(')')) return false;
    return true;
  }

  /// Estrae le battute dal testo usando i personaggi rilevati
  List<Battuta> _extractBattute(List<String> lines, Set<String> characters) {
    final battute = <Battuta>[];
    String? currentCharacter;
    final currentText = StringBuffer();
    int index = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Salta intestazioni e didascalie pure
      if (_isSceneHeader(line)) continue;
      if (_isPureStageDirection(line)) continue;
      
      // Cerca match con personaggi noti
      final parseResult = _parseCharacterLine(line, characters);
      
      if (parseResult != null) {
        // Salva battuta precedente
        if (currentCharacter != null && currentText.isNotEmpty) {
          final cleanText = _cleanDialogue(currentText.toString());
          if (cleanText.isNotEmpty) {
            battute.add(Battuta(
              index: index++,
              personaggio: currentCharacter,
              testo: cleanText,
            ));
          }
        }
        
        currentCharacter = parseResult.$1;
        currentText.clear();
        if (parseResult.$2.isNotEmpty) {
          currentText.write(parseResult.$2);
        }
      } else if (currentCharacter != null) {
        // Continua battuta precedente
        final cleaned = _cleanDialogue(line);
        if (cleaned.isNotEmpty) {
          if (currentText.isNotEmpty) currentText.write(' ');
          currentText.write(cleaned);
        }
      }
    }
    
    // Ultima battuta
    if (currentCharacter != null && currentText.isNotEmpty) {
      final cleanText = _cleanDialogue(currentText.toString());
      if (cleanText.isNotEmpty) {
        battute.add(Battuta(
          index: index++,
          personaggio: currentCharacter,
          testo: cleanText,
        ));
      }
    }
    
    return battute;
  }

  /// Prova a parsare una riga come battuta di un personaggio
  (String, String)? _parseCharacterLine(String line, Set<String> characters) {
    // Pattern 1: "Nome:" o "NOME:"
    final colonMatch = RegExp(r'^([A-ZÀ-Ú][A-Za-zÀ-ú0-9\s]{0,25}):\s*(.*)$').firstMatch(line);
    if (colonMatch != null) {
      final rawName = colonMatch.group(1)!.trim();
      final name = _normalizeName(rawName);
      final text = colonMatch.group(2)?.trim() ?? '';
      
      // Verifica che sia un personaggio noto o valido
      if (characters.contains(name) || _isValidCharacterName(rawName)) {
        return (name, _cleanDialogue(text));
      }
    }
    
    // Pattern 2: "CORO 1:" "CORO 2:"
    final coroMatch = RegExp(r'^(CORO\s*\d+)\s*:\s*(.*)$', caseSensitive: false).firstMatch(line);
    if (coroMatch != null) {
      final name = coroMatch.group(1)!.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
      final text = coroMatch.group(2)?.trim() ?? '';
      return (name, _cleanDialogue(text));
    }
    
    // Pattern 3: Nome noto senza due punti (es. "Mary Altrimenti...")
    for (final char in characters) {
      final lowerLine = line.toLowerCase();
      final charLower = char.toLowerCase();
      
      if (lowerLine.startsWith(charLower)) {
        final afterName = line.substring(char.length).trim();
        
        // Se c'è ":" subito dopo, usa quello
        if (afterName.startsWith(':')) {
          final text = afterName.substring(1).trim();
          return (char, _cleanDialogue(text));
        }
        
        // Altrimenti, se sembra un dialogo
        if (afterName.isNotEmpty && _looksLikeDialogue(afterName)) {
          // Verifica che non sia parte di una frase più lunga
          final nextWord = afterName.split(' ').first.toLowerCase();
          if (!_isCommonWord(nextWord)) {
            return (char, _cleanDialogue(afterName));
          }
        }
      }
    }
    
    return null;
  }

  bool _isCommonWord(String word) {
    final common = {'è', 'e', 'il', 'la', 'lo', 'i', 'gli', 'le', 'un', 'una', 
                    'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
                    'che', 'non', 'si', 'mi', 'ti', 'ci', 'vi', 'ne'};
    return common.contains(word.toLowerCase());
  }

  String _normalizeName(String name) {
    var cleaned = name.trim();
    
    // Rimuovi punteggiatura finale
    cleaned = cleaned.replaceAll(RegExp(r'[:\s]+$'), '');
    
    // Gestisci CORO 1, CORO 2 etc
    if (cleaned.toUpperCase().startsWith('CORO')) {
      return cleaned.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }
    
    // Gestisci NARRATORE
    if (cleaned.toUpperCase() == 'NARRATORE') {
      return 'Narratore';
    }
    
    // Title case per altri nomi tutto maiuscolo
    if (cleaned == cleaned.toUpperCase() && cleaned.length > 2) {
      return cleaned.split(' ').map((w) {
        if (w.isEmpty) return w;
        if (RegExp(r'^\d+$').hasMatch(w)) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');
    }
    
    // Capitalizza prima lettera
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    
    return cleaned;
  }

  bool _isValidCharacterName(String name) {
    if (name.length < 2 || name.length > 30) return false;
    
    // Escludi parole comuni che non sono personaggi
    final excluded = {
      'scena', 'atto', 'primo', 'secondo', 'terzo', 'quarto', 'quinto',
      'prologo', 'epilogo', 'fine', 'inizio', 'pausa', 'intervallo',
      'musica', 'canzone', 'coreografia', 'video', 'luce', 'luci',
      'buio', 'sipario', 'entra', 'esce', 'entrano', 'escono',
      'continua', 'segue', 'nota', 'note', 'didascalia', 'stop',
      'ok', 'silenzio', 'forza', 'benissimo', 'ottimo', 'perfetto',
      'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x',
    };
    
    if (excluded.contains(name.toLowerCase())) return false;
    
    // Deve contenere almeno una lettera
    if (!RegExp(r'[A-Za-zÀ-ú]').hasMatch(name)) return false;
    
    // Non deve essere solo numeri
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    
    return true;
  }

  bool _isSceneHeader(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('scena ') ||
           lower.startsWith('atto ') ||
           lower.startsWith('i atto') ||
           lower.startsWith('ii atto') ||
           lower.startsWith('iii atto') ||
           RegExp(r'^(scena|atto)\s+\d', caseSensitive: false).hasMatch(line) ||
           RegExp(r'^\d+\s*$').hasMatch(line) || // solo numero pagina
           lower.contains('- l\'orgoglio') ||
           lower.contains('- la critica');
  }

  bool _isPureStageDirection(String line) {
    // Didascalia pura tra parentesi
    if (RegExp(r'^\([^)]+\)$').hasMatch(line)) return true;
    if (RegExp(r'^\[[^\]]+\]$').hasMatch(line)) return true;
    
    // Indicazioni tecniche
    final lower = line.toLowerCase();
    if (lower.startsWith('coreografia ')) return true;
    if (lower.startsWith('canzone ')) return true;
    if (lower.startsWith('canzone –')) return true;
    if (lower.startsWith('musica ')) return true;
    if (lower.startsWith('video ')) return true;
    if (lower.startsWith('proiezione ')) return true;
    if (lower.startsWith('siamo sullo stage')) return true;
    if (lower.startsWith('tutti arrivano')) return true;
    if (lower.startsWith('dopo pochi istanti')) return true;
    
    return false;
  }

  String _cleanDialogue(String text) {
    var cleaned = text.trim();
    
    // Rimuovi didascalie all'inizio
    cleaned = cleaned.replaceAll(RegExp(r'^\([^)]+\)\s*'), '');
    
    // Mantieni didascalie inline ma rimuovi quelle finali se sono l'unico contenuto
    if (RegExp(r'^\s*\([^)]+\)\s*$').hasMatch(cleaned)) {
      return '';
    }
    
    // Rimuovi didascalie alla fine
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]+\)$'), '');
    
    // Normalizza spazi
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }
}
