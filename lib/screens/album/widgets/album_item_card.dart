import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// GridViewに表示される各アルバムのカードウィジェット
class AlbumItemCard extends StatefulWidget {
  const AlbumItemCard({
    super.key,
    required this.album,
  });

  final AssetPathEntity album;

  @override
  State<AlbumItemCard> createState() => _AlbumItemCardState();
}

class _AlbumItemCardState extends State<AlbumItemCard> {
  // サムネイル画像のバイナリデータ
  Uint8List? _thumbnailData;

  // アルバム内のアセット数
  int _assetCount = 0;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  /// アルバムの先頭の画像のサムネイルを非同期で読み込む
  Future<void> _loadThumbnail() async {
    // アセット数を非同期で取得
    final assetCount = await widget.album.assetCountAsync;
    
    // アルバム内のアセットリストを1件だけ取得
    final assets = await widget.album.getAssetListRange(start: 0, end: 1);
    if (assets.isEmpty) return; // アセットがなければ何もしない

    // 取得したアセットのサムネイルデータを取得
    final thumbnailData = await assets.first.thumbnailDataWithSize(
      const ThumbnailSize(250, 250), // サムネイルの解像度を指定
    );

    // ウィジェットがまだ画面に存在すれば、状態を更新して再描画
    if (mounted) {
      setState(() {
        _thumbnailData = thumbnailData;
        _assetCount = assetCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: ここにアルバム詳細画面への遷移処理を実装します
        // Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: widget.album)));
        print('Tapped on album: ${widget.album.name}');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // サムネイル画像
            if (_thumbnailData != null)
              Image.memory(
                _thumbnailData!,
                fit: BoxFit.cover,
                gaplessPlayback: true, // 画像読み込み時のちらつきを防ぐ
              )
            else
              // 読み込み中またはサムネイルがない場合のプレースホルダー
              Container(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.photo_album_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            
            // 文字を見やすくするためのグラデーションオーバーレイ
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // アルバム名と写真枚数
            Positioned(
              bottom: 8.0,
              left: 8.0,
              right: 8.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.album.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 2.0, color: Colors.black54)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$_assetCount items',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 2.0, color: Colors.black54)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
