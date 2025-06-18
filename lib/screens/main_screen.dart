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
          // buildメソッドが実行中の更新を防ぐため、安全にsetStateを呼び出す
          if (mounted) {
            setState(() {
              _isGallerySelectMode = isActive;
              _onShareAction = onShare;
              _onDeleteAction = onDelete;
            });
          }
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
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200), // 短めのアニメ
        transitionBuilder: (Widget child, Animation<double> anim) {
          // 上からフェードイン＆縦方向にスライド
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        child: _isGallerySelectMode && _selectedIndex == 0
            ? _buildSelectModeActions(key: const ValueKey('select'))
            : _buildNormalBottomNav(key: const ValueKey('normal')),
      ),
    );
  }

  /// 通常時の BottomNavigationBar
  Widget _buildNormalBottomNav({Key? key}) {
    return BottomNavigationBar(
      key: key,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
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

  /// 選択モード時のアクションバー
  Widget _buildSelectModeActions({Key? key}) {
    // 通常の BottomNavigationBar と同じ背景色を取得
    final Color bgColor = Theme.of(context)
        .bottomNavigationBarTheme
        .backgroundColor
      ?? Theme.of(context).bottomAppBarTheme.color
      ?? Theme.of(context).scaffoldBackgroundColor;

    return SafeArea(
      key: key,
      top: false, // 上側の余白はいらない
      child: SizedBox(
        height: kBottomNavigationBarHeight,
        child: BottomAppBar(
          color: bgColor,
          elevation: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: _onShareAction,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _onDeleteAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}