import 'package:flutter/material.dart';
import 'package:pictory/providers/albums_provider.dart';
import 'package:provider/provider.dart';
import 'providers/gallery_provider.dart';
import 'screens/gallery/gallery_screen.dart';
import 'screens/main_screen.dart';

/// アプリケーションのルート（最上位）ウィジェットです。
class PictoryApp extends StatelessWidget {
  const PictoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    /// MultiProviderを使って、アプリ全体で利用するProviderを登録します。
    /// これにより、アプリ内のどのウィジェットからでもここで登録したProviderにアクセスできます。
    return MultiProvider(
      providers: [
        /// 「すべての写真」タブ用のProvider
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
        /// 「アルバム」タブ用のProvider
        ChangeNotifierProvider(create: (_) => AlbumsProvider()),
      ],
      child: MaterialApp(
        title: 'Pictory',
        // アプリのテーマ設定
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        // アプリの初期画面としてGalleryScreenを指定
        home: const MainScreen(),
      ),
    );
  }
}
