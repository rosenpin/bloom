import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract interface class RestNotificationScheduler {
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

final class RestTimerFoundation {
  const RestTimerFoundation(this._scheduler);

  final RestNotificationScheduler _scheduler;

  Future<void> schedule({
    required int notificationId,
    required DateTime endsAt,
    required int nextSet,
    required String exerciseName,
  }) async {
    await _scheduler.cancel(notificationId);
    await _scheduler.schedule(
      id: notificationId,
      at: endsAt,
      title: "Rest's done.",
      body: 'Set $nextSet of $exerciseName.',
    );
  }

  Future<void> cancel(int notificationId) => _scheduler.cancel(notificationId);
}

final class LocalRestNotificationScheduler
    implements RestNotificationScheduler {
  LocalRestNotificationScheduler(this._plugin, this._clock);

  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;
  bool _initialized = false;
  Future<void>? _initialization;
  final Map<int, int> _generationById = <int, int>{};

  Future<void> _initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    late final Future<void> initialization;
    initialization = _performInitialization().whenComplete(() {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    });
    _initialization = initialization;
    return initialization;
  }

  Future<void> _performInitialization() async {
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    final delay = at.difference(_clock());
    if (delay <= Duration.zero) return;
    final generation = _generationById[id] ?? 0;
    await _initialize();
    if ((_generationById[id] ?? 0) != generation) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Tells you when the next set is ready.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    _generationById[id] = (_generationById[id] ?? 0) + 1;
    if (!_initialized) return;
    await _plugin.cancel(id: id);
  }
}
