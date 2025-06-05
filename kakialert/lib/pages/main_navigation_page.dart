import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakialert/pages/landing_page.dart';
import 'package:kakialert/pages/home_page.dart';
import 'package:kakialert/pages/map_page.dart';
import 'package:kakialert/pages/forum_page.dart';
import 'package:kakialert/pages/profile_page.dart';
import 'package:kakialert/services/auth_service.dart';
import '../utils/TColorTheme.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  int _currentIndex = 0;

  // List of pages for bottom navigation
  final List<Widget> _pages = [
    const HomePage(),
    const MapPage(),
    const ForumPage(),
    const ProfilePage(),
  ];

  // List of page titles
  final List<String> _pageTitles = [
    'KakiAlert',
    'Maps',
    'Community Forum',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColorTheme.lightGray,
      appBar:
          _currentIndex ==
                  1 // index of MapPage
              ? null
              : AppBar(
                title: Text(_pageTitles[_currentIndex]),
                backgroundColor: TColorTheme.primaryRed,
                foregroundColor: TColorTheme.white,
                elevation: 0,
                actions: [
                  IconButton(
                    onPressed: _isLoading ? null : _showLogoutDialog,
                    icon:
                        _isLoading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  TColorTheme.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.logout),
                    tooltip: 'Logout',
                  ),
                ],
              ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: TColorTheme.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: TColorTheme.white,
          selectedItemColor: TColorTheme.primaryOrange,
          unselectedItemColor: TColorTheme.gray,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
            BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forum'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
