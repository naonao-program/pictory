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
  bool _showUI = true;

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
      if (widget.assets.length <= 1) {
        Navigator.of(context).pop();
      } else {
        final newIndex = (_currentIndex > 0 ? _currentIndex - 1 : 0);
        // PageView.builderのitemBuilderが再構築されるようにsetStateを呼び出す
        setState(() {
           widget.assets.removeAt(_currentIndex);
          _currentIndex = newIndex;
        });
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
          PageView.builder(
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              // 以前のGestureDetectorを削除し、
              // 代わりに onToggleUI コールバックを渡します。
              if (asset.type == AssetType.video) {
                return VideoViewerView(
                  asset: asset,
                  onToggleUI: _toggleUI, // コールバックを渡す
                );
              } else {
                return PhotoViewerView(
                  asset: asset,
                  onToggleUI: _toggleUI, // コールバックを渡す
                );
              }
            },
          ),
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
        ],
      ),
    );
  }
}
