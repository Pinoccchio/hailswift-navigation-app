import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'; // For Android 13+ permissions
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationHandler {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationHandler() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  // Exposed initialization method
  void initializeNotifications() {
    // Use default Android notification icon
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher'); // Use default launcher icon

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones(); // Initialize time zones
  }


  // Request permission for notifications (Android 13+ and iOS)
  Future<void> requestNotificationPermissions() async {
    // Request permission for Android 13+ devices
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Handle iOS notification permissions (optional, if targeting iOS)
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Schedule notification for 30 minutes before deadline
  Future<void> scheduleTaskReminderNotification(String taskId, String taskTitle, DateTime deadline) async {
    final tz.TZDateTime reminderTime = tz.TZDateTime.from(deadline.subtract(Duration(minutes: 30)), tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'task_channel_id',
      'Task Reminders',
      channelDescription: 'Reminders for tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId.hashCode,
      'Task Reminder',
      'Your task "$taskTitle" is due in 30 minutes!',
      reminderTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Immediate notification for missed task
  Future<void> showMissedTaskNotification(String taskTitle) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'missed_task_channel_id',
      'Missed Tasks',
      channelDescription: 'Notifications for missed tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Missed Task',
      'Your task "$taskTitle" has been missed!',
      platformChannelSpecifics,
    );
  }

  // Immediate notification for completed task
  Future<void> showTaskCompletedNotification(String taskTitle) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'completed_task_channel_id',
      'Completed Tasks',
      channelDescription: 'Notifications for completed tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      1, // Notification ID
      'Task Completed', // Title
      'You have completed the task "$taskTitle"!', // Body with the task title dynamically inserted
      platformChannelSpecifics,
    );
  }

  // Immediate notification for welcome message
  Future<void> showWelcomeNotification(String userName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'welcome_channel_id',
      'Welcome Messages',
      channelDescription: 'Notifications for welcoming users',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      2, // Notification ID
      'Welcome to HailSwift',
      'Hello, $userName!',
      platformChannelSpecifics,
    );
  }


}
