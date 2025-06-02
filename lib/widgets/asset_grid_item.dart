import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart'; // ← 追加
import 'shimmer_placeholder.dart';

class AssetGridItem extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;      // ← 非 null
  final VoidCallback onTap;   // ← タップ時の挙動を呼び出し

  const AssetGridItem({
    Key? key,
    required this.asset,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // GalleryScreen で「選択モード or プレビュー」の処理を振り分ける
      child: Stack(
        children: [
          Hero(
            tag: 'asset_${asset.id}',
            child: Image(
              // キャッシュ付きサムネ取得
              image: AssetEntityImageProvider(
                asset,
                thumbnailSize: const ThumbnailSize(200, 200),
                isOriginal: false,
              ),
              fit: BoxFit.cover,
              frameBuilder: (ctx, child, frame, _) {
                if (frame == null) {
                  // 読み込み中は ShimmerPlaceholder
                  return const ShimmerPlaceholder();
                }
                return child;
              },
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.red),
            ),
          ),

          // 動画なら左下にアイコン＋時間
          if (asset.type == AssetType.video)
            Positioned(
              left: 4,
              bottom: 4,
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 14, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    _formatDuration(asset.videoDuration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          // 選択モード中かつ選択済みなら右上にチェック
          if (isSelected)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.check_circle, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
