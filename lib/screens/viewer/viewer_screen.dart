import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/gallery_provider.dart';
import 'widgets/photo_viewer_view.dart';
import 'widgets/video_viewer_view.dart';
import 'widgets/viewer_app_bar.dart';
import 'widgets/viewer_bottom_bar.dart';
import 'widgets/info_sheet.dart';

class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const ViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  
  /// --- 追加: 初期化処理の競合を防ぐためのセッションID ---
  int _videoSession = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeControllerForPage(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  /// --- 修正: コントローラーの初期化処理をより安全な方法に変更 ---
  Future<void> _initializeControllerForPage(int index) async {
    // 新しい初期化リクエストが来たので、セッションIDを更新
    _videoSession++;
    final int currentSession = _videoSession;

    // 前のコントローラーを破棄
    await _videoController?.dispose();

    // 破棄を待っている間に、さらに新しいリクエストが来ていたら、この処理は中断
    if (currentSession != _videoSession || !mounted) return;

    // 新しいページの状態をリセット（一度サムネイル表示に戻す）
    _videoController = null;
    _initializeVideoPlayerFuture = null;
    if (mounted) setState(() {});

    if (index < 0 || index >= widget.assets.length) return;

    final asset = widget.assets[index];
    if (asset.type != AssetType.video) {
      return; // 動画でなければ何もしない
    }

    // 動画ファイルを取得
    final file = await asset.file;

    // ファイル取得を待つ間に新しいリクエストが来ていたら中断
    if (currentSession != _videoSession || !mounted || file == null) return;
    
    // 新しいコントローラーを生成して初期化を開始
    final newController = VideoPlayerController.file(file);
    _videoController = newController;
    _initializeVideoPlayerFuture = newController.initialize();
    
    // 初期化が終わったら再生を開始するが、その時点でもセッションが有効か確認
    _initializeVideoPlayerFuture?.then((_) {
        if (mounted && _videoController == newController) {
            _videoController?.play();
            _videoController?.setLooping(true);
        }
    });

    // UIを更新して、新しいコントローラーとFutureをウィジェットに渡す
    if (mounted) setState(() {});
  }

  AssetEntity get currentAsset => widget.assets[_currentIndex];

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
    _initializeControllerForPage(index);
  }

  void _onDelete() async {
    final bool didDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This item will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;

    if (didDelete && mounted) {
      final idToDelete = currentAsset.id;
      
      // 削除操作の前に、進行中のセッションを無効化し、コントローラーを破棄
      _videoSession++; 
      await _videoController?.dispose();
      _videoController = null;
      _initializeVideoPlayerFuture = null;

      await PhotoManager.editor.deleteWithIds([idToDelete]);
      await context.read<GalleryProvider>().refresh();
      
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              
              if (asset.type == AssetType.video) {
                if (index == _currentIndex && _videoController != null && _initializeVideoPlayerFuture != null) {
                  return VideoViewerView(
                    key: ValueKey(asset.id), // Keyを追加してウィジェットの再利用を正しく制御
                    onToggleUI: _toggleUI,
                    controller: _videoController!,
                    initializeFuture: _initializeVideoPlayerFuture!,
                  );
                } else {
                  return Center(
                    child: AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(500),
                      fit: BoxFit.contain,
                    ),
                  );
                }
              } else {
                return PhotoViewerView(
                  asset: asset,
                  onToggleUI: _toggleUI,
                );
              }
            },
          ),
          if (_currentIndex < widget.assets.length) ...[
            ViewerAppBar(
              show: _showUI,
              asset: currentAsset,
              onBackPressed: () => Navigator.of(context).pop(),
            ),
            ViewerBottomBar(
              show: _showUI,
              asset: currentAsset,
              onDelete: _onDelete,
              onShowInfo: () => InfoSheet.show(context, currentAsset),
            ),
          ]
        ],
      ),
    );
  }
}
