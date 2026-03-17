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
  
  late AnimationController _progressController;
  late Animation<Color?> _progressColorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
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
      begin: Theme.of(context).colorScheme.primary,
      end: Theme.of(context).colorScheme.primary,
    ).animate(_progressController);
  }

  @override
  void dispose() {
    _provaProvider?.removeListener(_onStateChange);
    _scrollController.dispose();
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
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
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
        appBar: AppBar(
          title: const Text('Script Follower'),
          backgroundColor: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.8),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessun Copione Caricato',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seleziona un copione per iniziare la prova',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
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
                    : Colors.white.withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.tertiary.withOpacity(0.12),
                    width: 1,
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
                        fontSize: 16,
                        color: Theme.of(context).textTheme.headlineMedium?.color,
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Battuta ${current + 1} di ${c.battute.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Auto mode status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: prova.isAutoMode 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                          : Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: prova.isAutoMode 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.25)
                            : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prova.isAutoMode ? Icons.play_circle : Icons.pause_circle,
                          size: 14,
                          color: prova.isAutoMode 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prova.isAutoMode ? 'AUTO' : 'MANUALE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: prova.isAutoMode 
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress and alerts
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Next turn alert
                  if (nextIn != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA84F2F).withOpacity(0.15), // warning color
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFA84F2F).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: const Color(0xFFA84F2F),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tra $nextIn ${nextIn == 1 ? "battuta" : "battute"} tocca a te',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Color(0xFFA84F2F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Progress bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
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
            
            // SCROLLABLE LIST
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: c.battute.length,
                itemBuilder: (_, index) {
                  final b = c.battute[index];
                  final isCurrent = index == current;
                  final isUserCharacter = me != null && b.personaggio == me;
                  
                  return _AgencyBattutaCard(
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
      
      // Bottom controls - Agency design
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.tertiary.withOpacity(0.12),
                  width: 1,
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
                    _AgencyButton(
                      icon: Icons.skip_previous,
                      label: 'Prec',
                      onPressed: current > 0 ? prova.previousBattuta : null,
                      isDark: isDark,
                      isSecondary: true,
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Jump to start
                    _AgencyButton(
                      icon: Icons.first_page,
                      label: 'Inizio',
                      onPressed: () => prova.jumpTo(0),
                      isDark: isDark,
                      isSecondary: true,
                    ),
                    
                    const Spacer(),
                    
                    // Main play/pause button
                    GestureDetector(
                      onTap: prova.isAutoMode ? prova.stopAutoMode : prova.startAutoMode,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: prova.isAutoMode 
                              ? const Color(0xFFC0152F) // error color for stop
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (prova.isAutoMode 
                                  ? const Color(0xFFC0152F) 
                                  : Theme.of(context).colorScheme.primary)
                                  .withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          prova.isAutoMode ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Jump to end
                    _AgencyButton(
                      icon: Icons.last_page,
                      label: 'Fine',
                      onPressed: () => prova.jumpTo(c.battute.length - 1),
                      isDark: isDark,
                      isSecondary: true,
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Next button
                    _AgencyButton(
                      icon: Icons.skip_next,
                      label: 'Succ',
                      onPressed: current < c.battute.length - 1 ? prova.nextBattuta : null,
                      isDark: isDark,
                      isSecondary: true,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
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

// Agency styled battuta card
class _AgencyBattutaCard extends StatelessWidget {
  final String personaggio;
  final String testo;
  final int index;
  final bool isCurrent;
  final bool isUserCharacter;
  final bool isDark;
  final double fontSize;
  final VoidCallback onTap;

  const _AgencyBattutaCard({
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
    // Agency color scheme
    final primaryColor = Theme.of(context).colorScheme.primary;
    final successColor = const Color(0xFF21808D); // Agency success color
    final warningColor = const Color(0xFFA84F2F); // Agency warning color
    
    // Determine styling
    Color? bgColor;
    Color borderColor;
    double borderWidth;
    List<BoxShadow>? shadows;
    
    if (isCurrent && isUserCharacter) {
      // CURRENT + USER = Primary spotlight
      bgColor = primaryColor.withOpacity(0.08);
      borderColor = primaryColor;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: primaryColor.withOpacity(0.15),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];
    } else if (isCurrent) {
      // CURRENT (not user) = Subtle highlight  
      bgColor = successColor.withOpacity(0.06);
      borderColor = successColor.withOpacity(0.25);
      borderWidth = 1;
      shadows = null;
    } else if (isUserCharacter) {
      // USER (not current) = Warning highlight
      bgColor = warningColor.withOpacity(0.05);
      borderColor = warningColor.withOpacity(0.2);
      borderWidth = 1;
      shadows = null;
    } else {
      // Normal card
      bgColor = Theme.of(context).colorScheme.surface;
      borderColor = Theme.of(context).colorScheme.tertiary.withOpacity(0.12);
      borderWidth = 1;
      shadows = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: isCurrent ? 16 : 10),
        child: Container(
          padding: EdgeInsets.all(isCurrent ? 20 : 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with character name and badges
              Row(
                children: [
                  // Character badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUserCharacter
                          ? warningColor.withOpacity(0.15)
                          : isCurrent
                              ? primaryColor.withOpacity(0.15)
                              : Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUserCharacter) ...[
                          Icon(
                            Icons.person,
                            size: 12,
                            color: warningColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          personaggio,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUserCharacter
                                ? warningColor
                                : isCurrent
                                    ? primaryColor
                                    : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Scene number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              // "YOUR TURN" alert
              if (isCurrent && isUserCharacter) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.record_voice_over, color: primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'È il tuo turno',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: isCurrent ? 16 : 12),
              
              // Script text - Clean typography
              Text(
                testo,
                style: TextStyle(
                  fontSize: isCurrent ? fontSize + 2 : fontSize,
                  height: 1.5,
                  fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                  color: isUserCharacter
                      ? warningColor.withOpacity(0.9)
                      : isCurrent
                          ? primaryColor.withOpacity(0.95)
                          : Theme.of(context).textTheme.bodyLarge?.color,
                  letterSpacing: -0.01,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Agency button component
class _AgencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDark;
  final bool isSecondary;

  const _AgencyButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.isDark,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled 
              ? Theme.of(context).colorScheme.secondary.withOpacity(0.12)
              : Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled 
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled 
                  ? Theme.of(context).colorScheme.secondary 
                  : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: enabled 
                    ? Theme.of(context).colorScheme.secondary 
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}