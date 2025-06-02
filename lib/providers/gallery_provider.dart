import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider extends ChangeNotifier {
  final List<AssetEntity> _assets = [];
  bool _loading = false, _noAccess = false;
  int _page = 0;
  static const _pageSize = 100;

  late AssetPathEntity _recent;

  List<AssetEntity> get assets  => _assets;
  bool get loading    => _loading;
  bool get noAccess   => _noAccess;

  Future<void> init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      _noAccess = true;
      notifyListeners();
      return;
    }
    _noAccess = false;

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.all,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: true)],
      ),
    );
    _recent = paths.first;

    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      if (reset) {
        _assets.clear();
        _page = 0;
      }

      final pageAssets = await _recent.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );

      _assets.addAll(pageAssets);
      _page++;
    } catch (e) {
      debugPrint('Failed to load page: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreIfNeeded(int index) async {
    if (!_loading && index >= _assets.length - 20) {
      await _loadPage();
    }
  }

  Future<void> refresh() => _loadPage(reset: true);
  Future<void> openSetting() => PhotoManager.openSetting();
}
