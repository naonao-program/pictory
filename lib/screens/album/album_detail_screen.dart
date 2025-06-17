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
  State<_AlbumDetailView> createState() => __AlbumDetailViewState();
}

class __AlbumDetailViewState extends State<_AlbumDetailView> {
  late final AlbumDetailProvider _provider;
  // 無限スクロールを実現するためのスクロールコントローラー
  final ScrollController _scrollController = ScrollController();
  bool _initialLayoutCompleted = false;
  bool _isLoadingMore = false;
  double _oldMaxScrollExtent = 0.0;

  @override
  void initState() {
    super.initState();

    // context.read は initState() で安全に呼べる
    _provider = context.read<AlbumDetailProvider>();
    _provider.addListener(_onProviderUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initialize();
    });

    _scrollController.addListener(() {
      if (_initialLayoutCompleted &&
          !_isLoadingMore &&
          _scrollController.position.extentBefore < 200.0) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    // context を使わず、フィールドから直接 removeListener
    _provider.removeListener(_onProviderUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_provider.loading || !_provider.hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _oldMaxScrollExtent = _scrollController.position.maxScrollExtent;
    });
    _provider.loadMoreAssets();
  }

  void _onProviderUpdate() {
    if (_provider.loading) return;

    if (_provider.isInitialized &&
        !_initialLayoutCompleted &&
        _provider.assets.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
          setState(() {
            _initialLayoutCompleted = true;
          });
        }
      });
    } else if (_isLoadingMore) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final newMax = _scrollController.position.maxScrollExtent;
          // 先頭に要素が追加された分だけスクロール位置を下にずらす
          _scrollController.jumpTo(
            _scrollController.offset + (newMax - _oldMaxScrollExtent),
          );
        }
      });
      setState(() => _isLoadingMore = false);
    }
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
          if (!provider.isInitialized && provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // アルバムが空の場合
          if (assets.isEmpty) {
            return const Center(child: Text('No photos or videos found.'));
          }
          
          // CustomScrollViewを使って、先頭にインジケーターを追加できるようにする
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // さらに読み込み中は、グリッドの先頭にインジケーターを表示
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                    child: SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator())
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
                      final asset = assets[index];
                      return GestureDetector(
                        onTap: () {
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