/* 
 *四角の枠
*/

import 'package:flutter/material.dart';

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ここでは簡易的にグレーのボックスを配置するだけ
    return Container(
      color: Colors.grey.shade300,
    );
  }
}

