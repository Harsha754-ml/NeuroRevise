import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'memoryforge_recall_channel';
  static const String _channelName = 'Memory Recall Alerts';
  static const String _channelDescription = 'High-priority recall reminders from MemoryForge';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(NotificationDetail)? _onNotificationTap;

  Future<void> initialize({void Function(NotificationDetail)? onTap}) async {
    _onNotificationTap = onTap;

    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  void setOnTapHandler(void Function(NotificationDetail)? onTap) {
    _onNotificationTap = onTap;
  }

  Future<void> showMemoryAlert(NotificationDetail notification) async {
    if (!_initialized) {
      await initialize();
    }

    final notificationId = notification.notificationId.hashCode.abs() % 2147483647;

    final title = 'Memory Recall Required';
    final body = '${notification.topicName} • ${notification.question}';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        color: const Color(0xFFC5A059),
        ticker: 'MemoryForge Alert',
      ),
    );

    await _plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode(_toPayload(notification)),
    );
  }

  static Future<void> _onDidReceiveBackgroundNotificationResponse(NotificationResponse response) async {
    // No-op for now; foreground callback handles in-app navigation.
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final detail = NotificationDetail.fromJson(decoded);
      _onNotificationTap?.call(detail);
    } catch (_) {
      // Silently ignore malformed payloads.
    }
  }

  Map<String, dynamic> _toPayload(NotificationDetail notification) {
    return {
      'notification_id': notification.notificationId,
      'flashcard_id': notification.flashcardId,
      'topic_name': notification.topicName,
      'question': notification.question,
      'retention_score': notification.retentionScore,
      'urgency_level': notification.urgencyLevel,
      'action': notification.action,
      'audio_url': notification.audioUrl,
      'summary_text': notification.summaryText,
    };
  }
}
