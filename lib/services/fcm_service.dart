import 'package:firebase_messaging/firebase_messaging.dart';
import 'firestore_service.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirestoreService _firestore = FirestoreService();

  static Future<void> initialize() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _firestore.saveFcmToken(token);
      } catch (_) {}
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await _firestore.saveFcmToken(newToken);
      } catch (_) {}
    });

    FirebaseMessaging.onMessage.listen((message) {
      print('Foreground notification: ${message.notification?.title}');
    });
  }
}