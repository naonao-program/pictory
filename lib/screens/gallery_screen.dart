import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  // --- State Variables ---

  /// GridViewを制御するためのスクロールコントローラー
  final ScrollController _controller = ScrollController();

  /// 初回に写真リストの最下部へジャンプしたかどうかを管理するフラグ
  bool _didJumpToBottom = false;

  /// 選択モードかどうかを管理するフラグ
  bool _selectMode = false;

  /// 選択された写真（AssetEntity）のIDを保持するSet
  final Set<String> _selectedIds = {};

  /// 最下部へのジャンプを試行した回数（無限ループ防止用）
  int _jumpTries = 0;

  /// ボトムナビゲーションバーで選択されているタブのインデックス
  int _bottomNavIndex = 0;

  // --- Lifecycle Methods ---

  /// ウィジェットが初期化されるときに一度だけ呼ばれる
  @override
  void initState() {
    super.initState();
    // initState内でcontextを使うとエラーになることがあるため、ビルド後の最初のフレームで処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Providerを取得してデータの初期化を開始
      final gp = context.read<GalleryProvider>();
      gp.init();

      // Providerの状態変化を監視するリスナーを登録
      gp.addListener(() {
        // mounted: ウィジェットがツリーに存在するか確認
        // !gp.loading: Providerがロード中でないことを確認
        // !_didJumpToBottom: まだジャンプしていないことを確認
        // gp.assets.isNotEmpty: 写真データが1件以上あることを確認
        SchedulerBinding.instance.endOfFrame.then((_) {
          if (mounted) {
            _controller.jumpTo(_controller.position.maxScrollExtent);
            _didJumpToBottom = true; // ジャンプ済みフラグを立てる
          }
        });
      });
    });
  }

  /// ウィジェットが破棄されるときに呼ばれる
  @override
  void dispose() {
    // リスナーを解除してメモリリークを防ぐ
    context.read<GalleryProvider>().removeListener(() {});
    // コントローラーを破棄してメモリリークを防ぐ
    _controller.dispose();
    super.dispose();
  }

  // --- UI Build Methods ---

  /// メインのUIを構築するメソッド
  @override
  Widget build(BuildContext context) {
    // 現在のテーマ（ライト/ダーク）に合わせてバーの背景色を決定
    final barBackgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100.withOpacity(0.8) // ライトモード時
        : Colors.black.withOpacity(0.7); // ダークモード時

    return Scaffold(
      // 選択モードの状態に応じて、表示するボトムバーを切り替える
      bottomNavigationBar: _selectMode
          ? _buildSelectModeBottomBar(context) // 選択モード時のバー
          : _buildNormalModeBottomBar(), // 通常時のタブバー

      // Providerの状態を監視し、変化があればUIを再構築する
      body: Consumer<GalleryProvider>(
        builder: (context, gp, child) {
          // 写真へのアクセスが許可されていない場合
          if (gp.noAccess) {
            return Center(child: TextButton(onPressed: gp.openSetting, child: const Text('写真へのアクセスを許可')));
          }
          // ロード中かつ写真データがまだない場合
          if (gp.loading && gp.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // メインのスクロール領域を構築
          return CustomScrollView(
            controller: _controller,
            slivers: [
              // 1. スクロールに連動するAppBar
              _buildSliverAppBar(barBackgroundColor),
              // 2. 写真を表示するグリッド
              _buildSliverGrid(gp),
            ],
          );
        },
      ),
    );
  }

  /// スクロールに連動するAppBarを構築する
  SliverAppBar _buildSliverAppBar(Color barBackgroundColor) {
    return SliverAppBar(
      // 選択モードに応じてタイトルを「Select Items」と「All Photos」で切り替える
      title: Text(_selectMode ? 'Select Items' : 'All Photos'),
      centerTitle: true, // タイトルを中央に配置
      pinned: true,      // スクロールしてもAppBarを画面上部に固定
      floating: true,    // 下にスクロールするとすぐにAppBarが現れる
      elevation: 0,      // AppBarの影を消す
      backgroundColor: barBackgroundColor, // 半透明の背景色
      // 選択モードに応じてアクションボタンを「Cancel」と「Select」で切り替える
      actions: [
        TextButton(
          onPressed: _toggleSelectMode,
          child: Text(_selectMode ? 'Cancel' : 'Select'),
        ),
      ],
    );
  }

  /// 写真を表示するグリッドを構築する
  SliverPadding _buildSliverGrid(GalleryProvider gp) {
    // SliverGrid全体に余白を設定し、画像間のスペースのように見せる
    return SliverPadding(
      padding: const EdgeInsets.all(1.0),
      sliver: SliverGrid(
        // グリッドのレイアウトを定義
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,     // 3列表示
          mainAxisSpacing: 1,    // 垂直方向のスペース
          crossAxisSpacing: 1,   // 水平方向のスペース
          childAspectRatio: 1,   // アスペクト比を1:1（正方形）に
        ),
        // グリッドに表示するアイテムを動的に構築
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // 必要に応じて次のページを読み込む
            gp.loadMoreIfNeeded(index);
            // 表示するアセットを取得
            final asset = gp.assets[index];
            // このアセットが選択されているか確認
            final isSelected = _selectedIds.contains(asset.id);
            // 個々のグリッドアイテムウィジェットを返す
            return AssetGridItem(
              asset: asset,
              isSelected: isSelected,
              onTap: () => _onItemTap(asset, isSelected),
              onLongPress: () => _onItemLongPress(asset),
            );
          },
          childCount: gp.assets.length, // 表示するアイテムの総数
        ),
      ),
    );
  }

  /// 通常時のボトムナビゲーションバーを構築する
  Widget _buildNormalModeBottomBar() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex, // 現在選択されているタブのインデックス
      onTap: (index) => setState(() => _bottomNavIndex = index), // タブがタップされたらインデックスを更新
      type: BottomNavigationBarType.fixed, // タブのラベルを常に表示
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'All Photos'),
        BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'For You'),
        BottomNavigationBarItem(icon: Icon(Icons.collections_outlined), label: 'Albums'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
      ],
    );
  }

  /// 選択モード時のボトムバーを構築する
  Widget _buildSelectModeBottomBar(BuildContext context) {
    return BottomAppBar(
      child: SafeArea( // iPhoneのノッチなどを避ける
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // 両端に寄せる
          children: [
            // 共有ボタン
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              // 1件以上選択されている場合のみ押せるようにする
              onPressed: _selectedIds.isNotEmpty ? _onShare : null,
            ),
            // 削除ボタン
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              // 1件以上選択されている場合のみ押せるようにする
              onPressed: _selectedIds.isNotEmpty ? _onDelete : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- Event Handlers & Logic ---

  /// 写真リストの最下部までスクロールを試みる
  void _tryJumpToBottom() {
    if (_controller.hasClients && _controller.position.hasContentDimensions) {
      _controller.jumpTo(_controller.position.maxScrollExtent);
    } else if (_jumpTries < 5) {
      _jumpTries++;
      // 成功するまで少し待ってから再試行
      Future.delayed(const Duration(milliseconds: 200), _tryJumpToBottom);
    }
  }

  /// 写真アイテムがタップされたときの処理
  void _onItemTap(AssetEntity asset, bool isSelected) {
    if (_selectMode) {
      // 選択モードの場合：選択状態をトグルする
      setState(() {
        if (isSelected) {
          _selectedIds.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
        }
      });
    } else {
      // 通常モードの場合：写真ビューワー画面に遷移
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ViewerPage(asset: asset)),
      );
    }
  }

  /// 写真アイテムが長押しされたときの処理
  void _onItemLongPress(AssetEntity asset) {
    // すでに選択モードでなければ、選択モードに移行する
    if (!_selectMode) {
      setState(() {
        _selectMode = true;
        _selectedIds.add(asset.id); // 長押ししたアイテムを選択状態にする
      });
    }
  }

  /// 選択モードをオン/オフする
  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      // 選択モードを抜けるときは、選択リストをクリアする
      if (!_selectMode) {
        _selectedIds.clear();
      }
    });
  }

  /// 選択された写真を削除する
  Future<void> _onDelete() async {
    if (_selectedIds.isEmpty) return; // 何も選択されていなければ処理しない
    await PhotoManager.editor.deleteWithIds(_selectedIds.toList());
    // ギャラリーの状態をリフレッシュ
    await context.read<GalleryProvider>().refresh();
    // 選択モードを解除し、選択リストをクリア
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _didJumpToBottom = false; // 再度ジャンプを許可
    });
  }

  /// 選択された写真を共有する
  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return; // 何も選択されていなければ処理しない
    // IDを元にAssetEntityのリストを取得
    final assets = context.read<GalleryProvider>().assets.where((a) => _selectedIds.contains(a.id));
    // AssetEntityから実際のファイルパスを取得
    final files = await Future.wait(assets.map((a) => a.file));
    final paths = files.where((f) => f != null).map((f) => f!.path).toList();
    if (paths.isNotEmpty) {
      // XFileのリストを作成
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