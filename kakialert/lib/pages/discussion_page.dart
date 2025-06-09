import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incident_model.dart';
import '../models/discussion_model.dart';
import '../services/discussion_service.dart';
import '../services/auth_service.dart';
import '../utils/TColorTheme.dart';

class DiscussionPage extends StatefulWidget {
  final Incident incident;

  const DiscussionPage({super.key, required this.incident});

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final DiscussionService _discussionService = DiscussionService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<DiscussionMessage> _messages = [];
  Map<String, List<DiscussionMessage>> _replies = {};
  Map<String, bool> _expandedReplies = {};
  bool _isLoading = true;
  bool _isSending = false;
  String? _replyingToId;
  String? _replyingToUser;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);
      
      final messages = await _discussionService.getTopLevelMessages(widget.incident.id!);
      
      // Load replies for each message
      Map<String, List<DiscussionMessage>> replies = {};
      for (final message in messages) {
        if (message.replyCount > 0) {
          final messageReplies = await _discussionService.getReplies(message.id!);
          replies[message.id!] = messageReplies;
        }
      }
      
      setState(() {
        _messages = messages;
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    try {
      setState(() => _isSending = true);

      final userData = await _authService.getUserData();
      final displayName = userData?['displayName'] ?? _currentUser!.email ?? 'Anonymous';

      final message = DiscussionMessage(
        incidentId: widget.incident.id!,
        senderId: _currentUser!.uid,
        senderName: displayName,
        senderEmail: _currentUser!.email ?? '',
        message: _messageController.text.trim(),
        parentMessageId: _replyingToId,
      );

      await _discussionService.createMessage(message);
      
      _messageController.clear();
      _clearReply();
      await _loadMessages();
      
      // Scroll to bottom to show new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _replyToMessage(DiscussionMessage message) {
    setState(() {
      _replyingToId = message.id;
      _replyingToUser = message.senderName;
    });
    
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToUser = null;
    });
  }

  void _toggleReplies(String messageId) {
    setState(() {
      _expandedReplies[messageId] = !(_expandedReplies[messageId] ?? false);
    });
  }

  Future<void> _toggleLike(DiscussionMessage message) async {
    if (_currentUser == null) return;

    try {
      await _discussionService.toggleLike(message.id!, _currentUser!.uid);
      await _loadMessages();
    } catch (e) {
      _showErrorSnackBar('Failed to toggle like: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildMessageCard(DiscussionMessage message, {bool isReply = false}) {
    final isCurrentUser = _currentUser?.uid == message.senderId;
    final hasReplies = _replies[message.id] != null && _replies[message.id]!.isNotEmpty;
    final isExpanded = _expandedReplies[message.id] ?? false;
    
    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 32 : 16,
        right: 16,
        bottom: 8,
      ),
      child: Card(
        elevation: isReply ? 1 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info and timestamp
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: TColorTheme.getIncidentColor(widget.incident.incident),
                    child: Text(
                      message.senderName.isNotEmpty 
                          ? message.senderName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isCurrentUser ? Colors.blue : Colors.black87,
                          ),
                        ),
                        Text(
                          message.timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (message.isEdited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'edited',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Message content
              Text(
                message.message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Action buttons
              Row(
                children: [
                  // Like button
                  InkWell(
                    onTap: () => _toggleLike(message),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.isLikedBy(_currentUser?.uid ?? '')
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: message.isLikedBy(_currentUser?.uid ?? '')
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                          if (message.likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${message.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Reply button
                  if (!isReply)
                    InkWell(
                      onTap: () => _replyToMessage(message),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // View replies button
                  if (hasReplies && !isReply)
                    InkWell(
                      onTap: () => _toggleReplies(message.id!),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_replies[message.id]!.length} ${_replies[message.id]!.length == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              
              // Show replies if expanded
              if (hasReplies && isExpanded && !isReply) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...(_replies[message.id]!.map((reply) => _buildMessageCard(reply, isReply: true))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColorTheme.getIncidentColor(widget.incident.incident).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TColorTheme.getIncidentColor(widget.incident.incident),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.incident.incident.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                widget.incident.createdAt != null 
                    ? _formatDateTime(widget.incident.createdAt!)
                    : 'Unknown time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.incident.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (widget.incident.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.incident.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.incident.location,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Text(
                'by ${widget.incident.displayName}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Reply indicator
          if (_replyingToId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to $_replyingToUser',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _clearReply,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Message input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _replyingToId != null 
                          ? 'Write a reply...'
                          : 'Join the discussion...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _messageController.text.trim().isEmpty 
                        ? Colors.grey.shade300
                        : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime datetime) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Incident header
            _buildIncidentHeader(),
            
            // Messages list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? SingleChildScrollView(
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.4,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to start the discussion!',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageCard(_messages[index]);
                          },
                        ),
            ),
            
            // Message input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }
}
