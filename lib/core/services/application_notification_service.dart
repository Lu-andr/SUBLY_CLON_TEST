import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ApplicationNotificationService {
  static const _nativeNotifications = MethodChannel(
    'com.zaim.mobile/notifications',
  );
  static const dailyNotificationId = 2544;
  static const verificationNotificationId = 2545;
  static const verificationChannelId = 'subly_verification';
  static const verificationChannelName = 'Коды подтверждения';
  static const verificationChannelDescription =
      'Коды подтверждения заявки Sumly';
  static const verificationChannel = AndroidNotificationChannel(
    verificationChannelId,
    verificationChannelName,
    description: verificationChannelDescription,
    importance: Importance.high,
    enableVibration: true,
  );
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestSoundPermission: true,
            requestBadgePermission: true,
            defaultPresentAlert: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
            defaultPresentSound: true,
          ),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(verificationChannel);
    } on Object {
      // Notifications are helpful but never block the application flow.
    }
  }

  Future<bool> showVerificationCode(String code) async {
    if (kIsWeb) return false;
    try {
      if (!await _requestNotificationPermission()) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _nativeNotifications.invokeMethod<bool>(
              'showVerificationCode',
              {'code': code},
            ) ??
            false;
      }
      await _plugin.cancel(id: verificationNotificationId);
      // Give iOS enough time to finish the permission sheet/route animation;
      // otherwise an immediate foreground notification may be swallowed.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await _plugin.show(
        id: verificationNotificationId,
        title: 'Sumly · код подтверждения',
        body: 'Ваш код: $code',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            verificationChannelId,
            verificationChannelName,
            channelDescription: verificationChannelDescription,
            icon: 'ic_notification',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
      return true;
    } on Object {
      // The confirmation screen displays the code when Android cannot show it.
      return false;
    }
  }

  Future<bool> openNotificationSettings() => openAppSettings();

  Future<bool> _requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final nativeResult = await android?.requestNotificationsPermission();
      if (nativeResult != null) return nativeResult;
    }
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> startDailyNotifications() async {
    if (kIsWeb) return;
    try {
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isLimited) return;
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: dailyNotificationId,
        title: 'Sumly напоминает',
        body: 'Проверьте новые предложения и контролируйте регулярные расходы.',
        scheduledDate: first,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'subly_daily',
            'Ежедневные напоминания',
            channelDescription: 'Ежедневные полезные напоминания Sumly',
            icon: 'ic_notification',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on Object {
      // Missing permissions or platform support must not change navigation.
    }
  }

  Future<void> cancelDailyNotifications() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: dailyNotificationId);
    } on Object {
      // Keep moderator navigation independent of notification availability.
    }
  }
}
