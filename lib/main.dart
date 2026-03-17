import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/copioni_provider.dart';
import 'providers/prova_provider.dart';
import 'providers/settings_provider.dart';

import 'services/matching_service.dart';
import 'services/parser_service.dart';
import 'services/smart_parser_service.dart';
import 'services/storage_service.dart';
// Removed speech service - manual control only

import 'screens/home_screen.dart';
import 'sample_data/sample_scripts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final parser = ParserService();
  final smartParser = SmartParserService();
  await _seedSampleScriptsIfEmpty(storage, smartParser);

  final matching = MatchingService(baseThreshold: 0.6, windowSize: 10);
  final settings = SettingsProvider();
  await settings.load();

  runApp(MyApp(
    storage: storage,
    parser: parser,
    matching: matching,
    settings: settings,
  ));
}

Future<void> _seedSampleScriptsIfEmpty(StorageService storage, SmartParserService parser) async {
  final existing = storage.listCopioni();
  if (existing.isNotEmpty) return;
  
  final missionePossibile = parser.parseFromText(
    id: 'sample_missione_possibile',
    titolo: 'Missione Possibile',
    raw: sampleMissionePossibile,
  );
  await storage.saveCopione(missionePossibile);
  
  final romeoGiulietta = parser.parseFromText(
    id: 'sample_romeo_giulietta',
    titolo: 'Romeo e Giulietta (Esempio)',
    raw: sampleRomeoGiulietta,
  );
  await storage.saveCopione(romeoGiulietta);
}

// JETT AGENCY Design System
class JettAgencyTheme {
  // Light theme - Professional Agency
  static const lightPrimary = Color(0xFF21808D);     // --color-primary
  static const lightSecondary = Color(0xFF5E5240);   // Secondary brown
  static const lightBackground = Color(0xFFFCFCF9);  // --color-background
  static const lightSurface = Color(0xFFFFFFFF);     // --color-surface
  static const lightTextPrimary = Color(0xFF13343B); // --color-text
  static const lightTextSecondary = Color(0xFF626C71); // --color-text-secondary
  static const lightBorder = Color(0xFF5E5240);      // --color-border opacity
  
  // Dark theme - Professional Dark
  static const darkPrimary = Color(0xFF32B8C6);      // --color-primary dark
  static const darkSecondary = Color(0xFF777C7C);    // Secondary gray
  static const darkBackground = Color(0xFF1F2121);   // --color-background dark
  static const darkSurface = Color(0xFF262828);      // --color-surface dark
  static const darkTextPrimary = Color(0xFFF5F5F5);  // --color-text dark
  static const darkTextSecondary = Color(0xFFA7A9A9); // --color-text-secondary dark
  static const darkBorder = Color(0xFF777C7C);       // --color-border dark

  // Light gradient - Agency cream
  static const lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFCFCF9),  // Background
      Color(0xFFFFFFFD),  // Surface light
      Color(0xFFFAF7F0),  // Subtle variation
    ],
  );

  // Dark gradient - Agency dark
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1F2121),  // Background
      Color(0xFF262828),  // Surface
      Color(0xFF1A1A1A),  // Variation
    ],
  );

  static ThemeData lightTheme(TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        background: lightBackground,
        primaryContainer: lightPrimary.withOpacity(0.1),
        secondaryContainer: lightSecondary.withOpacity(0.12),
        tertiary: lightBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
        ),
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 0,
        shadowColor: lightBorder.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: lightBorder.withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
      ),
    );
  }

  static ThemeData darkTheme(TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkSurface,
        background: darkBackground,
        primaryContainer: darkPrimary.withOpacity(0.15),
        secondaryContainer: darkSecondary.withOpacity(0.15),
        tertiary: darkBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
        ),
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: darkBorder.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorder.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorder.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final StorageService storage;
  final ParserService parser;
  final MatchingService matching;
  final SettingsProvider settings;

  const MyApp({
    super.key,
    required this.storage,
    required this.parser,
    required this.matching,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.inter();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<CopioniProvider>(
          create: (_) => CopioniProvider(storage: storage, parser: parser),
        ),
        ChangeNotifierProvider<ProvaProvider>(
          create: (ctx) => ProvaProvider(
            storage: storage,
            matching: matching,
            settings: ctx.read<SettingsProvider>(),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, s, __) {
          // JETT Agency typography - Professional system fonts
          final textTheme = GoogleFonts.interTextTheme().copyWith(
            // Headlines use system font with tight tracking
            headlineLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
            ),
            headlineMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
            ),
            headlineSmall: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
            ),
            // Body text optimized for readability
            bodyLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            bodyMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            bodySmall: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          );
          
          return MaterialApp(
            title: 'Script Follower',
            debugShowCheckedModeBanner: false,
            themeMode: s.themeMode,
            theme: JettAgencyTheme.lightTheme(textTheme),
            darkTheme: JettAgencyTheme.darkTheme(textTheme),
            builder: (context, child) {
              // Wrap entire app with gradient background
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  gradient: isDark 
                      ? JettAgencyTheme.darkGradient 
                      : JettAgencyTheme.lightGradient,
                ),
                child: child,
              );
            },
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
