import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prova_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_container.dart';

class ProvaScreen extends StatefulWidget {
  const ProvaScreen({super.key});

  @override
  State<ProvaScreen> createState() => _ProvaScreenState();
}

class _ProvaScreenState extends State<ProvaScreen> {
  ProvaProvider? _provaProvider;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provaProvider?.removeListener(_onStateChange);
    _provaProvider = context.read<ProvaProvider>();
    _provaProvider!.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _provaProvider?.removeListener(_onStateChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentBattuta();
    });
  }

  void _scrollToCurrentBattuta() {
    final prova = _provaProvider;
    if (prova == null) return;
    
    final currentIndex = prova.battutaCorrente;
    final key = _cardKeys[currentIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.3, // Position at 30% from top
      );
    }
  }

  GlobalKey _getKeyForIndex(int index) {
    return _cardKeys.putIfAbsent(index, () => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    final prova = context.watch<ProvaProvider>();
    final settings = context.watch<SettingsProvider>();
    final c = prova.copione;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (c == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: const Text('Copione non caricato'),
          ),
        ),
      );
    }

    final current = prova.battutaCorrente;
    final me = prova.personaggioSelezionato;
    final nextIn = prova.nextMyTurnIn();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: isDark 
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.6),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                c.titolo,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: _GlassListeningIndicator(active: prova.isListening),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Alert prossimo turno
            if (nextIn != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  borderColor: Colors.amber.withOpacity(0.5),
                  borderRadius: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.amber.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tra $nextIn ${nextIn == 1 ? "battuta" : "battute"} tocca a te!',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${current + 1} / ${c.battute.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (current + 1) / c.battute.length,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // SCROLLABLE LIST - tutte le battute
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: c.battute.length,
                itemBuilder: (_, index) {
                  final b = c.battute[index];
                  final isCurrent = index == current;
                  final isUserCharacter = me != null && b.personaggio == me;
                  
                  return _BattutaCard(
                    key: _getKeyForIndex(index),
                    personaggio: b.personaggio,
                    testo: b.testo,
                    index: index + 1,
                    isCurrent: isCurrent,
                    isUserCharacter: isUserCharacter,
                    isDark: isDark,
                    fontSize: settings.fontSizeForScript(),
                    onTap: () => prova.jumpTo(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      
      // Bottom controls
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.7),
              border: Border(
                top: BorderSide(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                _GlassControlButton(
                  icon: Icons.skip_previous,
                  onPressed: () => prova.jumpTo(0),
                ),
                const SizedBox(width: 8),
                _GlassControlButton(
                  icon: Icons.fast_rewind,
                  onPressed: () => prova.jumpTo((current - 1).clamp(0, c.battute.length - 1)),
                ),
                const Spacer(),
                
                // Main mic button
                GestureDetector(
                  onTap: prova.isListening ? prova.stop : prova.start,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: prova.isListening
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (prova.isListening ? Colors.red : Theme.of(context).colorScheme.primary)
                              .withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      prova.isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                
                const Spacer(),
                _GlassControlButton(
                  icon: Icons.fast_forward,
                  onPressed: () => prova.jumpTo((current + 1).clamp(0, c.battute.length - 1)),
                ),
                const SizedBox(width: 8),
                _GlassControlButton(
                  icon: Icons.skip_next,
                  onPressed: () => prova.jumpTo(c.battute.length - 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Battuta card - full content visible
class _BattutaCard extends StatelessWidget {
  final String personaggio;
  final String testo;
  final int index;
  final bool isCurrent;
  final bool isUserCharacter;
  final bool isDark;
  final double fontSize;
  final VoidCallback onTap;

  const _BattutaCard({
    super.key,
    required this.personaggio,
    required this.testo,
    required this.index,
    required this.isCurrent,
    required this.isUserCharacter,
    required this.isDark,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colors based on state
    final userColor = const Color(0xFFFFD600); // Bright yellow
    final userOrangeColor = Colors.orange;
    
    // Determine card style
    Color? bgColor;
    Color borderColor;
    double borderWidth;
    List<BoxShadow>? shadows;
    
    if (isCurrent && isUserCharacter) {
      // CURRENT + USER = BRIGHT YELLOW with mega glow
      bgColor = userColor.withOpacity(0.5);
      borderColor = userColor;
      borderWidth = 4;
      shadows = [
        BoxShadow(color: userColor.withOpacity(0.7), blurRadius: 30, spreadRadius: 8),
        BoxShadow(color: userColor.withOpacity(0.4), blurRadius: 50, spreadRadius: 15),
      ];
    } else if (isCurrent) {
      // CURRENT (not user) = primary color highlight
      bgColor = Theme.of(context).colorScheme.primary.withOpacity(0.2);
      borderColor = Theme.of(context).colorScheme.primary;
      borderWidth = 3;
      shadows = [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          blurRadius: 20,
          spreadRadius: 4,
        ),
      ];
    } else if (isUserCharacter) {
      // USER (not current) = orange highlight
      bgColor = userOrangeColor.withOpacity(isDark ? 0.2 : 0.15);
      borderColor = userOrangeColor.withOpacity(0.6);
      borderWidth = 2;
      shadows = [
        BoxShadow(color: userOrangeColor.withOpacity(0.3), blurRadius: 10),
      ];
    } else {
      // Normal card
      bgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5);
      borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
      borderWidth = 1;
      shadows = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: isCurrent ? 16 : 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCurrent ? 20 : 16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(isCurrent ? 20 : 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(isCurrent ? 20 : 16),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Character badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCurrent ? 14 : 10,
                          vertical: isCurrent ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: (isCurrent && isUserCharacter)
                              ? const LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFFFC107)])
                              : isUserCharacter
                                  ? LinearGradient(colors: [Colors.orange, Colors.amber.shade600])
                                  : isCurrent
                                      ? LinearGradient(colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.secondary,
                                        ])
                                      : null,
                          color: (!isCurrent && !isUserCharacter)
                              ? (isDark ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.2))
                              : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUserCharacter) ...[
                              Icon(
                                Icons.star,
                                size: isCurrent ? 16 : 12,
                                color: (isCurrent && isUserCharacter) ? Colors.black87 : Colors.white,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              personaggio,
                              style: TextStyle(
                                fontSize: isCurrent ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                color: (isCurrent && isUserCharacter)
                                    ? Colors.black87
                                    : (isCurrent || isUserCharacter)
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // User badge
                      if (isUserCharacter)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isCurrent && isUserCharacter)
                                ? Colors.black87
                                : userOrangeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCurrent ? '🎭 TU' : 'TU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (isCurrent && isUserCharacter)
                                  ? userColor
                                  : Colors.white,
                            ),
                          ),
                        ),
                      
                      // Index badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? (isUserCharacter ? Colors.black87 : Theme.of(context).colorScheme.primary)
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$index',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // "YOUR TURN" banner
                  if (isCurrent && isUserCharacter) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, color: Color(0xFFFFD600), size: 22),
                          SizedBox(width: 10),
                          Text(
                            '🎭 TOCCA A TE! 🎭',
                            style: TextStyle(
                              color: Color(0xFFFFD600),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: isCurrent ? 14 : 10),
                  
                  // Full text - NO truncation
                  Text(
                    testo,
                    style: TextStyle(
                      fontSize: isCurrent ? fontSize + 2 : fontSize,
                      height: 1.5,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      color: (isCurrent && isUserCharacter)
                          ? Colors.black87
                          : isUserCharacter
                              ? (isDark ? Colors.orange.shade200 : Colors.orange.shade900)
                              : isCurrent
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassListeningIndicator extends StatelessWidget {
  final bool active;

  const _GlassListeningIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active 
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active 
              ? Colors.green.withOpacity(0.5)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.green : Colors.grey,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'LIVE' : 'OFF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
