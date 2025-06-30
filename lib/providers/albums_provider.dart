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
    if (_albums.isNotEmpty || _loading) return;

    // 写真ライブラリへのアクセス権限を確認
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;

    try {
      _setLoading(true);

      // 画像と動画が含まれるすべてのアルバム（AssetPathEntity）を取得
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      // 各アルバムのアセット数を並行して取得
      final counts = await Future.wait(paths.map((path) => path.assetCountAsync));

      // アセットが1件以上含まれるアルバムのみをフィルタリング
      final filteredAlbums = <AssetPathEntity>[
        for (int i = 0; i < paths.length; i++)
          if (counts[i] > 0) paths[i],
      ];

      _albums = filteredAlbums;
    } finally {
      _setLoading(false);
    }
  }

  /// ローディング状態を設定し、リスナーに通知するヘルパーメソッド。
  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }
}