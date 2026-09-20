import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../utils/formatters.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'credit_card_reminders';
  static const String channelName = 'Credit Card Reminders';
  static const String channelDesc =
      'Notifications for credit card bill generation and payment due dates';

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(initSettings);

      // Create Android channel
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.high,
          ),
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error displaying notification: $e');
    }
  }

  /// Checks credit cards against current date and triggers bill generation or due date notifications
  Future<void> checkAndNotifyCards(List<BankAccount> accounts) async {
    if (!_isInitialized) await initialize();

    final now = DateTime.now();
    final todayDay = now.day;

    for (final card in accounts) {
      if (card.accountType != 'credit_card' || !card.autoNotifyBill) continue;

      final cardName = card.name;
      final debt = card.balance;

      // 1. Bill Generation Day check
      if (card.billingCycleDay != null && card.billingCycleDay == todayDay) {
        if (debt > 0) {
          final billAmt = card.lastBillAmount ?? debt;
          await showNotification(
            id: card.id * 100 + 1,
            title: '$cardName Bill Generated',
            body:
                'Your bill of ${Formatters.currency(billAmt)} is generated today. Due date is on the ${card.paymentDueDay ?? "scheduled"}th.',
          );
        }
      }

      // 2. Due Date Reminder check (3 days before due date or on due date)
      if (card.paymentDueDay != null && debt > 0) {
        final dueDay = card.paymentDueDay!;
        int daysUntilDue = dueDay - todayDay;
        // Handle month wrapping if due day is early next month
        if (daysUntilDue < 0) {
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          daysUntilDue = (daysInMonth - todayDay) + dueDay;
        }

        if (daysUntilDue == 3) {
          await showNotification(
            id: card.id * 100 + 2,
            title: '$cardName Payment Due in 3 Days',
            body:
                'Reminder: Your outstanding balance of ${Formatters.currency(debt)} is due in 3 days. Pay now to avoid charges.',
          );
        } else if (daysUntilDue == 0) {
          await showNotification(
            id: card.id * 100 + 3,
            title: '$cardName Payment Due Today',
            body:
                'Your credit card payment of ${Formatters.currency(debt)} is due today. Tap to clear your bill.',
          );
        }
      }
    }
  }
}
