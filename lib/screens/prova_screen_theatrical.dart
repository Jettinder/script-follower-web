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

class _ProvaScreenState extends State<ProvaScreen> with TickerProviderStateMixin {
  ProvaProvider? _provaProvider;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _progressColorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for auto mode
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provaProvider?.removeListener(_onStateChange);
    _provaProvider = context.read<ProvaProvider>();
    _provaProvider!.addListener(_onStateChange);
    
    // Setup progress color animation
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _progressColorAnimation = ColorTween(
      begin: isDark ? const Color(0xFFD4AF37) : const Color(0xFF2C3E50),
      end: isDark ? const Color(0xFFE5B841) : const Color(0xFFD4AF37),
    ).animate(_progressController);
  }

  @override
  void dispose() {
    _provaProvider?.removeListener(_onStateChange);
    _scrollController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentBattuta();
      _progressController.forward(from: 0);
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.25,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 64,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessun Copione Caricato',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final current = prova.battutaCorrente;
    final me = prova.personaggioSelezionato;
    final nextIn = prova.nextMyTurnIn();
    final progress = (current + 1) / c.battute.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.titolo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Battuta ${current + 1} di ${c.battute.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Auto mode indicator
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: prova.isAutoMode 
                            ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: prova.isAutoMode 
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            prova.isAutoMode ? Icons.play_circle : Icons.pause_circle,
                            size: 16,
                            color: prova.isAutoMode 
                                ? Theme.of(context).colorScheme.secondary 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            prova.isAutoMode ? 'AUTO' : 'MANUALE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: prova.isAutoMode 
                                  ? Theme.of(context).colorScheme.secondary 
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    builder: (context, child) => Transform.scale(
                      scale: prova.isAutoMode ? _pulseAnimation.value : 1.0,
                      child: child,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar with theatrical styling
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // Next turn alert
                  if (nextIn != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade600,
                            Colors.orange.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '🎭 Tra $nextIn ${nextIn == 1 ? "battuta" : "battute"} tocca a te!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressColorAnimation,
                    builder: (context, child) => Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(
                            _progressColorAnimation.value ?? Theme.of(context).colorScheme.secondary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // SCROLLABLE LIST
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: c.battute.length,
                itemBuilder: (_, index) {
                  final b = c.battute[index];
                  final isCurrent = index == current;
                  final isUserCharacter = me != null && b.personaggio == me;
                  
                  return _TheatricalBattutaCard(
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
      
      // Bottom controls - Theatrical design
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.6)
                  : Colors.white.withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main controls row
                Row(
                  children: [
                    // Previous button
                    _TheatricalButton(
                      icon: Icons.skip_previous,
                      label: 'Prec',
                      onPressed: current > 0 ? prova.previousBattuta : null,
                      color: Theme.of(context).colorScheme.secondary,
                      isDark: isDark,
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Jump to start
                    _TheatricalButton(
                      icon: Icons.first_page,
                      label: 'Inizio',
                      onPressed: () => prova.jumpTo(0),
                      color: Theme.of(context).colorScheme.primary,
                      isDark: isDark,
                      isSecondary: true,
                    ),
                    
                    const Spacer(),
                    
                    // Main play/pause button
                    GestureDetector(
                      onTap: prova.isAutoMode ? prova.stopAutoMode : prova.startAutoMode,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: prova.isAutoMode
                                ? [Colors.red.shade500, Colors.red.shade700]
                                : [
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (prova.isAutoMode ? Colors.red : Theme.of(context).colorScheme.secondary)
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          prova.isAutoMode ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Jump to end
                    _TheatricalButton(
                      icon: Icons.last_page,
                      label: 'Fine',
                      onPressed: () => prova.jumpTo(c.battute.length - 1),
                      color: Theme.of(context).colorScheme.primary,
                      isDark: isDark,
                      isSecondary: true,
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Next button
                    _TheatricalButton(
                      icon: Icons.skip_next,
                      label: 'Succ',
                      onPressed: current < c.battute.length - 1 ? prova.nextBattuta : null,
                      color: Theme.of(context).colorScheme.secondary,
                      isDark: isDark,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Quick jump row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickJumpButton(
                      label: '-10',
                      onPressed: () => prova.jumpTo((current - 10).clamp(0, c.battute.length - 1)),
                    ),
                    _QuickJumpButton(
                      label: '-5',
                      onPressed: () => prova.jumpTo((current - 5).clamp(0, c.battute.length - 1)),
                    ),
                    _QuickJumpButton(
                      label: '+5',
                      onPressed: () => prova.jumpTo((current + 5).clamp(0, c.battute.length - 1)),
                    ),
                    _QuickJumpButton(
                      label: '+10',
                      onPressed: () => prova.jumpTo((current + 10).clamp(0, c.battute.length - 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Theatrical styled battuta card
class _TheatricalBattutaCard extends StatelessWidget {
  final String personaggio;
  final String testo;
  final int index;
  final bool isCurrent;
  final bool isUserCharacter;
  final bool isDark;
  final double fontSize;
  final VoidCallback onTap;

  const _TheatricalBattutaCard({
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
    // Theatrical color scheme
    final goldColor = const Color(0xFFD4AF37);
    final navyColor = const Color(0xFF2C3E50);
    final creamColor = const Color(0xFFFAF7F0);
    
    // Determine styling
    Color? bgColor;
    Color borderColor;
    double borderWidth;
    List<BoxShadow>? shadows;
    
    if (isCurrent && isUserCharacter) {
      // CURRENT + USER = Golden spotlight
      bgColor = goldColor.withOpacity(isDark ? 0.3 : 0.15);
      borderColor = goldColor;
      borderWidth = 4;
      shadows = [
        BoxShadow(color: goldColor.withOpacity(0.6), blurRadius: 30, spreadRadius: 6),
        BoxShadow(color: goldColor.withOpacity(0.3), blurRadius: 50, spreadRadius: 12),
      ];
    } else if (isCurrent) {
      // CURRENT (not user) = Navy spotlight  
      bgColor = navyColor.withOpacity(isDark ? 0.4 : 0.1);
      borderColor = navyColor;
      borderWidth = 3;
      shadows = [
        BoxShadow(
          color: navyColor.withOpacity(0.4),
          blurRadius: 20,
          spreadRadius: 4,
        ),
      ];
    } else if (isUserCharacter) {
      // USER (not current) = Warm highlight
      bgColor = const Color(0xFF8B4513).withOpacity(isDark ? 0.2 : 0.1);
      borderColor = const Color(0xFF8B4513).withOpacity(0.6);
      borderWidth = 2;
      shadows = null;
    } else {
      // Normal card - Parchment style
      bgColor = isDark 
          ? Colors.white.withOpacity(0.05) 
          : creamColor.withOpacity(0.8);
      borderColor = isDark 
          ? Colors.white.withOpacity(0.1) 
          : Colors.brown.withOpacity(0.2);
      borderWidth = 1;
      shadows = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: EdgeInsets.only(bottom: isCurrent ? 20 : 12),
        child: Container(
          padding: EdgeInsets.all(isCurrent ? 24 : 18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(isCurrent ? 24 : 18),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with character name and badges
              Row(
                children: [
                  // Character badge - Theatrical style
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCurrent ? 16 : 12,
                      vertical: isCurrent ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: (isCurrent && isUserCharacter)
                          ? const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE5B841)])
                          : isUserCharacter
                              ? const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFFA0522D)])
                              : isCurrent
                                  ? LinearGradient(colors: [navyColor, navyColor.withOpacity(0.8)])
                                  : null,
                      color: (!isCurrent && !isUserCharacter)
                          ? (isDark ? Colors.white.withOpacity(0.1) : Colors.brown.withOpacity(0.1))
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUserCharacter) ...[
                          Icon(
                            Icons.person,
                            size: isCurrent ? 18 : 14,
                            color: (isCurrent && isUserCharacter) ? navyColor : Colors.white,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          personaggio,
                          style: TextStyle(
                            fontSize: isCurrent ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: (isCurrent && isUserCharacter)
                                ? navyColor
                                : (isCurrent || isUserCharacter)
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.brown.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Scene number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? goldColor.withOpacity(0.2)
                          : (isDark ? Colors.white.withOpacity(0.1) : Colors.brown.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sc. $index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? goldColor
                            : (isDark ? Colors.white54 : Colors.brown.shade600),
                      ),
                    ),
                  ),
                ],
              ),
              
              // "YOUR TURN" theatrical banner
              if (isCurrent && isUserCharacter) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [navyColor, navyColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: navyColor.withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories, color: goldColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '🎭 È IL TUO MOMENTO! 🎭',
                        style: TextStyle(
                          color: goldColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: isCurrent ? 18 : 14),
              
              // Script text - Enhanced typography
              Text(
                testo,
                style: TextStyle(
                  fontSize: isCurrent ? fontSize + 4 : fontSize,
                  height: 1.6,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: (isCurrent && isUserCharacter)
                      ? navyColor
                      : isUserCharacter
                          ? (isDark ? const Color(0xFFA0522D) : const Color(0xFF8B4513))
                          : isCurrent
                              ? (isDark ? creamColor : navyColor)
                              : (isDark ? Colors.white.withOpacity(0.85) : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Theatrical control button
class _TheatricalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isDark;
  final bool isSecondary;

  const _TheatricalButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
    required this.isDark,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled 
              ? (isSecondary 
                  ? color.withOpacity(0.1)
                  : color.withOpacity(0.15))
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled 
                ? (isSecondary ? color.withOpacity(0.4) : color)
                : Colors.grey.withOpacity(0.3),
            width: isSecondary ? 1 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: enabled ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Quick jump button
class _QuickJumpButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickJumpButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}