import 'package:flutter/material.dart';
import 'screens/home.dart';

void main() {
  runApp(const TripitakaApp());
}

class TripitakaApp extends StatelessWidget {
  const TripitakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tripitaka Indonesia',
      theme: ThemeData(
        // pakai hex langsung
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}
