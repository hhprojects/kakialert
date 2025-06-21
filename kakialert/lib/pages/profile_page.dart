import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakialert/pages/landing_page.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/TColorTheme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  Map<String, bool> _userSubscriptions = {};
  String? _selectedTestIncidentType;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSubscriptions();
  }

  Future<void> _loadUserData() async {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      final userData = await _authService.getUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
        });
      }
    }
  }

  Future<void> _loadSubscriptions() async {
    final subscriptions = await NotificationService.getUserSubscriptions();
    if (mounted) {
      setState(() {
        _userSubscriptions = subscriptions;
      });
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: TColorTheme.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSubscription(String incidentType, bool currentValue) async {
    try {
      bool success;
      if (currentValue) {
        success = await NotificationService.unsubscribeFromIncidentType(incidentType);
      } else {
        success = await NotificationService.subscribeToIncidentType(incidentType);
      }

      if (success) {
        await _loadSubscriptions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentValue 
                  ? 'Unsubscribed from ${NotificationService.incidentTypes[incidentType]}'
                  : 'Subscribed to ${NotificationService.incidentTypes[incidentType]}',
              ),
              backgroundColor: TColorTheme.primaryOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TColorTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColorTheme.lightGray,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColorTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentUser != null) ...[
                      Text('Email: ${_currentUser!.email}'),
                      Text('UID: ${_currentUser!.uid}'),
                      if (_userData != null) ...[
                        Text('Name: ${_userData!['name'] ?? 'Not set'}'),
                        Text('Phone: ${_userData!['phoneNumber'] ?? 'Not set'}'),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Notification Subscriptions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔔 Notification Subscriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColorTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage which types of incidents you want to receive notifications for.',
                      style: TextStyle(color: TColorTheme.gray),
                    ),
                    const SizedBox(height: 16),
                    
                    ...NotificationService.incidentTypes.entries.map((entry) {
                      final isSubscribed = _userSubscriptions[entry.key] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TColorTheme.lightGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(entry.value),
                          subtitle: Text('incident_${entry.key}'),
                          value: isSubscribed,
                          onChanged: (value) => _toggleSubscription(entry.key, isSubscribed),
                          activeColor: TColorTheme.primaryOrange,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Logout Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColorTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColorTheme.primaryRed,
                          foregroundColor: TColorTheme.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(TColorTheme.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Signing out...'),
                              ],
                            )
                          : const Text('Logout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // Debug Section for Notifications
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 Notification Debug',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColorTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Test and debug notification functionality.',
                      style: TextStyle(color: TColorTheme.gray),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await NotificationService.sendTestNotification();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent! Check console logs.'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            icon: const Icon(Icons.notification_add),
                            label: const Text('Test Notification'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final status = await NotificationService.checkNotificationSetup();
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Notification Status'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: status.entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(color: Colors.black),
                                              children: [
                                                TextSpan(
                                                  text: '${entry.key}: ',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                TextSpan(text: '${entry.value}'),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info),
                            label: const Text('Check Status'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Force notification test
                    ElevatedButton.icon(
                      onPressed: () async {
                        await NotificationService.forceShowNotification(
                          title: 'Panic as Smoke Engulfs Building (Verified Report)',
                          body: 'Emergency Alert reported at 10 Bayfront Ave, Singapore 018956, Singapore',
                          data: {'test': 'foreground', 'timestamp': DateTime.now().toIso8601String()},
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Force notification sent! Should appear in notification drawer.'),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      },
                      icon: const Icon(Icons.notification_important),
                      label: const Text('Force Foreground Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Topic Test Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Test Topic Notifications',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send test notifications to ALL users subscribed to an incident type:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Incident Type',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  value: _selectedTestIncidentType,
                                  items: NotificationService.incidentTypes.entries.map((entry) {
                                    return DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTestIncidentType = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectedTestIncidentType != null
                                      ? () async {
                                          await NotificationService.sendTestNotificationToTopic(_selectedTestIncidentType!);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Test sent to ${NotificationService.incidentTypes[_selectedTestIncidentType]} subscribers!'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Send', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // DEBUG: Notification Debugging Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 Notification Debugging',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColorTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use these tools to debug notification issues.',
                      style: TextStyle(color: TColorTheme.gray),
                    ),
                    const SizedBox(height: 16),
                    
                    // Check Setup Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Checking notification setup... Check console for details.'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                          final status = await NotificationService.checkNotificationSetup();
                          print('🔍 Setup check completed: ${status.keys.length} items');
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Check Notification Setup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Refresh Token Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing FCM token...'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          final success = await NotificationService.refreshFCMToken();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'FCM token refreshed successfully' : 'Failed to refresh FCM token'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh FCM Token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Complete Test Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Running complete notification test... Check console for details.'),
                              backgroundColor: Colors.purple,
                            ),
                          );
                          await NotificationService.testCompleteNotificationFlow();
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run Complete Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}