import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/gallery_provider.dart';
import '../widgets/asset_grid_item.dart';
import 'viewer_page.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ScrollController _controller = ScrollController();
  bool _didJumpToBottom = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  int _jumpTries = 0;
  int _bottomNavIndex = 0; // ボトムナビゲーションの現在のインデックス

  // 初期化処理（変更なし）
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GalleryProvider>();
      gp.init();

      gp.addListener(() {
        if (mounted && !gp.loading && !_didJumpToBottom && gp.assets.isNotEmpty) {
          _jumpTries = 0;
          Future.delayed(const Duration(milliseconds: 200), _tryJumpToBottom);
          _didJumpToBottom = true;
        }
      });
    });
  }

  @override
  void dispose() {
    context.read<GalleryProvider>().removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  void _tryJumpToBottom() {
    if (_controller.hasClients && _controller.position.hasContentDimensions) {
      _controller.jumpTo(_controller.position.maxScrollExtent);
    } else if (_jumpTries < 5) {
      _jumpTries++;
      Future.delayed(const Duration(milliseconds: 200), _tryJumpToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    // テーマに合わせてバーの背景色を半透明にする
    final barBackgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100.withOpacity(0.8)
        : Colors.black.withOpacity(0.7);

    return Scaffold(
      // ★変更点1: ボトムバーを選択モードに応じて切り替え
      bottomNavigationBar: _selectMode
          ? _buildSelectModeBottomBar(context)
          : _buildNormalModeBottomBar(),
      body: Consumer<GalleryProvider>(
        builder: (context, gp, child) {
          if (gp.noAccess) {
            return Center(child: TextButton(onPressed: gp.openSetting, child: const Text('写真へのアクセスを許可')));
          }
          if (gp.loading && gp.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // ★変更点2: BodyをCustomScrollViewに変更し、SliverAppBarとSliverGridを配置
          return CustomScrollView(
            controller: _controller,
            slivers: [
              SliverAppBar(
                title: Text(_selectMode ? 'Select Items' : 'All Photos'),
                centerTitle: true,
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: barBackgroundColor,
                actions: [
                  TextButton(
                    onPressed: _toggleSelectMode,
                    child: Text(_selectMode ? 'Cancel' : 'Select'),
                  ),
                ],
              ),
              // ★変更点3: GridViewをSliverGridに変更し、上下左右に1pxの余白を追加
              SliverPadding(
                padding: const EdgeInsets.all(1.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      gp.loadMoreIfNeeded(index);
                      final asset = gp.assets[index];
                      final isSelected = _selectedIds.contains(asset.id);
                      return AssetGridItem(
                        asset: asset,
                        isSelected: isSelected,
                        onTap: () => _onItemTap(asset, isSelected),
                        onLongPress: () => _onItemLongPress(asset),
                      );
                    },
                    childCount: gp.assets.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 通常時のボトムタブバー
  Widget _buildNormalModeBottomBar() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) => setState(() => _bottomNavIndex = index),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'All Photos'),
        BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'For You'),
        BottomNavigationBarItem(icon: Icon(Icons.collections_outlined), label: 'Albums'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
      ],
    );
  }

  // 選択モード時のボトムバー
  Widget _buildSelectModeBottomBar(BuildContext context) {
    return BottomAppBar(
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _selectedIds.isNotEmpty ? _onShare : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _selectedIds.isNotEmpty ? _onDelete : null,
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTap(AssetEntity asset, bool isSelected) {
    if (_selectMode) {
      setState(() {
        if (isSelected) {
          _selectedIds.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ViewerPage(asset: asset)),
      );
    }
  }

  void _onItemLongPress(AssetEntity asset) {
    if (!_selectMode) {
      setState(() {
        _selectMode = true;
        _selectedIds.add(asset.id);
      });
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _onDelete() async {
    if (_selectedIds.isEmpty) return;
    await PhotoManager.editor.deleteWithIds(_selectedIds.toList());
    await context.read<GalleryProvider>().refresh();
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _didJumpToBottom = false;
    });
  }

  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return;
    final assets = context.read<GalleryProvider>().assets.where((a) => _selectedIds.contains(a.id));
    final files = await Future.wait(assets.map((a) => a.file));
    final paths = files.where((f) => f != null).map((f) => f!.path).toList();
    if (paths.isNotEmpty) {
      await Share.shareXFiles(paths.map((path) => XFile(path)).toList());
    }
  }
}