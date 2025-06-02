/* 
 *プレースホルダーを 1 行で使うためのラッパー。
 *画像と同じ「真四角」の箱を Shimmer させて
 *「ここに写真が来るよ！」とユーザーに示す。
*/
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(color: Colors.grey),
    );
  }
}
