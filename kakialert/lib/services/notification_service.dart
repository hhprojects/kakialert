import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthService _authService = AuthService();
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final Map<String, dynamic> _serviceAccount = {
      "type": dotenv.env['SERVICE_ACCOUNT_TYPE'],
      "project_id": dotenv.env['PROJECT_ID'],
      "private_key_id": dotenv.env['PRIVATE_KEY_ID'],
      "private_key": dotenv.env['PRIVATE_KEY']?.replaceAll(r'\n', '\n'),
      "client_email": dotenv.env['CLIENT_EMAIL'],
      "client_id": dotenv.env['CLIENT_ID'],
      "auth_uri": dotenv.env['AUTH_URI'],
      "token_uri": dotenv.env['TOKEN_URI'],
      "auth_provider_x509_cert_url": dotenv.env['AUTH_PROVIDER_CERT_URL'],
      "client_x509_cert_url": dotenv.env['CLIENT_CERT_URL'],
      "universe_domain": dotenv.env['UNIVERSE_DOMAIN'],
    };


  // Available incident types for subscription
  static const Map<String, String> incidentTypes = {
    'medical': 'Medical Emergencies',
    'fire': 'Fire Incidents',
    'accident': 'Traffic Accidents',
    'violence': 'Violence & Crime',
    'rescue': 'Rescue Operations',
    'hdb_facilities': 'HDB Facilities',
    'mrt': 'MRT Disruptions',
    'others': 'Other Incidents',
  };

  /// Initialize Firebase Messaging and Local Notifications
  static Future<void> initialize() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
        
        // Get FCM token
        await _updateFCMToken();
        
        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen(_updateFCMToken);
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background message taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
        
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Initialize Local Notifications
  static Future<void> _initializeLocalNotifications() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleLocalNotificationTap(response);
      },
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'kakialert_incidents',
      'Incident Alerts',
      description: 'Notifications for emergency incidents',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle local notification tap
  static void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      print('Local notification tapped with payload: $payload');
      // TODO: Navigate to incident details using the payload
    }
  }

  /// Update FCM token in user's Firestore document
  static Future<void> _updateFCMToken([String? token]) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token updated: ${fcmToken.substring(0, 20)}...');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 FOREGROUND MESSAGE RECEIVED');
    print('🔔 Title: ${message.notification?.title}');
    print('🔔 Body: ${message.notification?.body}');
    print('🔔 Data: ${message.data}');
    
    // Extract incident data if available
    if (message.data['incidentId'] != null) {
      print('🔔 Incident notification: ${message.data['incidentId']} at ${message.data['location']}');
    }
    
    // ALWAYS show system notification when app is in foreground
    print('🔔 Displaying notification in system drawer...');
    _showLocalNotification(message);
  }

  /// Show local notification in system notification drawer
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      print('🔔 Preparing local notification...');
      print('🔔 FCM notification exists: ${notification != null}');
      
      // Use FCM notification data if available, otherwise create from data
      final title = notification?.title ?? data['title'] ?? 'Emergency Alert';
      final body = notification?.body ?? data['body'] ?? 'New incident reported';
      
      print('🔔 Final title: $title');
      print('🔔 Final body: $body');

      // Create notification details with enhanced settings
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'kakialert_incidents',
          'Incident Alerts',
          channelDescription: 'Notifications for emergency incidents',
        importance: Importance.max, // Changed to max for better visibility
        priority: Priority.max,     // Changed to max for better visibility
          playSound: true,
        enableVibration: true,      // Added vibration
        enableLights: true,         // Added LED lights
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFF44336), // Red color for emergency alerts
          ticker: 'Emergency Alert',
        autoCancel: false,          // Don't auto-dismiss
        ongoing: false,             // Not persistent
        showWhen: true,             // Show timestamp
        category: AndroidNotificationCategory.alarm, // Emergency category
        );

        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        interruptionLevel: InterruptionLevel.critical, // Critical for iOS
        );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        // Create payload with incident data
        final payload = data.isNotEmpty ? _createNotificationPayload(data) : null;
      
      // Generate unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      print('🔔 Notification ID: $notificationId');

        // Show the notification
        await _localNotifications.show(
        notificationId,
        title,
        body,
          notificationDetails,
          payload: payload,
        );

      print('✅ Local notification displayed in system drawer with ID: $notificationId');
      
    } catch (e) {
      print('❌ Error showing local notification: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  /// Create notification payload from FCM data
  static String _createNotificationPayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Handle message tap (when app opens from notification)
  static void _handleMessageTap(RemoteMessage message) {
    print('Message tapped: ${message.notification?.title}');
    // Navigate to specific incident if data contains incident ID
    if (message.data['incidentId'] != null) {
      // TODO: Navigate to incident details
      print('Navigate to incident: ${message.data['incidentId']}');
    }
  }

  /// Subscribe to specific incident type
  static Future<bool> subscribeToIncidentType(String incidentType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return false;

      // Subscribe to FCM topic
      await _messaging.subscribeToTopic('incident_$incidentType');
      print('✅ Subscribed to FCM topic: incident_$incidentType');
      
      // Update user preferences in Firestore
      await _updateUserSubscriptions(currentUser.uid, incidentType, true);
      
      print('✅ Subscribed to incident type: $incidentType');
      return true;
    } catch (e) {
      print('❌ Error subscribing to incident type: $e');
      return false;
    }
  }

  /// Unsubscribe from specific incident type
  static Future<bool> unsubscribeFromIncidentType(String incidentType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return false;

      // Unsubscribe from FCM topic
      await _messaging.unsubscribeFromTopic('incident_$incidentType');
      
      // Update user preferences in Firestore
      await _updateUserSubscriptions(currentUser.uid, incidentType, false);
      
      print('Unsubscribed from incident type: $incidentType');
      return true;
    } catch (e) {
      print('Error unsubscribing from incident type: $e');
      return false;
    }
  }

  /// Update user subscription preferences in Firestore
  static Future<void> _updateUserSubscriptions(String userId, String incidentType, bool isSubscribed) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      if (isSubscribed) {
        await userRef.update({
          'subscriptions.$incidentType': true,
          'lastSubscriptionUpdate': FieldValue.serverTimestamp(),
        });
      } else {
        await userRef.update({
          'subscriptions.$incidentType': FieldValue.delete(),
          'lastSubscriptionUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating user subscriptions: $e');
    }
  }

  /// Get user's current subscriptions
  static Future<Map<String, bool>> getUserSubscriptions() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return {};

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final data = userDoc.data();
      
      if (data != null && data['subscriptions'] != null) {
        final subscriptions = Map<String, dynamic>.from(data['subscriptions']);
        return subscriptions.map((key, value) => MapEntry(key, value == true));
      }
      
      return {};
    } catch (e) {
      print('Error getting user subscriptions: $e');
      return {};
    }
  }

  /// Send notification for new incident using FCM REST API
  static Future<void> sendIncidentNotification({
    required String incidentType,
    required String title,
    required String location,
    required String incidentId,
  }) async {
    try {
      print('🔔 STARTING NOTIFICATION: incidentType=$incidentType, title=$title');
      print('🔔 Sending to topic: incident_$incidentType');
      
      // Send to topic (users subscribed to this incident type)
      final success = await _sendToTopic(
        topic: 'incident_$incidentType',
        title: title,
        body: 'Emergency incident reported at $location',
        data: {
          'incidentId': incidentId,
          'incidentType': incidentType,
          'location': location,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      if (success) {
        print('✅ Notification sent successfully for incident type: $incidentType');
      } else {
        print('❌ Failed to send notification for incident type: $incidentType');
      }
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  /// Get OAuth 2.0 access token for Firebase HTTP v1 API
  static Future<String?> _getAccessToken() async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(_serviceAccount);
      final client = await clientViaServiceAccount(
        credentials, 
        ['https://www.googleapis.com/auth/firebase.messaging']
      );
      return client.credentials.accessToken.data;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  /// Send notification to a specific FCM topic using HTTP v1 API
  static Future<bool> _sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      print('🔑 Getting access token...');
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('⚠️ Failed to get access token');
        return false;
      }
      print('✅ Access token obtained: ${accessToken.substring(0, 20)}...');

      final projectId = _serviceAccount['project_id'];
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
             final messageBody = {
          'message': {
            'topic': topic,
            'notification': {
              'title': title,
              'body': body,
            },
          'data': {
            ...?data,
            'title': title,  // Include title in data for foreground handling
            'body': body,    // Include body in data for foreground handling
          },
            'android': {
              'priority': 'high',
              'notification': {
                'sound': 'default',
                'notification_priority': 'PRIORITY_HIGH',
              'default_sound': true,
              'default_vibrate_timings': true,
              'default_light_settings': true,
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                'alert': {
                  'title': title,
                  'body': body,
                },
              },
            },
          },
        },
      };
      
      print('📡 Sending FCM request to: $url');
      print('📋 Topic: $topic');
      print('📋 Title: $title');
      print('📋 Body: $body');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(messageBody),
      );

      print('📨 FCM Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ FCM Response: $responseData');
        return true;
      } else {
        print('❌ FCM Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('🚨 Error sending FCM notification: $e');
      return false;
    }
  }

  /// Send notification to a specific user using their FCM token
  static Future<bool> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null || userData['fcmToken'] == null) {
        print('No FCM token found for user: $userId');
        return false;
      }

      final fcmToken = userData['fcmToken'] as String;
      return await _sendToToken(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('Error sending notification to user: $e');
      return false;
    }
  }

  /// Send notification to a specific FCM token
  static Future<bool> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('⚠️ Failed to get access token');
        return false;
      }

      final projectId = _serviceAccount['project_id'];
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data ?? {},
            'android': {
              'priority': 'high',
              'notification': {
                'sound': 'default',
                'notification_priority': 'PRIORITY_HIGH',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                },
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('FCM Response: $responseData');
        return true;
      } else {
        print('FCM Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
      return false;
    }
  }

  /// Check if user is subscribed to specific incident type
  static Future<bool> isSubscribedTo(String incidentType) async {
    final subscriptions = await getUserSubscriptions();
    return subscriptions[incidentType] ?? false;
  }

  /// Get count of user's active subscriptions
  static Future<int> getSubscriptionCount() async {
    final subscriptions = await getUserSubscriptions();
    return subscriptions.values.where((isSubscribed) => isSubscribed).length;
  }

  /// Test notification functionality (for debugging)
  static Future<void> sendTestNotification() async {
    try {
      print('🧪 Sending test notification...');
      
      // First try local notification with enhanced settings
      await _localNotifications.show(
        999, // Test ID
        'Test Notification',
        'This is a test notification to verify the system is working',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kakialert_incidents',
            'Incident Alerts',
            channelDescription: 'Notifications for emergency incidents',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFF44336),
            ticker: 'Test Alert',
            autoCancel: false,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
      print('✅ Local test notification sent');
      
      // Then try FCM test if user is logged in
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final success = await sendToUser(
          userId: currentUser.uid,
          title: 'FCM Test',
          body: 'This is a Firebase Cloud Messaging test',
          data: {'test': 'true', 'timestamp': DateTime.now().toIso8601String()},
        );
        
        if (success) {
          print('✅ FCM test notification sent');
        } else {
          print('❌ FCM test notification failed');
        }
      } else {
        print('⚠️ No user logged in, skipping FCM test');
      }
    } catch (e) {
      print('❌ Test notification error: $e');
    }
  }

  /// Force show notification (for testing foreground notifications)
  static Future<void> forceShowNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      print('🔔 FORCE SHOWING NOTIFICATION');
      print('🔔 Title: $title');
      print('🔔 Body: $body');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'kakialert_incidents',
        'Incident Alerts',
        channelDescription: 'Notifications for emergency incidents',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFF44336),
        ticker: 'Emergency Alert',
        autoCancel: false,
        showWhen: true,
        category: AndroidNotificationCategory.alarm,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: data != null ? _createNotificationPayload(data.cast<String, dynamic>()) : null,
      );

      print('✅ Force notification displayed with ID: $notificationId');
      
    } catch (e) {
      print('❌ Error force showing notification: $e');
    }
  }

  /// Send test notification to all users subscribed to a specific incident type
  static Future<void> sendTestNotificationToTopic(String incidentType) async {
    try {
      print('🧪 Sending test notification to topic: incident_$incidentType');
      
      final success = await _sendToTopic(
        topic: 'incident_$incidentType',
        title: 'Test Alert: ${incidentTypes[incidentType] ?? incidentType}',
        body: 'This is a test notification for $incidentType incidents. If you receive this, notifications are working!',
        data: {
          'test': 'true',
          'incidentType': incidentType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (success) {
        print('✅ Test notification sent to topic: incident_$incidentType');
      } else {
        print('❌ Failed to send test notification to topic');
      }
    } catch (e) {
      print('❌ Topic test notification error: $e');
    }
  }

  /// Check notification setup and permissions
  static Future<Map<String, dynamic>> checkNotificationSetup() async {
    Map<String, dynamic> status = {};
    
    try {
      // Check FCM permission
      final settings = await _messaging.getNotificationSettings();
      status['fcm_permission'] = settings.authorizationStatus.toString();
      
      // Check FCM token
      final token = await _messaging.getToken();
      status['fcm_token_exists'] = token != null;
      status['fcm_token_preview'] = token?.substring(0, 20) ?? 'null';
      status['fcm_token_full'] = token ?? 'null';
      
      // Check user subscriptions
      final subscriptions = await getUserSubscriptions();
      status['active_subscriptions'] = subscriptions.length;
      status['subscription_details'] = subscriptions;
      
      // Check current user
      final currentUser = _authService.currentUser;
      status['user_logged_in'] = currentUser != null;
      status['user_id'] = currentUser?.uid;
      
      // Check if FCM token is saved in Firestore
      if (currentUser != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          final userData = userDoc.data();
          status['firestore_fcm_token'] = userData?['fcmToken']?.substring(0, 20) ?? 'null';
          status['tokens_match'] = userData?['fcmToken'] == token;
          status['last_token_update'] = userData?['lastTokenUpdate']?.toString() ?? 'never';
        } catch (e) {
          status['firestore_check_error'] = e.toString();
        }
      }
      
      print('📊 COMPREHENSIVE NOTIFICATION SETUP STATUS:');
      status.forEach((key, value) {
        print('  $key: $value');
      });
      
    } catch (e) {
      status['error'] = e.toString();
      print('❌ Error checking notification setup: $e');
    }
    
    return status;
  }

  /// Force refresh FCM token and update Firestore
  static Future<bool> refreshFCMToken() async {
    try {
      print('🔄 Refreshing FCM token...');
      
      // Delete existing token and get new one
      await _messaging.deleteToken();
      final newToken = await _messaging.getToken();
      
      if (newToken != null) {
        print('✅ New FCM token: ${newToken.substring(0, 20)}...');
        await _updateFCMToken(newToken);
        return true;
      } else {
        print('❌ Failed to get new FCM token');
        return false;
      }
    } catch (e) {
      print('❌ Error refreshing FCM token: $e');
      return false;
    }
  }

  /// Test complete notification flow
  static Future<void> testCompleteNotificationFlow() async {
    try {
      print('🧪 STARTING COMPLETE NOTIFICATION TEST');
      
      // Step 1: Check setup
      final setupStatus = await checkNotificationSetup();
      print('📊 Setup Status: ${setupStatus.keys.length} items checked');
      
      // Step 2: Refresh token if needed
      if (setupStatus['tokens_match'] != true) {
        print('🔄 Tokens don\'t match, refreshing...');
        await refreshFCMToken();
      }
      
      // Step 3: Test local notification
      print('🔔 Testing local notification...');
      await sendTestNotification();
      
      // Step 4: Test FCM if subscribed to something
      final subscriptions = await getUserSubscriptions();
      final subscribedTypes = subscriptions.entries.where((e) => e.value).map((e) => e.key).toList();
      
      if (subscribedTypes.isNotEmpty) {
        print('🌐 Testing FCM notification to topic: ${subscribedTypes.first}');
        await sendTestNotificationToTopic(subscribedTypes.first);
      } else {
        print('⚠️ No subscriptions found. Subscribe to an incident type first.');
      }
      
      print('✅ Complete notification test finished');
      
    } catch (e) {
      print('❌ Complete notification test error: $e');
    }
  }
} 