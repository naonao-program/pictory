import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:photo_manager/photo_manager.dart';

class InfoSheet extends StatelessWidget {
  final AssetEntity asset;

  const InfoSheet({super.key, required this.asset});
  
  static void show(BuildContext context, AssetEntity asset) async {
    await initializeDateFormatting('ja_JP');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: InfoSheet(asset: asset),
          );
        },
      ),
    );
  }

  // ファイルサイズを非同期で取得するヘルパー関数
  Future<int?> _getFileSize(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;
    // Fileオブジェクトのlength()メソッドでサイズ(byte)を取得
    return file.length();
  }

  @override
  Widget build(BuildContext context) {
    final date = asset.createDateTime;
    final formattedDate = DateFormat('y年M月d日 E曜日', 'ja_JP').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

    return FutureBuilder<int?>(
      // <<< 修正: 正しいファイルサイズ取得関数を呼び出す
      future: _getFileSize(asset),
      builder: (context, snapshot) {
        final fileSizeMB = snapshot.hasData && snapshot.data != null && snapshot.data! > 0
            ? (snapshot.data! / (1024 * 1024)).toStringAsFixed(1)
            : 'N/A';

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('$formattedDate $formattedTime', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(asset.title ?? 'No Title', style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white24, height: 32),
            _buildInfoRow('Resolution', '${asset.width} x ${asset.height}'),
            _buildInfoRow('Size', '$fileSizeMB MB'),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}