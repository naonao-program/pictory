import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

/// ViewerScreenの上部に表示されるAppBarウィジェット。
class ViewerAppBar extends StatelessWidget {
  /// このAppBarを表示するかどうか。
  final bool show;
  /// 表示対象のアセット。
  final AssetEntity asset;
  /// 戻るボタンが押されたときのコールバック。
  final VoidCallback onBackPressed;
  
  const ViewerAppBar({
    super.key,
    required this.show,
    required this.asset,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    // アセットの作成日時をフォーマットする
    final date = asset.createDateTime;
    final formattedDate = DateFormat('M月d日').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

    // AnimatedPositionedを使って、表示/非表示をアニメーションさせる
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      // `show`フラグに応じて、画面の上端または画面外に配置する
      top: show ? 0 : -kToolbarHeight - MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        // ステータスバーの高さを考慮してpaddingを設定
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        color: Colors.black.withOpacity(0.4), // 半透明の黒
        child: Row(
          children: [
            // 戻るボタン
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: onBackPressed),
            const Spacer(),
            // 日付と時刻
            Column(
              children: [
                Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(formattedTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const Spacer(),
            // 編集ボタン（現在の実装ではダミー）
            TextButton(onPressed: () {}, child: const Text('編集', style: TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}
