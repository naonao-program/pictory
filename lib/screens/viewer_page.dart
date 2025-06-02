import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class ViewerPage extends StatelessWidget {
  final AssetEntity asset;
  const ViewerPage({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Uint8List?>(
        future: asset.originBytes, // 原寸画像データ
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done || snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Image.memory(
              snap.data!,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}