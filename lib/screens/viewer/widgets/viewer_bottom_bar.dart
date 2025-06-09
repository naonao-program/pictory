import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class ViewerBottomBar extends StatelessWidget {
  final bool show;
  final AssetEntity asset;
  final VoidCallback onDelete;
  final VoidCallback onShowInfo;

  const ViewerBottomBar({
    super.key,
    required this.show,
    required this.asset,
    required this.onDelete,
    required this.onShowInfo,
  });
  
  Future<void> _onShare() async {
    final file = await asset.file;
    if (file == null) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      bottom: show ? 0 : -100, // 適当な高さで隠す
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        color: Colors.black.withOpacity(0.4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: _onShare),
            IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: onShowInfo),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}