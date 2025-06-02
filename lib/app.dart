import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/gallery_provider.dart';
import 'screens/gallery_screen.dart';

class PictoryApp extends StatelessWidget {
  const PictoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
      ],
      child: MaterialApp(
        title: 'Pictory',
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const GalleryScreen(),
      ),
    );
  }
}
