import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'calendar/calendar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  runApp(const Activity12App());
}

class Activity12App extends StatelessWidget {
  const Activity12App({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF315EDC);

    return MaterialApp(
      title: 'Actividad 12 - Equipo 6',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FC),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: CalendarPage(),
    );
  }
}
