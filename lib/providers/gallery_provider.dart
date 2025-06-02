// lib/providers/gallery_provider.dart

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider extends ChangeNotifier {
  /// 読み込み中フラグ
  bool _loading = false;

  /// アクセス拒否フラグ（権限なし）
  bool _noAccess = false;

  /// 取得済みの AssetEntity（常に時間昇順：古い→新しい）
  final List<AssetEntity> _assets = [];

  /// ページサイズ（1ページあたり何件読み込むか）
  final int _pageSize = 100;

  /// “現状取得しているページ番号”（末尾ページ = _lastPageIndex から始めて、0 までデクリメントしていく）
  int? _currentPage;

  /// 全画像数から計算される「最後のページ番号」
  int? _lastPageIndex;

  /// まだ「古い方のページ」が残っているか
  bool _hasMore = true;

  /// AssetPathEntity("すべての写真") への参照
  AssetPathEntity? _allPhotosPath;

  bool get loading => _loading;
  bool get noAccess => _noAccess;

  /// 読み込まれた AssetEntity リスト
  List<AssetEntity> get assets => List.unmodifiable(_assets);

  /// 写真アクセス権限設定画面を開く
  void openSetting() {
    PhotoManager.openSetting();
  }

  /// 初期化：権限リクエスト→パス取得→最後のページ（最新）から最初のページを1つだけ取得
  Future<void> init() async {
    // 1) 権限リクエスト
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      _noAccess = true;
      notifyListeners();
      return;
    }

    // 2) "すべての写真" のパスリストを取得（作成日：昇順にソート。先頭が古い・末尾が新しい）
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: true, // 昇順（古いものが先、最後尾が最新）
          ),
        ],
      ),
    );

    if (paths.isEmpty) {
      // 写真が一切ない場合
      _noAccess = false;
      _hasMore = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return;
    }

    // "すべての写真" パスを格納
    _allPhotosPath = paths.first;

    // 取得可能な総画像数を得る
    final int totalCount = await _allPhotosPath!.assetCountAsync;

    // “最後のページ”のインデックスを計算（0始まり）
    // 例：totalCount = 250, pageSize = 100 → pages = 3 → lastPageIndex = 2
    final int pageCount = (totalCount / _pageSize).ceil();
    _lastPageIndex = pageCount - 1;
    _currentPage = _lastPageIndex;

    // 最後のページ＝最新の画像リストだけを読み込む
    await _loadPage(reset: true);
  }

  /// 必要に応じて「古い方のページ」を追加読み込みするトリガー
  void loadMoreIfNeeded(int index) {
    if (!_hasMore || _loading) return;

    // リストの「先頭 10 件」に来たら次の古いページを読み込む
    if (index <= 10) {
      _loadPage();
    }
  }

  /// ページ単位での読み込み処理（reset = true なら最初の呼び出し、false なら古いページを追加取得）
  Future<void> _loadPage({bool reset = false}) async {
    if (_loading || _allPhotosPath == null || _currentPage == null) return;
    _loading = true;

    if (reset) {
      // リセットモード：初期化時。_currentPage はすでに lastPageIndex にセット済み
      _assets.clear();
      _hasMore = true;
    }

    // _currentPage のページを読み込む
    final int pageToLoad = _currentPage!;
    final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize,
    );

    // もし取得件数 < pageSize なら、もうそれより古いページはない
    if (pageList.length < _pageSize || pageToLoad == 0) {
      _hasMore = false;
    }

    // “古い→新しい” 順序を保つために、取得結果自体は先頭が「そのページの最古」, 末尾が「そのページの最新」。
    // reset==true の場合はリスト全体として最後尾が最新になるため、そのまま _assets に追加
    if (reset) {
      _assets.addAll(pageList);
    } else {
      // reset==false（古い方を追加）＝ページは「pageToLoad < lastPageIndex」 → 取得したリストはpageToLoad の昇順リスト
      // これを「既存リストの先頭」に挿入して、全体で昇順（古い→新しい）のまま保持する
      _assets.insertAll(0, pageList);
    }

    // 次に読むべきページをひとつ古い方へデクリメント
    _currentPage = pageToLoad - 1;

    _loading = false;

    // ビルド中に notifyListeners() を呼ばないため、次フレームで更新を通知する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// 削除などでリフレッシュが必要になった場合、全ページをリセットして最新ページから再読み込み
  Future<void> refresh() async {
    if (_allPhotosPath == null || _lastPageIndex == null) return;
    _currentPage = _lastPageIndex;
    _assets.clear();
    _hasMore = true;
    await _loadPage(reset: true);
  }
}
