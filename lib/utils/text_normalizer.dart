class TextNormalizer {
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final withoutPunct = lower.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    final collapsed = withoutPunct.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed;
  }

  static List<String> words(String input) {
    final n = normalize(input);
    if (n.isEmpty) return [];
    return n.split(' ');
  }

  static bool startsWithSameWords(String a, String b, int n) {
    final wa = words(a);
    final wb = words(b);
    if (wa.isEmpty || wb.isEmpty) return false;
    final len = n.clamp(1, wa.length < wb.length ? wa.length : wb.length);
    for (int i = 0; i < len; i++) {
      if (wa[i] != wb[i]) return false;
    }
    return true;
  }
}
