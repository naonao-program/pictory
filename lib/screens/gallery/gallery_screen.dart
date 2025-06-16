import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/gallery_provider.dart';
import '../../widgets/asset_grid_item.dart';
import '../viewer/viewer_screen.dart';

// 親ウィジェット(MainScreen)に状態を伝えるためのコールバック関数の型定義
// isActive: 選択モードかどうか
// onShare: 共有ボタンが押されたときのアクション
// onDelete: 削除ボタンが押されたときのアクション
typedef SelectionChangeCallback = void Function(
    bool isActive, VoidCallback? onShare, VoidCallback? onDelete);

/// ギャラリー画面のメインとなるStatefulWidget。
class GalleryScreen extends StatefulWidget {
  // 親からコールバック関数を受け取るためのプロパティ
  final SelectionChangeCallback? onSelectionChange;

  const GalleryScreen({Key? key, this.onSelectionChange}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

/// GalleryScreenの状態を管理するStateクラス。
/// AutomaticKeepAliveClientMixinは、タブ切り替えなどで状態を保持するために使用します。
class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  bool _initialLayoutCompleted = false;
  bool _isLoadingMore = false;
  double _oldMaxScrollExtent = 0.0;
  static const double _indicatorHeight = 56.0;

  // タブが非表示になってもStateを破棄しないようにするための設定
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

  /// 親ウィジェット(MainScreen)に現在の状態を通知するヘルパーメソッド
  void _updateParent() {
    // 選択中のアイテムが1つ以上ある場合のみ、共有・削除アクションを有効にする
    final bool hasSelection = _selectedIds.isNotEmpty;
    widget.onSelectionChange?.call(
      _selectMode,
      hasSelection ? _onShare : null,
      hasSelection ? _onDelete : null,
    );
  }

  void _onProviderUpdate() {
    final gp = context.read<GalleryProvider>();
    if (gp.loading) return;

    if (!_initialLayoutCompleted && gp.assets.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _performInitialScrollAndLoad();
        }
      });
    } else if (_isLoadingMore) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          final newMaxScrollExtent = _controller.position.maxScrollExtent;
          final addedHeight = newMaxScrollExtent - _oldMaxScrollExtent;
          _controller.jumpTo(_controller.offset + addedHeight);
        }
      });
      setState(() => _isLoadingMore = false);
    }
  }

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

  void _userScrollListener() {
    if (_shouldLoadMore()) _loadMorePhotos();
  }

  bool _shouldLoadMore() =>
      _initialLayoutCompleted &&
      !_isLoadingMore &&
      _controller.position.extentBefore < 500.0;

  void _loadMorePhotos() {
    final gp = context.read<GalleryProvider>();
    if (gp.loading) return;
    setState(() {
      _isLoadingMore = true;
      _oldMaxScrollExtent = _controller.position.maxScrollExtent;
    });
    gp.loadMoreIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixinを使用するためにsuper.buildを呼び出す
    super.build(context);

    final barBackgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100.withAlpha(204)
        : Colors.black.withAlpha(179);

    // MainScreen側でScaffoldを持つため、このウィジェットはコンテンツ本体のみを返す
    return Consumer<GalleryProvider>(
      builder: (context, gp, child) {
        if (gp.noAccess) {
          return Center(
              child: TextButton(
                  onPressed: gp.openSetting,
                  child: const Text('写真へのアクセスを許可')));
        }
        if (gp.loading && gp.assets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return CustomScrollView(
          key: const PageStorageKey('gallery_scroll_view'),
          controller: _controller,
          slivers: [
            _buildSliverAppBar(barBackgroundColor),
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
    );
  }

  /// スクロールと連動する上部アプリバーを構築する
  SliverAppBar _buildSliverAppBar(Color barBackgroundColor) {
    return SliverAppBar(
      // 選択モードに応じてタイトルを変更
      title: Text(_selectMode ? '${_selectedIds.length}件を選択中' : 'Photos'),
      centerTitle: true,
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: barBackgroundColor,
      actions: [
        TextButton(
          onPressed: _toggleSelectMode,
          child: Text(_selectMode ? 'キャンセル' : '選択'),
        ),
      ],
    );
  }

  /// 写真・動画のグリッド部分を構築する
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

  void _onItemTap(AssetEntity asset, bool isSelected) {
    if (_selectMode) {
      setState(() {
        if (isSelected) {
          _selectedIds.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
        }
      });
      _updateParent(); // 選択状態が変わったので親に通知
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
      _updateParent(); // 選択モードに切り替わったので親に通知
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        _selectedIds.clear();
      }
    });
    _updateParent(); // 選択モードが切り替わったので親に通知
  }

  Future<void> _onDelete() async {
    if (_selectedIds.isEmpty) return;
    
    // 削除確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedIds.length}件の項目を削除'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('削除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PhotoManager.editor.deleteWithIds(_selectedIds.toList());
    
    // UIを通常モードに戻す
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _initialLayoutCompleted = false;
    });

    _updateParent(); // 状態が変わったので親に通知
    await context.read<GalleryProvider>().refresh();
  }

  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return;

    final assets = context
        .read<GalleryProvider>()
        .assets
        .where((a) => _selectedIds.contains(a.id));
    final files = await Future.wait(assets.map((a) => a.file));
    final paths = files.where((f) => f != null).map((f) => f!.path).toList();

    if (paths.isNotEmpty) {
      // share_plusパッケージを使って共有ダイアログを表示
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
