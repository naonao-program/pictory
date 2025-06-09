import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

class ViewerAppBar extends StatelessWidget {
  final bool show;
  final AssetEntity asset;
  final VoidCallback onBackPressed;
  
  const ViewerAppBar({
    super.key,
    required this.show,
    required this.asset,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final date = asset.createDateTime;
    final formattedDate = DateFormat('M月d日').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: show ? 0 : -kToolbarHeight - MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        color: Colors.black.withOpacity(0.4),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: onBackPressed),
            const Spacer(),
            Column(
              children: [
                Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(formattedTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const Spacer(),
            // 編集ボタン
            TextButton(onPressed: () {}, child: const Text('編集', style: TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}