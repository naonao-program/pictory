import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class AssetGridItem extends StatelessWidget {
  /// 表示する AssetEntity
  final AssetEntity asset;

  /// 選択済みかどうか
  final bool isSelected;

  /// タップ時のコールバック
  final VoidCallback onTap;

  /// 長押し時のコールバック（任意）
  final VoidCallback? onLongPress;

  const AssetGridItem({
    Key? key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  // 秒数を「M:SS」形式の文字列にフォーマットするヘルパー関数
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.toString();
    // 秒数が一桁の場合、先頭に '0' を付けて2桁にする (例: 7 -> "07")
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          // 1. サムネイル画像
          Positioned.fill(
            child: AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize(200, 200),
              fit: BoxFit.cover, // パツパツに表示
            ),
          ),
          // 2. 動画の場合のオーバーレイ表示
          if (asset.type == AssetType.video)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              // iOS風の黒いグラデーション
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Row(
                children: [
                  // Spacerを先頭に配置し、後続のウィジェットをすべて右端に寄せる
                  const Spacer(), 
                  // ビデオアイコン
                  const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  // フォーマットされた再生時間
                  Text(
                    _formatDuration(asset.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 3. 選択中のチェックマーク表示
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
