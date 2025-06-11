import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/gallery_provider.dart';
import '../widgets/asset_grid_item.dart';
import 'viewer/viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  int _bottomNavIndex = 0;
  
  /// 初回レイアウトが完了したか
  bool _initialLayoutCompleted = false;

  /// 古い写真を追加読み込み中かを示すフラグ
  bool _isLoadingMore = false;
  /// 読み込み前のスクロール可能な最大範囲
  double _oldMaxScrollExtent = 0.0;
  /// 読み込みインジケーターの高さ
  static const double _indicatorHeight = 56.0;


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final gp = context.read<GalleryProvider>();
    
    gp.init();
    gp.addListener(_onProviderUpdate);
    _controller.addListener(_userScrollListener);
  }

  @override
  void dispose() {
    context.read<GalleryProvider>().removeListener(_onProviderUpdate);
    _controller.removeListener(_userScrollListener);
    _controller.dispose();
    super.dispose();
  }
  
  /// Providerの状態が更新されたときに呼ばれるリスナー
  void _onProviderUpdate() {
    final gp = context.read<GalleryProvider>();

    if (gp.loading) return; // ロード中はなにもしない

    // --- 1. 初回レイアウト処理 ---
    if (!_initialLayoutCompleted && gp.assets.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _performInitialScrollAndLoad();
        }
      });
    }
    // ★★★ 2. 古い写真の追加読み込み後のスクロール位置補正処理 ★★★
    else if (_isLoadingMore) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          final newMaxScrollExtent = _controller.position.maxScrollExtent;
          // 追加された高さ（新しいアイテム＋インジケーター）
          final addedHeightWithIndicator = newMaxScrollExtent - _oldMaxScrollExtent;
          
          // インジケーターが消えることを見越して、その高さ分を引いた位置にジャンプする
          final targetOffset = _controller.offset + addedHeightWithIndicator - _indicatorHeight;
          
          _controller.jumpTo(targetOffset);
          
          // 補正が完了したので、フラグをリセット
          setState(() {
            _isLoadingMore = false;
          });
        }
      });
    }
  }
  
  /// 初回スクロールと追加読み込みを実行するメソッド
  void _performInitialScrollAndLoad() {
    final gp = context.read<GalleryProvider>();
    if (!mounted || !_controller.hasClients || gp.loading) return;

    _controller.jumpTo(_controller.position.maxScrollExtent);
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);

      if (_controller.position.maxScrollExtent == 0.0 && gp.hasMore) {
        gp.loadMoreIfNeeded();
      } else {
        if (!_initialLayoutCompleted) {
          setState(() {
            _initialLayoutCompleted = true;
          });
        }
      }
    });
  }


  /// ユーザーが手動でスクロールした際のリスナー
  void _userScrollListener() {
    // 初回処理完了後 & 一番上に近づいたら & 読み込み中でなければ
    if (_initialLayoutCompleted && !_isLoadingMore && _controller.position.extentBefore < 500.0) {
      final gp = context.read<GalleryProvider>();
      if (!gp.loading) {
        // ★★★ 読み込み前に、現在のスクロール状態を保存 ★★★
        setState(() {
          _isLoadingMore = true;
          _oldMaxScrollExtent = _controller.position.maxScrollExtent;
        });
        gp.loadMoreIfNeeded();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final barBackgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100.withAlpha(204)
        : Colors.black.withAlpha(179);

    return Scaffold(
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

          return CustomScrollView(
            key: const PageStorageKey('gallery_scroll_view'),
            controller: _controller,
            slivers: [
              _buildSliverAppBar(barBackgroundColor),
              // 追加読み込み中のインジケーター
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: _indicatorHeight,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              _buildSliverGrid(gp),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(Color barBackgroundColor) {
    return SliverAppBar(
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
    );
  }

  SliverPadding _buildSliverGrid(GalleryProvider gp) {
    return SliverPadding(
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
    );
  }

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

  Widget _buildSelectModeBottomBar(BuildContext context) {
    return BottomAppBar(
      height: 57.0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
      final assets = context.read<GalleryProvider>().assets;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            assets: assets,
            initialIndex: assets.indexOf(asset),
          ),
        ),
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
    
    // refreshを呼ぶ前にフラグをリセット
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _initialLayoutCompleted = false; 
    });

    // Providerにリフレッシュを依頼
    await context.read<GalleryProvider>().refresh();
  }

  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return;
    final assets = context.read<GalleryProvider>().assets.where((a) => _selectedIds.contains(a.id));
    final files = await Future.wait(assets.map((a) => a.file));
    final paths = files.where((f) => f != null).map((f) => f!.path).toList();
    if (paths.isNotEmpty) {
      final xFiles = paths.map((path) => XFile(path)).toList();
      await SharePlus.instance.share(
        ShareParams(
          text: '共有します',
          files: xFiles,
        ),
      );
    }
  }
}
