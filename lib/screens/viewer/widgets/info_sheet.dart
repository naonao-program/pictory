import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

class InfoSheet extends StatelessWidget {
  final AssetEntity asset;

  const InfoSheet({super.key, required this.asset});
  
  // このシートを表示するための静的メソッド
  static void show(BuildContext context, AssetEntity asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 高さを自由に設定可能に
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4, // 初期の高さ
        minChildSize: 0.2,     // 最小の高さ
        maxChildSize: 0.8,     // 最大の高さ
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF222222), // ダークな背景色
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: InfoSheet(asset: asset),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = asset.createDateTime;
    final formattedDate = DateFormat('y年M月d日 E曜日', 'ja_JP').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

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
        _buildInfoRow('Size', '${(asset.size.width / 1000000).toStringAsFixed(1)} MB'),
        // ... 他のExif情報をここに追加 ...
      ],
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