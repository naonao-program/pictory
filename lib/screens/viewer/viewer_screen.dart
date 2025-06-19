import 'package:flutter/gestures.dart';
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

/// 写真や動画を全画面表示するためのメインスクリーン。
class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets; // 表示するアセットのリスト
  final int initialIndex;        // 最初に表示するアセットのインデックス

  const ViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  /// ページのスワイプを管理するコントローラー。
  late final PageController _pageController;
  
  /// 現在表示されているアセットのインデックス。
  late int _currentIndex;
  
  /// AppBarやBottomBarなどのUIを表示するかどうかのフラグ。
  bool _showUI = true;

  /// 動画再生を管理するコントローラー。
  VideoPlayerController? _videoController;
  
  /// 動画コントローラーの初期化状態を管理するFuture。
  Future<void>? _initializeVideoPlayerFuture;
  
  /// 素早いスワイプによる動画初期化処理の競合を防ぐためのセッションID。
  /// ページが切り替わるたびにインクリメントされます。
  int _videoSession = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // 最初に表示するページのアセット（特に動画）の初期化を開始
    _initializeControllerForPage(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose(); // 画面が破棄されるときに動画コントローラーも破棄
    super.dispose();
  }
  
  /// 指定されたページの動画コントローラーを初期化するメソッド。
  /// ページが切り替わるたびに呼び出されます。
  Future<void> _initializeControllerForPage(int index) async {
    // 新しい初期化リクエストが来たので、セッションIDをインクリメント
    _videoSession++;
    final int currentSession = _videoSession;

    // 前のページの動画コントローラーがあれば破棄
    await _videoController?.dispose();

    // 破棄を待っている間に、さらに新しいリクエストが来ていたら（ユーザーが素早くスワイプしたら）、この処理は中断
    if (currentSession != _videoSession || !mounted) return;

    // 新しいページの状態を一旦リセット（サムネイル表示に戻す）
    _videoController = null;
    _initializeVideoPlayerFuture = null;
    if (mounted) setState(() {});

    if (index < 0 || index >= widget.assets.length) return;

    final asset = widget.assets[index];
    // 表示するアセットが動画でなければ、ここで処理を終了
    if (asset.type != AssetType.video) {
      return;
    }

    // 動画ファイルを取得
    final file = await asset.file;

    // ファイル取得を待つ間に新しいリクエストが来ていたら中断
    if (currentSession != _videoSession || !mounted || file == null) return;
    
    // 新しい動画コントローラーを生成し、初期化を開始
    final newController = VideoPlayerController.file(file);
    _videoController = newController;
    _initializeVideoPlayerFuture = newController.initialize();
    
    // 初期化が完了したら再生を開始するが、その時点でもセッションが有効か再度確認
    _initializeVideoPlayerFuture?.then((_) {
        if (mounted && _videoController == newController) {
            _videoController?.play();
            _videoController?.setLooping(true); // ループ再生を有効に
        }
    });

    // UIを更新して、新しいコントローラーとFutureをVideoViewerViewに渡す
    if (mounted) setState(() {});
  }

  /// 現在表示中のアセットを取得するゲッター。
  AssetEntity get currentAsset => widget.assets[_currentIndex];

  /// UI（AppBar, BottomBar）の表示・非表示を切り替える。
  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  /// PageViewでページが切り替わったときに呼び出される。
  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
    // 新しいページのためのコントローラー初期化処理を開始
    _initializeControllerForPage(index);
  }

  /// 削除ボタンが押されたときの処理。
  void _onDelete() async {
    // 確認ダイアログを表示
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
      
      // 削除操作の前に、進行中の動画関連処理をすべて停止・破棄する
      _videoSession++; 
      await _videoController?.dispose();
      _videoController = null;
      _initializeVideoPlayerFuture = null;

      // PhotoManager経由でアセットを削除
      await PhotoManager.editor.deleteWithIds([idToDelete]);
      // GalleryProviderにデータの更新を通知
      await context.read<GalleryProvider>().refresh();
      
      // ビューワー画面を閉じる
      Navigator.of(context).pop();
    }
  }

  /// 情報シートを表示するためのヘルパーメソッド
  void _showInfoSheet() {
    // アセットが動画の場合のみ、videoControllerを渡す
    InfoSheet.show(
      context, 
      currentAsset, 
      videoController: currentAsset.type == AssetType.video ? _videoController : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          // PageViewの水平スクロールと共存させるため、垂直方向のドラッグのみをリッスンする
          VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(),
            (VerticalDragGestureRecognizer instance) {
              instance.onEnd = (details) {
                // 上方向へのスワイプ（負の速度）を検知した場合に情報シートを表示
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                  _showInfoSheet();
                }
              };
            },
          ),
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.assets.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final asset = widget.assets[index];
                
                if (asset.type == AssetType.video) {
                  // --- 動画アセットの場合 ---
                  if (index == _currentIndex && _videoController != null && _initializeVideoPlayerFuture != null) {
                    return VideoViewerView(
                      key: ValueKey(asset.id),
                      onToggleUI: _toggleUI,
                      controller: _videoController!,
                      initializeFuture: _initializeVideoPlayerFuture!,
                    );
                  } else {
                    // 動画の読み込み中はサムネイルを表示
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
                  // --- 写真アセットの場合 ---
                  return PhotoViewerView(
                    asset: asset,
                    onToggleUI: _toggleUI,
                  );
                }
              },
            ),
            // リストの範囲外のインデックスを参照しないようにチェック
            if (_currentIndex < widget.assets.length) ...[
              // --- 上下のUIバー ---
              ViewerAppBar(
                show: _showUI,
                asset: currentAsset,
                onBackPressed: () => Navigator.of(context).pop(),
              ),
              ViewerBottomBar(
                show: _showUI,
                asset: currentAsset,
                onDelete: _onDelete,
                onShowInfo: _showInfoSheet,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
