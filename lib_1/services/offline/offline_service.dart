class OfflineService {
  static final OfflineService instance = OfflineService._init();
  OfflineService._init();

  Future<void> initialize() async {}
  Future<bool> isOnline() async => true;
  Future<void> syncData() async {}
}
