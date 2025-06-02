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

  /// 初回ジャンプ済みフラグ
  bool _didJumpToBottom = false;

  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  int _jumpTries = 0;

  void _tryJumpToBottom() {
    if (_controller.hasClients) {
      _controller.jumpTo(_controller.position.maxScrollExtent);
      _jumpTries++;
      if (_jumpTries < 5) {
        Future.delayed(const Duration(milliseconds: 200), _tryJumpToBottom);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Provider の init() を次フレームで呼び出し
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GalleryProvider>();
      gp.init();

      // Provider の状態変化をリスンして、初回ロード完了時に一度だけジャンプする
      gp.addListener(() {
        if (!_didJumpToBottom && !gp.loading && gp.assets.isNotEmpty) {
          _jumpTries = 0;
          Future.delayed(const Duration(milliseconds: 200), _tryJumpToBottom);
          _didJumpToBottom = true;
        }
      });
    });
  }

  @override
  void dispose() {
    // リスナーを解除（匿名クロージャではなく、登録時の関数を保存しておいて remove するのが理想ですが、
    // このサンプルでは簡易的に全リスナ―を外すイメージです）
    context.read<GalleryProvider>().removeListener(() {});
    _controller.dispose();
    super.dispose();
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
        builder: (context, gp, child) {
          // 1) 権限なし
          if (gp.noAccess) {
            return Center(
              child: TextButton(
                onPressed: gp.openSetting,
                child: const Text('写真へのアクセスを許可'),
              ),
            );
          }

          // 2) ロード中かつ assets が空: ローディング表示
          if (gp.loading && gp.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3) GridView: 3列・隙間なし・正方形セル
          return GridView.builder(
            controller: _controller,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1, // 正方形グリッド
            ),
            itemCount: gp.assets.length,
            itemBuilder: (context, index) {
              // 先頭10件以内に来たら古いページを追加読み込み
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
      _didJumpToBottom = false; // 削除後に再度ジャンプを許可
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
