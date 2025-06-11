import 'package:flutter/material.dart';
import '../utils/TColorTheme.dart';
import '../services/incident_service.dart';
import '../models/incident_model.dart';
import 'discussion_page.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final IncidentService _incidentService = IncidentService();
  List<Incident> _incidents = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }

      final incidents = await _incidentService.getAllIncidents();

      if (mounted) {
        setState(() {
          _incidents = incidents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load incidents: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshIncidents() async {
    await _loadIncidents();
  }

  String _getIncidentIcon(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'accident':
        return '🚗';
      case 'violence':
        return '⚠️';
      case 'rescue':
        return '🚑';
      case 'hdb_facilities':
        return '🏢';
      case 'mrt':
        return '🚇';
      default:
        return '📍';
    }
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

  String _truncateDescription(String? description, int maxLength) {
    if (description == null || description.isEmpty) {
      return 'No description provided';
    }

    if (description.length <= maxLength) {
      return description;
    }

    return '${description.substring(0, maxLength)}...';
  }

  Widget _buildIncidentCard(Incident incident) {
    final firstImageUrl = incident.firstImageUrl;
    final title = incident.title;
    final description = incident.description;
    final incidentType = incident.incident;
    final location = incident.location;
    final displayName = incident.displayName;
    final datetime = incident.createdAt ?? incident.datetime;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiscussionPage(incident: incident),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image on the left
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child:
                    firstImageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            firstImageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey.shade600,
                                    size: 30,
                                  ),
                                ),
                          ),
                        )
                        : Container(
                          decoration: BoxDecoration(
                            color: TColorTheme.getIncidentColor(incidentType),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _getIncidentIcon(incidentType),
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
              ),

              const SizedBox(width: 12),

              // Content on the right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Incident type and time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: TColorTheme.getIncidentColor(incidentType),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            incidentType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Verified badge if incident has 3+ reports
                        if (incident.totalReports >= 3) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDateTime(datetime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Title with verification info
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Show verification count if verified
                    if (incident.totalReports >= 3) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Verified by ${incident.totalReports} reports',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Truncated description
                    Text(
                      _truncateDescription(description, 100),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Location and user info
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'by $displayName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _error,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshIncidents,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
        : _incidents.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No incidents reported yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to report an incident!',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        )
        : RefreshIndicator(
          onRefresh: _refreshIncidents,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _incidents.length,
            itemBuilder: (context, index) {
              return _buildIncidentCard(_incidents[index]);
            },
          ),
        );
  }
}
