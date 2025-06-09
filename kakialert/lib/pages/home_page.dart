import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakialert/pages/form_photo_page.dart';
import '../utils/TColorTheme.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';
import '../models/incident_model.dart';
import 'discussion_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final IncidentService _incidentService = IncidentService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  List<Incident> _latestIncidents = [];
  bool _isLoadingIncidents = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLatestIncidents();
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

  Future<void> _loadLatestIncidents() async {
    try {
      final incidents = await _incidentService.getAllIncidents();
      // Sort by creation date (most recent first) and take top 3
      incidents.sort((a, b) {
        final aTime = a.createdAt ?? a.datetime ?? DateTime.now();
        final bTime = b.createdAt ?? b.datetime ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      
      if (mounted) {
        setState(() {
          _latestIncidents = incidents.take(3).toList();
          _isLoadingIncidents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIncidents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColorTheme.lightGray,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: TColorTheme.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('images/logo.png', width: 50, height: 50),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Welcome,',
                        style: TextStyle(
                          fontSize: 16,
                          color: TColorTheme.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userData?['displayName'] ?? _currentUser?.displayName ?? 'Username',
                        style: TextStyle(
                          fontSize: 16,
                          color: TColorTheme.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.warning,
                    iconColor: TColorTheme.white,
                    backgroundColor: TColorTheme.primaryOrange,
                    title: 'Submit',
                    subtitle: 'Incidents',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FormPhotoPage()));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.location_on,
                    iconColor: TColorTheme.white,
                    backgroundColor: TColorTheme.primaryBlue,
                    title: 'Today\'s',
                    subtitle: 'Incidents',
                    onTap: () {
                      // TODO: Navigate to today's incidents page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Today\'s Incidents clicked')),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Latest Forums Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest Forums',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TColorTheme.primaryBlue,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to forums page
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: TColorTheme.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Forum Posts
            _isLoadingIncidents
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _latestIncidents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No recent incidents to display',
                            style: TextStyle(
                              color: TColorTheme.gray,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: _latestIncidents.asMap().entries.map((entry) {
                          final index = entry.key;
                          final incident = entry.value;
                          return Column(
                            children: [
                              _buildForumPost(incident: incident),
                              if (index < _latestIncidents.length - 1) 
                                const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 32),

            // Latest News Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest News',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TColorTheme.primaryBlue,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to news page
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: TColorTheme.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // News Card
            _buildNewsCard(
              imageUrl: '', // Will use placeholder
              title: '5 taken to hospital after blaze at fire sets Toa Payoh HDFb store',
              time: 'Dec 3, 2024, 9:36 PM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TColorTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumPost({required Incident incident}) {
    final category = incident.incident;
    final categoryColor = TColorTheme.getIncidentColor(category);
    final title = incident.title;
    final content = incident.description.isNotEmpty 
        ? incident.description 
        : 'No description provided';
    final time = _formatDateTime(incident.createdAt ?? incident.datetime);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionPage(incident: incident),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TColorTheme.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: TColorTheme.gray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            
            // Content
            Text(
              content,
              style: TextStyle(
                fontSize: 12,
                color: TColorTheme.gray,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: TColorTheme.gray,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    incident.location,
                    style: TextStyle(
                      fontSize: 11,
                      color: TColorTheme.gray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Actions
            Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: TColorTheme.gray,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to join discussion',
                  style: TextStyle(
                    fontSize: 12,
                    color: TColorTheme.gray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? datetime) {
    if (datetime == null) return 'Unknown time';
    
    try {
      final now = DateTime.now();
      final difference = now.difference(datetime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${datetime.day}/${datetime.month}/${datetime.year}';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Widget _buildNewsCard({
    required String imageUrl,
    required String title,
    required String time,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: TColorTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: TColorTheme.gray.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Icon(
              Icons.image,
              size: 50,
              color: TColorTheme.gray,
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: TColorTheme.gray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 