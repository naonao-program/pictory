import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:photo_manager/photo_manager.dart';

/// アセットの詳細情報を表示するためのボトムシートウィジェット。
class InfoSheet extends StatelessWidget {
  final AssetEntity asset;

  const InfoSheet({super.key, required this.asset});
  
  /// このボトムシートをモーダル表示するための静的メソッド。
  static void show(BuildContext context, AssetEntity asset) async {
    // 日本語の日付フォーマットを初期化
    await initializeDateFormatting('ja_JP');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // シートの高さをドラッグで変更可能にする
      backgroundColor: Colors.transparent, // 背景を透明にして、下のContainerの角丸を活かす
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4, // 初期表示時の高さ（画面の40%）
        minChildSize: 0.2,     // ドラッグで縮小できる最小の高さ
        maxChildSize: 0.8,     // ドラッグで拡大できる最大の高さ
        builder: (context, scrollController) {
          // シート本体のコンテナ
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF222222), // 背景色
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // 上部の角を丸める
            ),
            child: InfoSheet(asset: asset),
          );
        },
      ),
    );
  }

  /// アセットからファイルサイズを非同期で取得するヘルパー関数。
  Future<int?> _getFileSize(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;
    // Fileオブジェクトのlength()メソッドでサイズをバイト単位で取得
    return file.length();
  }

  @override
  Widget build(BuildContext context) {
    // 日付と時刻をフォーマット
    final date = asset.createDateTime;
    final formattedDate = DateFormat('y年M月d日 E曜日', 'ja_JP').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

    // FutureBuilderを使って非同期でファイルサイズを取得し、UIに反映させる
    return FutureBuilder<int?>(
      future: _getFileSize(asset),
      builder: (context, snapshot) {
        // ファイルサイズをバイトからメガバイト(MB)に変換
        final fileSizeMB = snapshot.hasData && snapshot.data != null && snapshot.data! > 0
            ? (snapshot.data! / (1024 * 1024)).toStringAsFixed(1)
            : 'N/A';

        // 情報リスト
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 上部のドラッグハンドル
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
            // 撮影日時
            Text('$formattedDate $formattedTime', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            // ファイル名 (タイトル)
            Text(asset.title ?? 'No Title', style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white24, height: 32),
            // 解像度
            _buildInfoRow('Resolution', '${asset.width} x ${asset.height}'),
            // ファイルサイズ
            _buildInfoRow('Size', '$fileSizeMB MB'),
          ],
        );
      },
    );
  }

  /// 「タイトル: 値」の形式の行を生成するヘルパーウィジェット。
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
