import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

/// ViewerScreenの下部に表示されるアクションバーウィジェット。
class ViewerBottomBar extends StatelessWidget {
  /// このバーを表示するかどうか。
  final bool show;
  /// 表示対象のアセット。
  final AssetEntity asset;
  /// 削除ボタンが押されたときのコールバック。
  final VoidCallback onDelete;
  /// 情報ボタンが押されたときのコールバック。
  final VoidCallback onShowInfo;

  const ViewerBottomBar({
    super.key,
    required this.show,
    required this.asset,
    required this.onDelete,
    required this.onShowInfo,
  });
  
  /// 共有ボタンが押されたときの処理。
  Future<void> _onShare() async {
    // アセットからFileオブジェクトを取得
    final file = await asset.file;
    if (file == null) return;
    // share_plusパッケージを使って、OSの共有ダイアログを呼び出す
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedPositionedを使って、表示/非表示をアニメーションさせる
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      // `show`フラグに応じて、画面の下端または画面外に配置する
      bottom: show ? 0 : -100,
      left: 0,
      right: 0,
      child: Container(
        // ナビゲーションバーなどシステムUIの領域を避けるためのpadding
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        color: Colors.black.withOpacity(0.4), // 半透明の黒
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // アイコンを等間隔に配置
          children: [
            // 共有ボタン
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: _onShare),
            // お気に入りボタン（現在の実装ではダミー）
            IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
            // 情報ボタン
            IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: onShowInfo),
            // 削除ボタン
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
