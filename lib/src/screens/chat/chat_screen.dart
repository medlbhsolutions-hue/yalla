import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../services/phone_call_service.dart';

/// Écran de chat en temps réel entre Patient et Chauffeur
class ChatScreen extends StatefulWidget {
  final String rideId;
  final String currentUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserPhone;
  final bool isDriver;

  const ChatScreen({
    required this.rideId,
    required this.currentUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserPhone,
    this.isDriver = false,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messagesSubscription;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  /// Charge l'historique des messages
  Future<void> _loadMessages() async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('ride_id', widget.rideId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// S'abonne aux nouveaux messages en temps réel
  void _subscribeToMessages() {
    _messagesSubscription = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('ride_id', widget.rideId)
        .order('created_at', ascending: true)
        .listen((data) {
          if (mounted) {
            setState(() {
              _messages = List<Map<String, dynamic>>.from(data);
            });
            _scrollToBottom();
            _markMessagesAsRead();
          }
        });
  }

  /// Marque les messages comme lus
  Future<void> _markMessagesAsRead() async {
    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('ride_id', widget.rideId)
          .neq('sender_id', widget.currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('⚠️ Erreur marquage messages lus: $e');
    }
  }

  /// Envoie un message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _supabase.from('chat_messages').insert({
        'ride_id': widget.rideId,
        'sender_id': widget.currentUserId,
        'message': text,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ Erreur envoi message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi du message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// Scroll vers le bas
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Envoie un message rapide prédéfini
  void _sendQuickMessage(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: widget.otherUserAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.otherUserAvatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          widget.isDriver ? Icons.person : Icons.local_taxi,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      widget.isDriver ? Icons.person : Icons.local_taxi,
                      color: AppColors.primary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.isDriver ? 'Patient' : 'Chauffeur',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              if (widget.otherUserPhone != null && widget.otherUserPhone!.isNotEmpty) {
                PhoneCallService.showCallDialog(
                  context: context,
                  phoneNumber: widget.otherUserPhone!,
                  contactName: widget.otherUserName,
                  role: widget.isDriver ? 'patient' : 'chauffeur',
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Numéro de téléphone non disponible'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),

          // Messages rapides
          _buildQuickMessages(),

          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envoyez un message pour commencer\nla conversation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['sender_id'] == widget.currentUserId;
    final createdAt = DateTime.tryParse(message['created_at'] ?? '');
    final timeString = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message['message'] ?? '',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : Colors.grey[500],
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message['is_read'] == true
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: message['is_read'] == true
                            ? Colors.lightBlueAccent
                            : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildQuickMessages() {
    final quickMessages = widget.isDriver
        ? [
            'Je suis en route 🚗',
            'Je suis arrivé 📍',
            'Je vous attends devant',
            '5 minutes ⏱️',
          ]
        : [
            'J\'arrive ! 🏃',
            'Où êtes-vous ? 📍',
            'Pouvez-vous m\'appeler ?',
            'Merci ! 🙏',
          ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: quickMessages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: InkWell(
              onTap: () => _sendQuickMessage(quickMessages[index]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  quickMessages[index],
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Écrivez un message...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
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
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
