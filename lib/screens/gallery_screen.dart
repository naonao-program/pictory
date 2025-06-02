// gallery_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/gallery_provider.dart';
import '../widgets/asset_grid_item.dart';
import 'viewer_page.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ScrollController _controller = ScrollController();
  bool _didJumpToBottom = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Provider の init() を呼んで権限リクエスト＆初回読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GalleryProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectMode
              ? '${_selectedIds.length} selected'
              : 'Pictory',
        ),
        actions: [
          if (_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _onDelete,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _onShare,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectMode,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectMode,
            ),
        ],
      ),
      body: Consumer<GalleryProvider>(
        builder: (_, gp, __) {
          // 権限がない場合
          if (gp.noAccess) {
            return Center(
              child: TextButton(
                onPressed: gp.openSetting,
                child: const Text('写真へのアクセス権を許可'),
              ),
            );
          }

          // ロード中かつまだassetsが空ならローディング表示
          if (gp.loading && gp.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 一度だけ最下部にジャンプさせる
          if (!_didJumpToBottom &&
              _controller.hasClients &&
              gp.assets.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_controller.hasClients) {
                _controller.jumpTo(_controller.position.maxScrollExtent);
              }
            });
            _didJumpToBottom = true;
          }

          return GridView.builder(
            controller: _controller,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 1, // 正方形グリッド
            ),
            itemCount: gp.assets.length,
            itemBuilder: (_, index) {
              // 必要に応じて次ページ読み込み
              gp.loadMoreIfNeeded(index);

              final asset = gp.assets[index];
              final isSelected = _selectedIds.contains(asset.id);

              return AssetGridItem(
                asset: asset,
                isSelected: isSelected,
                onTap: () {
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
                      MaterialPageRoute(
                        builder: (_) => ViewerPage(asset: asset),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  // 長押しで選択モードに移行（任意）
                  if (!_selectMode) {
                    setState(() {
                      _selectMode = true;
                      _selectedIds.add(asset.id);
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedIds.clear();
    });
  }

  Future<void> _onDelete() async {
    if (_selectedIds.isEmpty) return;
    await PhotoManager.editor.deleteWithIds(_selectedIds.toList());
    await context.read<GalleryProvider>().refresh();
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
      _didJumpToBottom = false; // 再度ジャンプさせる場合は false に戻す
    });
  }

  Future<void> _onShare() async {
    if (_selectedIds.isEmpty) return;
    final assets = context
        .read<GalleryProvider>()
        .assets
        .where((a) => _selectedIds.contains(a.id));
    final files = await Future.wait(assets.map((a) => a.file));
    final paths = files.where((f) => f != null).map((f) => f!.path).toList();
    final xFiles = paths.map((p) => XFile(p)).toList();
    Share.shareXFiles(xFiles);
  }
}
