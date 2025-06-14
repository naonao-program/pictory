import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// デバイス内のアルバム一覧の状態を管理し、UIにデータを提供するクラス。
/// 「アルバム」タブのデータソースとして機能します。
class AlbumsProvider extends ChangeNotifier {
  /// アルバムの読み込み中かどうかを示すフラグ。
  bool _loading = false;

  /// 読み込んだアルバム（AssetPathEntity）のリスト。
  List<AssetPathEntity> _albums = [];

  /// `_loading`フラグのゲッター。
  bool get loading => _loading;

  /// 外部から参照するための、読み込み済みアルバムのリスト。
  List<AssetPathEntity> get albums => List.unmodifiable(_albums);

  /// デバイスからアルバム一覧を非同期に読み込むメソッド。
  Future<void> loadAlbums() async {
    // 既に読み込み済みの場合は再読み込みしない
    if (_albums.isNotEmpty) return;

    // 写真ライブラリへのアクセス権限を確認
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;

    _loading = true;
    notifyListeners();

    // 画像と動画が含まれるすべてのアルバム（AssetPathEntity）を取得
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    // アセットが1件も含まれていない空のアルバムを除外する
    final List<AssetPathEntity> filteredAlbums = [];
    for (final path in paths) {
      final count = await path.assetCountAsync;
      if (count > 0) {
        filteredAlbums.add(path);
      }
    }
    
    _albums = filteredAlbums;
    _loading = false;
    notifyListeners();
  }
}
