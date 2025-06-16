import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/album_detail_provider.dart';
import '../viewer/viewer_screen.dart';

/// 特定のアルバムに含まれるアセット（写真・動画）の一覧を表示する画面
/// このウィジェットはProviderの生成に責任を持つ
class AlbumDetailScreen extends StatelessWidget {
  final AssetPathEntity album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    // AlbumDetailProviderを生成し、その子ウィジェットである_AlbumDetailViewに提供する
    return ChangeNotifierProvider(
      create: (context) => AlbumDetailProvider(album: album),
      child: const _AlbumDetailView(),
    );
  }
}

/// Providerを消費して実際のUIを描画する内部ウィジェット
class _AlbumDetailView extends StatefulWidget {
  const _AlbumDetailView();

  @override
  State<_AlbumDetailView> createState() => __AlbumDetailViewState();
}

class __AlbumDetailViewState extends State<_AlbumDetailView> {
  // 無限スクロールを実現するためのスクロールコントローラー
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // initStateの実行時点では、このウィジェットはまだビルドプロセスの最中です。
    // このタイミングでProviderの状態を変更してnotifyListeners()を呼び出すと、
    // "dirty" assertionエラーが発生します。
    // そのため、最初のフレームの描画が完了した直後に処理を実行するようスケジュールします。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // このコールバック内では、ウィジェットツリーが安定しているため安全にProviderを呼び出せます。
      final provider = context.read<AlbumDetailProvider>();

      // 最初のデータを読み込む
      provider.loadAssets();

      // スクロールコントローラーにリスナーを登録
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          provider.loadMoreAssets();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // watchを使ってProviderの状態変更を監視し、変更があればUIを再構築する
    final provider = context.watch<AlbumDetailProvider>();
    final assets = provider.assets;

    return Scaffold(
      appBar: AppBar(
        // Providerからアルバム名を取得して表示
        title: Text(provider.album.name),
      ),
      body: Builder(
        builder: (context) {
          // 初回読み込み中の場合
          if (assets.isEmpty && provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // アルバムが空の場合
          if (assets.isEmpty) {
            return const Center(child: Text('No photos or videos found.'));
          }
          
          // GridViewでアセットのサムネイルを一覧表示
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(2.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4列表示
              crossAxisSpacing: 2.0,
              mainAxisSpacing: 2.0,
            ),
            itemCount: assets.length + (provider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // リストの末尾で、まだ読み込めるデータがある場合はインジケータを表示
              if (index == assets.length) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ));
              }

              final asset = assets[index];
              return GestureDetector(
                onTap: () {
                  // タップされたアセットを全画面ビューワーで表示
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ViewerScreen(
                      assets: assets,
                      initialIndex: index,
                    ),
                  ));
                },
                child: Hero(
                  tag: asset.id, // スムーズな画面遷移アニメーションのためのHeroタグ
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // サムネイル画像
                      AssetEntityImage(
                        asset,
                        isOriginal: false,
                        // サムネイルの解像度を少し下げて、読み込みの負荷を軽減します。
                        thumbnailSize: const ThumbnailSize.square(200),
                        // --- 修正箇所ここまで ---
                        fit: BoxFit.cover,
                      ),
                      // アセットが動画の場合、左下にアイコンと再生時間を表示
                      if (asset.type == AssetType.video)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Row(
                            children: [
                              const Icon(Icons.videocam, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(asset.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  shadows: [Shadow(blurRadius: 1.0, color: Colors.black54)],
                                ),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 動画の再生時間（秒）を `mm:ss` 形式の文字列にフォーマットする
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString();
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}