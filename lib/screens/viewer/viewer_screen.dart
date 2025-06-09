import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

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
  bool _showUI = true; // UI(バーなど)の表示/非表示を管理

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 現在表示中のアセット
  AssetEntity get currentAsset => widget.assets[_currentIndex];

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
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
      await PhotoManager.editor.deleteWithIds([currentAsset.id]);
      await context.read<GalleryProvider>().refresh();
      // 1件しか無かった場合は前の画面に戻る
      if (widget.assets.length <= 1) {
        Navigator.of(context).pop();
      } else {
        // 削除後の画面遷移処理
        final newIndex = (_currentIndex - 1).clamp(0, widget.assets.length - 2);
        setState(() {
          // 削除されたので、現在のリストから該当アセットを削除
          widget.assets.removeAt(_currentIndex);
          // 新しいインデックスに更新
          _currentIndex = newIndex;
        });
        // 前のページにアニメーションなしで遷移
        _pageController.jumpToPage(newIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景のページビュー（写真/動画をスワイプで切り替え）
          PageView.builder(
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              // タップでUI表示/非表示を切り替えるためのラッパー
              return GestureDetector(
                onTap: _toggleUI,
                child: asset.type == AssetType.video
                    ? VideoViewerView(asset: asset)
                    : PhotoViewerView(asset: asset),
              );
            },
          ),
          
          // 上部バー
          ViewerAppBar(
            show: _showUI,
            asset: currentAsset,
            onBackPressed: () => Navigator.of(context).pop(),
          ),

          // 下部バー
          ViewerBottomBar(
            show: _showUI,
            asset: currentAsset,
            onDelete: _onDelete,
            onShowInfo: () => InfoSheet.show(context, currentAsset),
          ),
        ],
      ),
    );
  }
}