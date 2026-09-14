import 'package:flutter/material.dart';
import 'package:pulseble/pages/homePage.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      routes: {
        '/': (context) => const HomePage(),
      }, initialRoute: '/',
    );
  }
}
