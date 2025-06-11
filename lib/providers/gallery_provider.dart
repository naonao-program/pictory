import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider extends ChangeNotifier {
  /// 読み込み中フラグ
  bool _loading = false;

  /// アクセス拒否フラグ
  bool _noAccess = false;

  /// 取得済みの AssetEntity（常に昇順：古い→新しい）
  final List<AssetEntity> _assets = [];

  /// 1ページあたりの読み込み件数
  final int _pageSize = 100;

  /// 次に読み込むべき「ページ番号」。
  int? _currentPage;

  /// 全ページのうち「最後（最新側）のページ番号」を保持
  int? _lastPageIndex;

  /// まだ「古い方のページ」が残っているか
  bool _hasMore = true;

  /// "すべての写真" パスへの参照
  AssetPathEntity? _allPhotosPath;

  /// 外部から参照用：読み込まれた AssetEntity のリストを返す
  List<AssetEntity> get assets => List.unmodifiable(_assets);

  /// 読み込み中フラグ
  bool get loading => _loading;

  /// 権限がない状態か
  bool get noAccess => _noAccess;

  /// まだ古い写真が残っているか
  bool get hasMore => _hasMore;

  /// 権限設定画面を開く
  void openSetting() {
    PhotoManager.openSetting();
  }

  /// 初期化：権限を取って「最後（最新）」のページだけ読み込み
  Future<void> init() async {
    // 1) 権限リクエスト
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      _noAccess = true;
      notifyListeners();
      return;
    }

    // 2) "すべての写真" のパスを取得（作成日を昇順でソート）
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: true, // ★ 昇順（古い→新しい）に戻す
          ),
        ],
      ),
    );

    if (paths.isEmpty) {
      _noAccess = false;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _allPhotosPath = paths.first;

    // 総画像数を取得して「最後のページ番号」を計算
    final int totalCount = await _allPhotosPath!.assetCountAsync;
    if (totalCount == 0) {
      _hasMore = false;
      notifyListeners();
      return;
    }
    final int pageCount = (totalCount / _pageSize).ceil();
    _lastPageIndex = pageCount - 1;
    _currentPage = _lastPageIndex; // まずは最新ページ＝lastPageIndex を読み込む

    // 最新のページだけを読み込み
    await _loadPage(reset: true);
    notifyListeners();
  }

  /// スクロール位置に応じて、さらに古いページを読み込む
  Future<void> loadMoreIfNeeded() async {
    if (_loading || !_hasMore) return;
    await _loadPage();
    notifyListeners();
  }

  /// ページ単位での読み込み処理
  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    if (_allPhotosPath == null || _currentPage == null || _currentPage! < 0) {
      _hasMore = false;
      return;
    }

    _loading = true;
    if (!reset) {
      notifyListeners();
    }

    if (reset) {
      _assets.clear();
      _hasMore = true;
      _currentPage = _lastPageIndex; // リセット時は最新ページから
    }

    final int pageToLoad = _currentPage!;
    final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize,
    );
    
    _loading = false;

    if (reset) {
      _assets.addAll(pageList);
    } else {
      _assets.insertAll(0, pageList); // 古い写真をリストの先頭に追加
    }

    if (pageToLoad == 0) {
      _hasMore = false;
    }

    _currentPage = pageToLoad - 1; // 次はさらに古いページを読み込む
  }

  /// 全件リフレッシュ
  Future<void> refresh() async {
    if (_allPhotosPath == null || _lastPageIndex == null) return;
    await _loadPage(reset: true);
    notifyListeners();
  }
}
