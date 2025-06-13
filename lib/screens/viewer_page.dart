import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 1枚のアセット画像をシンプルに表示するためのページ。
/// (viewer_screen.dart の方が高機能なため、こちらは現在使用されていない可能性があります)
class ViewerPage extends StatelessWidget {
  final AssetEntity asset;
  const ViewerPage({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(), // シンプルなAppBar
      body: FutureBuilder<Uint8List?>(
        // asset.originBytesは、アセットのオリジナル画質データをUint8List(バイト配列)として非同期に取得する。
        future: asset.originBytes,
        builder: (ctx, snap) {
          // データの取得が完了していない、またはデータがnullの場合はローディングインジケーターを表示
          if (snap.connectionState != ConnectionState.done || snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          // 取得した画像データをImage.memoryウィジェットで表示
          return Center(
            child: Image.memory(
              snap.data!,
              fit: BoxFit.contain, // アスペクト比を維持して画面に収める
            ),
          );
        },
      ),
    );
  }
}
