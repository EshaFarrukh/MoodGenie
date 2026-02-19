import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('❌ No user logged in. Showing welcome message.');
      _addWelcomeMessage();
      setState(() => _isLoading = false);
      return;
    }

    print('📥 Loading chat history for user: $uid');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: false)
          .limit(50)
          .get();

      print('📊 Found ${snapshot.docs.length} messages in Firestore');

      if (snapshot.docs.isEmpty) {
        print('💬 No chat history found. Adding welcome message.');
        _addWelcomeMessage();
      } else {
        setState(() {
          _messages.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _messages.add(ChatMessage(
              text: data['message'] ?? '',
              isUser: data['isUser'] ?? false,
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            ));
          }
        });
        print('✅ Loaded ${_messages.length} messages successfully');
      }
    } catch (e) {
      print('❌ Error loading chat history: $e');
      _addWelcomeMessage();
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _addWelcomeMessage() {
    final welcomeMsg = ChatMessage(
      text: "Hello! I'm MoodGenie, your AI companion. How are you feeling today? 💜",
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMsg);
    });

    // Save welcome message to Firestore
    _saveMessageToFirestore(welcomeMsg);
  }

  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('❌ ERROR: User not authenticated. Cannot save message.');
      return;
    }

    print('💾 Saving message to Firestore...');
    print('   User ID: $uid');
    print('   Message: ${message.text}');
    print('   Is User: ${message.isUser}');

    try {
      final docRef = await FirebaseFirestore.instance.collection('chats').add({
        'userId': uid,
        'message': message.text,
        'isUser': message.isUser,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Message saved successfully! Document ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error saving message: $e');
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    final userChatMessage = ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userChatMessage);
      _isTyping = true;
    });

    // Save user message to Firestore
    _saveMessageToFirestore(userChatMessage);

    _messageController.clear();
    _scrollToBottom();

    // Simulate AI response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final aiResponse = ChatMessage(
          text: _generateResponse(userMessage),
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(aiResponse);
          _isTyping = false;
        });

        // Save AI response to Firestore
        _saveMessageToFirestore(aiResponse);

        _scrollToBottom();
      }
    });
  }

  String _generateResponse(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('sad') || lowerMessage.contains('down') || lowerMessage.contains('depressed')) {
      return "I'm sorry you're feeling this way. Remember, it's okay to have difficult days. Would you like to talk about what's making you feel sad? I'm here to listen. 💙";
    } else if (lowerMessage.contains('happy') || lowerMessage.contains('great') || lowerMessage.contains('good')) {
      return "That's wonderful to hear! I'm so glad you're feeling good. What's been bringing you joy today? 😊";
    } else if (lowerMessage.contains('anxious') || lowerMessage.contains('worried') || lowerMessage.contains('stress')) {
      return "Anxiety can be overwhelming. Try taking a few deep breaths with me. Remember, you've handled difficult moments before, and you can handle this too. What's on your mind? 🌸";
    } else if (lowerMessage.contains('help')) {
      return "I'm here to support you! You can:\n• Log your daily mood\n• Track your emotional patterns\n• Talk to me anytime\n• View your mood analytics\n\nHow can I help you today? 💜";
    } else if (lowerMessage.contains('thank')) {
      return "You're very welcome! I'm always here for you. Remember, taking care of your mental health is a sign of strength. 🌟";
    } else {
      return "I hear you. Tell me more about how you're feeling. I'm here to listen and support you through whatever you're experiencing. 💜";
    }
  }

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/moodgenie_bg.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B7FD8).withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B7FD8), Color(0xFF6B5CFF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B5CFF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MoodGenie AI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D2545),
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: Color(0xFF4CAF50),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D6689),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: Show chat options
                      },
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF8B7FD8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Messages
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B7FD8),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF8B7FD8).withOpacity(0.15),
                                    const Color(0xFF6B5CFF).withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: Color(0xFF8B7FD8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Start a conversation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D2545),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share how you\'re feeling today',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),

            // Input area
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE5DEFF).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2D2545),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B7FD8), Color(0xFF6B5CFF)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B5CFF).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B7FD8), Color(0xFF6B5CFF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF8B7FD8), Color(0xFF6B5CFF)],
                      )
                    : null,
                color: message.isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? const Color(0xFF6B5CFF).withOpacity(0.3)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: message.isUser ? Colors.white : const Color(0xFF2D2545),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFFFD39B),
              child: Icon(
                Icons.person,
                size: 18,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B7FD8), Color(0xFF6B5CFF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, -4 * (0.5 - (value - 0.5).abs()) * 2),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF8B7FD8),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

