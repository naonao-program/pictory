import 'package:flutter/material.dart';
import 'package:pictory/screens/album/albums_screen.dart';
import 'package:pictory/screens/gallery/gallery_screen.dart';

/// アプリケーションのメイン画面。
/// BottomNavigationBarと、選択モード時のアクションバーの切り替えを管理します。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 現在選択されているタブのインデックス
  int _selectedIndex = 0;
  // PageViewを制御するためのコントローラー
  final PageController _pageController = PageController();

  // --- 子ウィジェット（GalleryScreen）の状態を受け取るための変数 ---
  /// GalleryScreenが選択モードかどうか
  bool _isGallerySelectMode = false;
  /// GalleryScreenの共有アクション
  VoidCallback? _onShareAction;
  /// GalleryScreenの削除アクション
  VoidCallback? _onDeleteAction;

  // 表示する画面のリスト
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // GalleryScreenに状態を通知するためのコールバックを渡す
    _screens = [
      GalleryScreen(
        onSelectionChange: (isActive, onShare, onDelete) {
          // GalleryScreenの状態変更を受け取ったら、UIを更新する
          setState(() {
            _isGallerySelectMode = isActive;
            _onShareAction = onShare;
            _onDeleteAction = onDelete;
          });
        },
      ),
      const AlbumsScreen(),
    ];
  }

  /// BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    // PageViewをタップされたタブのページにアニメーション付きで移動
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PageViewで画面をスワイプ切り替え可能にする
      body: PageView(
        controller: _pageController,
        // ページが切り替わったときに呼ばれる
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      // フッターのナビゲーションバー
      // Photosタブ(_selectedIndex == 0)が選択モードの場合のみ、アクションバーを表示
      bottomNavigationBar: _isGallerySelectMode && _selectedIndex == 0
          ? _buildSelectModeActions()
          : _buildNormalBottomNav(),
    );
  }

  /// 通常時のBottomNavigationBarを構築する
  Widget _buildNormalBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library_outlined),
          activeIcon: Icon(Icons.photo_library),
          label: 'Photos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.collections_outlined),
          activeIcon: Icon(Icons.collections),
          label: 'Albums',
        ),
      ],
    );
  }

  /// 選択モード時のアクションバー（共有・削除）を構築する
  Widget _buildSelectModeActions() {
    return BottomAppBar(
      child: SafeArea(
        child: Row(
          // mainAxisAlignmentで両端に寄せる
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              // 実行するアクションがGalleryScreenから渡されていない場合は無効
              onPressed: _onShareAction,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              // 実行するアクションがGalleryScreenから渡されていない場合は無効
              onPressed: _onDeleteAction,
            ),
          ],
        ),
      ),
    );
  }
}
