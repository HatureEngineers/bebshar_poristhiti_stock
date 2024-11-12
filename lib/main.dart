import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_wrapper.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'totals_reset_helper.dart'; // Import TotalsResetHelper

// Flutter local notifications plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  // Initialize locale data for Bangladesh
  await initializeDateFormatting('bn_BD', null);

  WidgetsFlutterBinding.ensureInitialized();

  await initializeFirebase(); // Initialize Firebase
  await TotalsResetHelper.checkAndResetTotals(); // Check and reset totals
  await initializeNotification(); // Initialize local notifications
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // Set background handler for FCM

  runApp(MyApp());
}

// Function to initialize Firebase
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// FCM background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    showLocalNotification(message.notification!); // Show local notification
  }
}

// Initialize local notifications
Future<void> initializeNotification() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create notification channel (required for Android 8.0 and above)
  await createNotificationChannel();
}

// Function to create Notification Channel
Future<void> createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // Channel ID
    'High Importance Notifications', // Channel Name
    description:
    'This channel is used for high importance notifications.', // Channel Description
    importance: Importance.high, // Notification importance
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// Show local notification
Future<void> showLocalNotification(RemoteNotification notification) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'high_importance_channel', // Channel ID
    'High Importance Notifications', // Channel Name
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    platformChannelSpecifics,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    final logger = Logger();

    // Request notification permission
    FirebaseMessaging.instance.requestPermission();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        showLocalNotification(notification); // Show local notification
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Retrieve FCM token
    FirebaseMessaging.instance.getToken().then((String? token) {
      logger.i("FCM Token: $token"); // Use logger instead of print
    });
  }

  // Method to toggle theme
  void toggleTheme() {
    setState(() {
      isDarkTheme = !isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My App',
      theme: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: AuthWrapper(toggleTheme: toggleTheme, isDarkTheme: isDarkTheme),
    );
  }
}
