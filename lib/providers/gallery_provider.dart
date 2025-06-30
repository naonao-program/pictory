import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// デバイスのギャラリーの状態を管理し、UIにデータを提供するクラス。
/// 「すべての写真」タブのデータソースとして機能します。
/// ChangeNotifierを継承しており、状態の変更をUIに通知することができます。
class GalleryProvider extends ChangeNotifier {
  /// アセットの読み込み中かどうかを示すフラグ。
  bool _loading = false;

  /// ギャラリーへのアクセスが許可されていないかどうかを示すフラグ。
  bool _noAccess = false;

  /// 取得済みのAssetEntityのリスト。常に作成日時の昇順（古い→新しい）で保持されます。
  final List<AssetEntity> _assets = [];

  /// ページネーションで一度に読み込むアセットの数。
  final int _pageSize = 100;

  /// 次に読み込むべきページのインデックス。0から始まります。
  /// 過去のデータを遡って読み込むため、デクリメント（-1）されていきます。
  int? _nextPageToLoad;

  /// 全ページの中で、最も新しいアセットが含まれる「最後のページ」のインデックス。
  int? _lastPageIndex;

  /// まだ読み込んでいない古いアセット（ページ）が存在するかどうかを示すフラグ。
  bool _hasMore = true;

  /// "すべての写真"アルバム（AssetPathEntity）への参照。
  AssetPathEntity? _allPhotosPath;

  // --- 外部公開用のゲッター ---

  /// 外部から参照するための、読み込み済みアセットのリスト。
  /// List.unmodifiableでラップすることで、外部からリストが変更されるのを防ぎます。
  List<AssetEntity> get assets => List.unmodifiable(_assets);

  /// `_loading`フラグのゲッター。
  bool get loading => _loading;

  /// `_noAccess`フラグのゲッター。
  bool get noAccess => _noAccess;

  /// `_hasMore`フラグのゲッター。
  bool get hasMore => _hasMore;

  /// デバイスの設定アプリを開き、写真へのアクセス許可を変更するよう促すメソッド。
  void openSetting() {
    PhotoManager.openSetting();
  }

  /// プロバイダーの初期化処理。
  /// 権限の確認と、アセットの初回読み込みを行います。
  Future<void> init() async {
    // 1. 写真ライブラリへのアクセス権限をリクエストします。
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      _noAccess = true;
      notifyListeners();
      return;
    }

    // 2. "すべての写真"アルバムのパス情報を取得します。
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, // 画像と動画の両方
      onlyAll: true, // "すべての写真"アルバムのみを対象
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: true, // 昇順（古い→新しい）
          ),
        ],
      ),
    );

    if (paths.isEmpty) {
      // "すべての写真"アルバムが見つからない場合は、処理を終了します。
      _noAccess = false; // アルバムがない場合はアクセス拒否ではない
      _hasMore = false;
      notifyListeners();
      return;
    }

    _allPhotosPath = paths.first;

    // 3. アセットの初回読み込みを実行します。
    await refresh();
  }

  /// 必要に応じて、さらに古いページのアセットを読み込むメソッド。
  /// UI側（例: スクロールがリストの先頭に近づいた時）から呼び出されます。
  Future<void> loadMoreIfNeeded() async {
    if (_loading || !_hasMore) return;

    try {
      _setLoading(true);
      await _loadPage();
    } finally {
      _setLoading(false);
    }
  }

  /// アセットリストを強制的にリフレッシュするメソッド。
  Future<void> refresh() async {
    if (_loading) return;

    try {
      _setLoading(true);

      if (_allPhotosPath == null) {
        _assets.clear();
        _hasMore = false;
        return;
      }

      // 1. 最新の総アセット数を再取得する
      final int totalCount = await _allPhotosPath!.assetCountAsync;

      if (totalCount == 0) {
        // アセットが0件になった場合、状態を完全にクリア
        _assets.clear();
        _hasMore = false;
        _lastPageIndex = null;
        _nextPageToLoad = null;
        return;
        return;
      } else {
        // 2. ページネーション情報を再計算する
        final int pageCount = (totalCount / _pageSize).ceil();
        _lastPageIndex = pageCount - 1;
        // 3. 最新のページから読み直すためにカレントページをセットする
        _nextPageToLoad = _lastPageIndex;
      }

      // 4. _loadPageを呼び出してアセットリストをリセット＆再読み込み
      await _loadPage(reset: true);
    } finally {
      _setLoading(false);
    }
  }

  /// 実際にページ単位でアセットを読み込む内部メソッド。
  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _assets.clear();
      _hasMore = true;
    }

    // 読み込むべきページがない場合は、これ以上データがないと判断
    if (_allPhotosPath == null || _nextPageToLoad == null || _nextPageToLoad! < 0) {
      _hasMore = false;
      return;
    }

    final int pageToLoad = _nextPageToLoad!;
    // 指定したページのAssetEntityのリストを取得
    final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize,
    );

    if (reset) {
      // リフレッシュの場合は、取得したリストをそのままセット
      _assets.addAll(pageList);
    } else {
      // 追加読み込みの場合は、既存のリストの「先頭」に挿入（古い写真を追加するため）
      _assets.insertAll(0, pageList);
    }

    // 読み込んだページが最初のページ(index 0)だった場合、これ以上古いデータはない
    _hasMore = pageToLoad > 0;

    // 次に読み込むべきページのインデックスを更新
    _nextPageToLoad = pageToLoad - 1;
  }

  /// ローディング状態を設定し、リスナーに通知するヘルパーメソッド。
  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }
}