class MedicineNotificationService {
  Future<void> initialize() async {}
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {}
  Future<void> cancel(int id) async {}
  Future<void> showNow({
    required String title,
    required String body,
  }) async {}
}
