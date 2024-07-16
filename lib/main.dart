import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_app_screen.dart';

void main() {
  runApp(const ProviderScope(child: PrayersApp()));
}

class PrayersApp extends StatelessWidget {
  const PrayersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MainAppScreen(),
    );
  }
}
