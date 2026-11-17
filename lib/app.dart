import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/root.dart';

class SparkApp extends StatelessWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: buildSparkTheme(),
      darkTheme: buildSparkTheme(),
      themeMode: ThemeMode.dark, // Dark-mode-first product.
      home: const RootScreen(),
    );
  }
}
