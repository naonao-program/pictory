import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/album_detail_provider.dart';
import '../viewer/viewer_screen.dart';

/// 特定のアルバムに含まれるアセット（写真・動画）の一覧を表示する画面
class AlbumDetailScreen extends StatelessWidget {
  final AssetPathEntity album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
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
  State<_AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<_AlbumDetailView> {
  late final AlbumDetailProvider _provider;
  // 無限スクロールを実現するためのスクロールコントローラー
  final ScrollController _scrollController = ScrollController();
  // 読み込みが始まるscrollの位置
  static const double _loadMoreScrollOffset = 500.0;

  @override
  void initState() {
    super.initState();

    _provider = context.read<AlbumDetailProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initialize();
    });

    _scrollController.addListener(() {
      // スクロール位置が一番上(maxScrollExtent)に近づいたら、さらに古いデータを読み込む
      // reverse: true の場合、リストの見た目上の一番上がスクロールの終点になります。
      if (!_provider.loading &&
          _provider.hasMore &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - _loadMoreScrollOffset) {
        _provider.loadMoreAssets();
      }
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
    // MODIFIED: Providerから取得したリスト（新しい順）をそのまま使用します
    final assets = provider.assets;

    return Scaffold(
      appBar: AppBar(
        // Providerからアルバム名を取得して表示
        title: Text(provider.album.name),
      ),
      body: Builder(
        builder: (context) {
          if (!provider.isInitialized && provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // アルバムが空の場合
          if (assets.isEmpty) {
            return const Center(child: Text('No photos or videos found.'));
          }

          // MODIFIED: CustomScrollViewに `shrinkWrap: true` を追加します。
          // これにより、コンテンツの高さがスクロールビューの高さとなり、
          // 写真が少ない場合でも不要な余白が発生しなくなります。
          return CustomScrollView(
            shrinkWrap: true,
            reverse: true,
            controller: _scrollController,
            slivers: [
              // ローディングインジケーターをリストの末尾（見た目上は一番上）に配置
              if (provider.loading && provider.hasMore)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(2.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Providerからのリスト（新しい順）をそのまま使用します。
                      // reverse:true のおかげで、リストの0番目（最新）が一番下に表示されます。
                      final asset = assets[index];
                      return GestureDetector(
                        onTap: () {
                          // ViewerScreenにはそのままのリストとインデックスを渡す
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ViewerScreen(
                              assets: assets,
                              initialIndex: index,
                            ),
                          ));
                        },
                        child: Hero(
                          tag: asset.id,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AssetEntityImage(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(200),
                                fit: BoxFit.cover,
                              ),
                              if (asset.type == AssetType.video)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.videocam,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDuration(asset.duration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          shadows: [
                                            Shadow(
                                                blurRadius: 1.0,
                                                color: Colors.black54)
                                          ],
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
                    childCount: assets.length,
                  ),
                ),
              ),
            ],
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