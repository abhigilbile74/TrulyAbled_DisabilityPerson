import 'dart:html' as html;

class MedicineNotificationService {
  Future<void> initialize() async {
    // Browsers require permission to be requested after a user action.
  }

  Future<bool> requestPermission() async {
    try {
      final permission = await html.Notification.requestPermission();
      return permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    // Web reminders are checked by the screen while the app tab is open.
    // Browsers cannot guarantee reminders after the tab/browser is closed.
  }

  Future<void> cancel(int id) async {}

  Future<void> showNow({
    required String title,
    required String body,
  }) async {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      } else {
        await requestPermission();
        if (html.Notification.permission == 'granted') {
          html.Notification(title, body: body);
        }
      }
    } catch (_) {
      // The screen still displays an in-app alert if browser notifications fail.
    }
  }
}
