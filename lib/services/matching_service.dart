import '../models/battuta.dart';
import '../utils/levenshtein.dart';
import '../utils/text_normalizer.dart';

class MatchingService {
  final double baseThreshold;
  final int windowSize;

  MatchingService({
    this.baseThreshold = 0.6,
    this.windowSize = 10,
  });

  Battuta? findMatchingBattuta({
    required String transcribedText,
    required int currentIndex,
    required List<Battuta> battute,
    double? overrideThreshold,
  }) {
    if (battute.isEmpty) return null;
    final threshold = overrideThreshold ?? baseThreshold;

    final start = currentIndex.clamp(0, battute.length);
    final end = (currentIndex + windowSize).clamp(0, battute.length);
    final normalizedTrans = TextNormalizer.normalize(transcribedText);

    double bestScore = -1.0;
    Battuta? best;

    for (int i = start; i < end; i++) {
      final b = battute[i];
      final score = _score(normalizedTrans, TextNormalizer.normalize(b.testo));
      if (score > bestScore && score >= threshold) {
        bestScore = score;
        best = b;
      }
    }
    return best;
  }

  double _score(String a, String b) {
    double score = Levenshtein.similarity(a, b);
    if (TextNormalizer.startsWithSameWords(a, b, 3)) {
      score += 0.2;
    }
    if (score > 1.0) score = 1.0;
    return score;
  }
}
