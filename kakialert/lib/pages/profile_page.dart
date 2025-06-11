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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}