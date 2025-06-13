import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/gallery_provider.dart';
import '../../widgets/asset_grid_item.dart';
import '../viewer/viewer_screen.dart';

/// ギャラリー画面のメインとなるStatefulWidget。
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

/// GalleryScreenの状態を管理するStateクラス。
/// AutomaticKeepAliveClientMixinは、タブ切り替えなどで状態を保持するために使用します。
class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  /// グリッドビューのスクロールを監視するためのコントローラー。
  final ScrollController _controller = ScrollController();
  
  /// アイテム選択モードかどうかを示すフラグ。
  bool _selectMode = false;
  
  /// 選択されたアセットのIDを保持するSet。
  final Set<String> _selectedIds = {};
  
  /// 下部ナビゲーションバーの現在選択中のインデックス。
  int _bottomNavIndex = 0;
  
  /// 初回のレイアウトとスクロールが完了したかを示すフラグ。
  bool _initialLayoutCompleted = false;

  /// 古い写真を追加読み込み中かを示すフラグ。
  bool _isLoadingMore = false;
  
  /// 追加読み込みが始まる直前の、スクロール可能な最大範囲を保持する変数。
  /// 読み込み後のスクロール位置調整に使用します。
  double _oldMaxScrollExtent = 0.0;
  
  /// 画面上部に表示される追加読み込みインジケーターの高さ。
  static const double _indicatorHeight = 56.0;

  @override
  bool get wantKeepAlive => true; // タブが非表示になってもStateを破棄しない

  @override
  void initState() {
    super.initState();
    final gp = context.read<GalleryProvider>();
    
    gp.init(); // Providerの初期化
    gp.addListener(_onProviderUpdate); // Providerの更新を監視
    _controller.addListener(_userScrollListener); // スクロールイベントを監視
  }

  @override
  void dispose() {
    // リスナーとコントローラーを破棄してメモリリークを防ぐ
    context.read<GalleryProvider>().removeListener(_onProviderUpdate);
    _controller.removeListener(_userScrollListener);
    _controller.dispose();
    super.dispose();
  }
  
  /// GalleryProviderの状態が更新されたときに呼び出されるリスナー。
  void _onProviderUpdate() {
    final gp = context.read<GalleryProvider>();

    if (gp.loading) return; // データのロード中は処理しない

    // --- 1. 初回レイアウト時の処理 ---
    // まだ初回レイアウトが完了しておらず、アセットが読み込まれた場合
    if (!_initialLayoutCompleted && gp.assets.isNotEmpty) {
      // フレームの描画が終わった直後に実行する
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          // 初期スクロールと、必要であれば追加の読み込みを実行
          _performInitialScrollAndLoad();
        }
      });
    }
    // --- 2. 古い写真の追加読み込み完了後のスクロール位置補正処理 ---
    else if (_isLoadingMore) {
      // フレームの描画が終わった直後に実行する
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          final newMaxScrollExtent = _controller.position.maxScrollExtent;
          // 新しく追加されたコンテンツの高さを計算
          final addedHeight = newMaxScrollExtent - _oldMaxScrollExtent;
          
          // 現在のスクロール位置に、追加されたコンテンツの高さを加算してジャンプする。
          // これにより、ユーザーの見ていた位置が維持される。
          _controller.jumpTo(_controller.offset + addedHeight);
        }
      });

      // UIを更新して、ローディングインジケーターを非表示にする
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  /// 初回表示時に、一番下までスクロールし、必要に応じて追加のデータを読み込むメソッド。
  void _performInitialScrollAndLoad() {
    final gp = context.read<GalleryProvider>();
    if (!mounted || !_controller.hasClients || gp.loading) return;

    // 一番下（最新の写真）までジャンプ
    _controller.jumpTo(_controller.position.maxScrollExtent);
    
    // 短い遅延を挟んで再度ジャンプ（初回描画のタイミング問題を回避するため）
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);

      // スクロールバーが表示されないほど写真が少ない場合、追加読み込みを試みる
      if (_controller.position.maxScrollExtent == 0.0 && gp.hasMore) {
        gp.loadMoreIfNeeded();
      } else {
        // 初回レイアウト完了フラグを立てる
        if (!_initialLayoutCompleted) {
          setState(() {
            _initialLayoutCompleted = true;
          });
        }
      }
    });
  }

  /// ユーザーのスクロール操作を監視するリスナー。
  void _userScrollListener() {
    // 条件を満たした場合、古い写真を追加読み込みする
    if (_shouldLoadMore()) {
      _loadMorePhotos();
    }
  }

  /// 古い写真を追加読み込みすべきかどうかを判断するメソッド。
  bool _shouldLoadMore() {
    return _initialLayoutCompleted && // 初回レイアウトが完了している
        !_isLoadingMore &&           // 現在読み込み中でない
        _controller.position.extentBefore < 500.0; // スクロール位置が一番上から500px以内
  }

  /// 古い写真の追加読み込みを開始するメソッド。
  void _loadMorePhotos() {
    final gp = context.read<GalleryProvider>();
    if (!gp.loading) {
      setState(() {
        _isLoadingMore = true; // 読み込み中フラグを立てる
        // 読み込み前のスクロール範囲を保存
        _oldMaxScrollExtent = _controller.position.maxScrollExtent;
      });
      gp.loadMoreIfNeeded(); // Providerに読み込みを依頼
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要

    final barBackgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100.withAlpha(204)
        : Colors.black.withAlpha(179);

    return Scaffold(
      // 選択モードに応じて下部バーを切り替える
      bottomNavigationBar: _selectMode
          ? _buildSelectModeBottomBar(context)
          : _buildNormalModeBottomBar(),
      body: Consumer<GalleryProvider>(
        builder: (context, gp, child) {
          // --- 状態に応じたUIの表示 ---
          if (gp.noAccess) {
            // アクセスが拒否されている場合
            return Center(child: TextButton(onPressed: gp.openSetting, child: const Text('写真へのアクセスを許可')));
          }
          if (gp.loading && gp.assets.isEmpty) {
            // 初回読み込み中の場合
            return const Center(child: CircularProgressIndicator());
          }

          // --- メインのグリッドビュー ---
          return CustomScrollView(
            key: const PageStorageKey('gallery_scroll_view'), // スクロール位置を保持
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

  /// スクロールと連動する上部アプリバーを構築する。
  SliverAppBar _buildSliverAppBar(Color barBackgroundColor) {
    return SliverAppBar(
      title: Text(_selectMode ? 'Select Items' : 'All Photos'),
      centerTitle: true,
      pinned: true,      // 上部に固定
      floating: true,    // 下スクロールですぐに表示
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

  /// 写真・動画のグリッド部分を構築する。
  SliverPadding _buildSliverGrid(GalleryProvider gp) {
    return SliverPadding(
      padding: const EdgeInsets.all(1.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,        // 3列表示
          mainAxisSpacing: 1,       // 垂直方向の間隔
          crossAxisSpacing: 1,      // 水平方向の間隔
          childAspectRatio: 1,        // アスペクト比を1:1に
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

  /// 通常モード時の下部ナビゲーションバーを構築する。
  Widget _buildNormalModeBottomBar() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: (index) => setState(() => _bottomNavIndex = index),
      type: BottomNavigationBarType.fixed, // タップされたアイテムをハイライト
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'All Photos'),
        BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'For You'),
        BottomNavigationBarItem(icon: Icon(Icons.collections_outlined), label: 'Albums'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
      ],
    );
  }

  /// 選択モード時の下部アクションバーを構築する。
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
                // 選択中のアイテムがなければ無効化
                onPressed: _selectedIds.isNotEmpty ? _onShare : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                // 選択中のアイテムがなければ無効化
                onPressed: _selectedIds.isNotEmpty ? _onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// グリッドのアイテムがタップされたときの処理。
  void _onItemTap(AssetEntity asset, bool isSelected) {
    if (_selectMode) {
      // --- 選択モード中の場合 ---
      setState(() {
        if (isSelected) {
          _selectedIds.remove(asset.id); // 選択解除
        } else {
          _selectedIds.add(asset.id);    // 選択
        }
      });
    } else {
      // --- 通常モードの場合 ---
      final assets = context.read<GalleryProvider>().assets;
      // ビューワー画面に遷移
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            assets: assets,
            initialIndex: assets.indexOf(asset), // タップされた写真のインデックスを渡す
          ),
        ),
      );
    }
  }

  /// グリッドのアイテムが長押しされたときの処理。
  void _onItemLongPress(AssetEntity asset) {
    if (!_selectMode) {
      // 通常モードであれば、選択モードに移行する
      setState(() {
        _selectMode = true;
        _selectedIds.add(asset.id); // 長押ししたアイテムを選択状態にする
      });
    }
  }

  /// 選択モードを切り替える。
  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        // 通常モードに戻るときは、選択状態をクリア
        _selectedIds.clear();
      }
    });
  }

  /// 選択したアイテムを削除する処理。
  Future<void> _onDelete() async {
    if (_selectedIds.isEmpty) return;
    // PhotoManagerに削除を依頼
    await PhotoManager.editor.deleteWithIds(_selectedIds.toList());
    
    // 削除後のリフレッシュの前に、UIの状態をリセット
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _initialLayoutCompleted = false; // リフレッシュ後に初回スクロールを再度実行するため
    });

    // Providerにデータのリフレッシュを依頼
    await context.read<GalleryProvider>().refresh();
  }

  /// 選択したアイテムを共有する処理。
  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return;
    // 選択されたIDのアセットを取得
    final assets = context.read<GalleryProvider>().assets.where((a) => _selectedIds.contains(a.id));
    // アセットからファイルを取得
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
