import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:moodgenie/src/services/backend_api_client.dart';
import 'package:moodgenie/src/services/app_telemetry_service.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _chatHistoryPageSize = 50;
  static const int _chatHistoryFetchLimit = 250;
  static const int _maxPromptHistoryMessages = 6;
  static const int _maxPromptHistoryCharacters = 1200;
  static const int _maxPromptAssistantMessageLength = 240;
  static const int _maxPromptUserMessageLength = 320;
  static const Duration _healthRetryDelay = Duration(seconds: 8);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final BackendApiClient _backendClient = BackendApiClient();
  bool _isTyping = false;
  bool _isLoading = true;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = false;
  String? _lastReportedAiStatus;
  String? _historyError;
  Timer? _healthRetryTimer;
  bool _healthCheckInFlight = false;
  int _loadedHistoryCount = 0;

  // AI connection status
  String _aiStatus = 'connecting';

  @override
  void initState() {
    super.initState();
    _initializeBackend();
    _loadChatHistory();
  }

  Future<void> _initializeBackend() async {
    await _backendClient.getBaseUrl(refresh: true);
    await _checkBackendHealth();
  }

  void _scheduleHealthRetry({bool immediate = false}) {
    _healthRetryTimer?.cancel();
    final delay = immediate ? Duration.zero : _healthRetryDelay;
    _healthRetryTimer = Timer(delay, () {
      unawaited(_checkBackendHealth());
    });
  }

  void _setAiStatus(String status) {
    if (!mounted) {
      return;
    }
    if (_lastReportedAiStatus != status &&
        (status == 'degraded' || status == 'fallback' || status == 'crisis')) {
      _lastReportedAiStatus = status;
      unawaited(
        AppTelemetryService.instance.trackEvent(
          'chat.ai_status_changed',
          attributes: {'status': status},
        ),
      );
    } else if (status == 'connected') {
      _lastReportedAiStatus = status;
    }
    setState(() {
      _aiStatus = status;
    });
  }

  Future<void> _checkBackendHealth() async {
    if (_healthCheckInFlight) {
      return;
    }
    _healthCheckInFlight = true;
    try {
      final data = await _backendClient.getJson(
        '/api/health',
        timeout: const Duration(seconds: 5),
      );

      if (!mounted) return;

      if (data['ok'] == true) {
        _healthRetryTimer?.cancel();
        _setAiStatus('connected');
        return;
      }

      _setAiStatus('degraded');
      _scheduleHealthRetry();
    } catch (_) {
      _setAiStatus('degraded');
      _scheduleHealthRetry();
    } finally {
      _healthCheckInFlight = false;
    }
  }

  Future<void> _loadChatHistory() async {
    await _loadChatHistoryPage(refresh: true);
  }

  DateTime _resolveChatTimestamp(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    if (timestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    }
    if (timestamp is String) {
      final parsed = DateTime.tryParse(timestamp);
      if (parsed != null) {
        return parsed;
      }
    }

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    if (createdAt is DateTime) {
      return createdAt;
    }
    if (createdAt is num) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt.toInt());
    }
    if (createdAt is String) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) {
        return parsed;
      }
    }

    final sentAt = data['sentAt'];
    if (sentAt is Timestamp) {
      return sentAt.toDate();
    }
    if (sentAt is DateTime) {
      return sentAt;
    }
    if (sentAt is num) {
      return DateTime.fromMillisecondsSinceEpoch(sentAt.toInt());
    }
    if (sentAt is String) {
      final parsed = DateTime.tryParse(sentAt);
      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.now();
  }

  String _resolveChatText(Map<String, dynamic> data) {
    final directMessage = data['message'];
    if (directMessage is String && directMessage.trim().isNotEmpty) {
      return directMessage.trim();
    }
    if (directMessage is num || directMessage is bool) {
      return directMessage.toString();
    }

    final legacyText = data['text'];
    if (legacyText is String && legacyText.trim().isNotEmpty) {
      return legacyText.trim();
    }
    if (legacyText is num || legacyText is bool) {
      return legacyText.toString();
    }

    final body = data['body'];
    if (body is String && body.trim().isNotEmpty) {
      return body.trim();
    }
    if (body is num || body is bool) {
      return body.toString();
    }

    return '';
  }

  ChatMessage _mapChatDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ChatMessage(
      text: _resolveChatText(data),
      isUser: data['isUser'] == true,
      timestamp: _resolveChatTimestamp(data),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchSortedChatDocs(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('userId', isEqualTo: uid)
        .limit(_chatHistoryFetchLimit)
        .get();

    final docs = snapshot.docs.toList(growable: true);
    docs.sort((left, right) {
      final comparison = _resolveChatTimestamp(
        right.data(),
      ).compareTo(_resolveChatTimestamp(left.data()));
      if (comparison != 0) {
        return comparison;
      }
      return right.id.compareTo(left.id);
    });
    return docs;
  }

  Future<void> _loadChatHistoryPage({required bool refresh}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }
      setState(() {
        _isLoading = false;
        _hasMoreHistory = false;
        _historyError = null;
      });
      return;
    }

    if (refresh) {
      setState(() {
        _isLoading = true;
        _historyError = null;
        _loadedHistoryCount = 0;
        _hasMoreHistory = false;
      });
    } else {
      if (_isLoadingMoreHistory || !_hasMoreHistory) {
        return;
      }
      setState(() => _isLoadingMoreHistory = true);
    }

    try {
      final sortedDocs = await _fetchSortedChatDocs(uid);
      final startIndex = refresh ? 0 : _loadedHistoryCount;
      final endIndex = (startIndex + _chatHistoryPageSize).clamp(
        0,
        sortedDocs.length,
      );
      final pageDocs = startIndex >= sortedDocs.length
          ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : sortedDocs.sublist(startIndex, endIndex);

      final pageMessages = pageDocs.reversed
          .map(_mapChatDocument)
          .where((message) => message.text.trim().isNotEmpty)
          .toList(growable: false);
      final welcomeMessage = refresh && pageMessages.isEmpty
          ? ChatMessage(
              text:
                  "Hello! I'm MoodGenie, your AI companion. How are you feeling today? 💜",
              isUser: false,
              timestamp: DateTime.now(),
            )
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _historyError = null;
        _loadedHistoryCount = endIndex;
        _hasMoreHistory = sortedDocs.length > _loadedHistoryCount;

        if (refresh) {
          _messages
            ..clear()
            ..addAll(pageMessages);
        } else {
          _messages.insertAll(0, pageMessages);
        }

        if (welcomeMessage != null) {
          _messages.add(welcomeMessage);
          _hasMoreHistory = false;
        }
      });
      if (welcomeMessage != null) {
        _saveMessageToFirestore(welcomeMessage);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _historyError = refresh
            ? 'We could not load your saved chat history right now.'
            : 'We could not load older messages right now.';
        if (refresh && _messages.isEmpty) {
          _hasMoreHistory = false;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMoreHistory = false;
        });
        if (refresh) {
          _scrollToBottom();
        }
      }
    }
  }

  void _addWelcomeMessage({bool persist = true}) {
    final welcomeMsg = ChatMessage(
      text:
          "Hello! I'm MoodGenie, your AI companion. How are you feeling today? 💜",
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMsg);
    });

    if (persist) {
      _saveMessageToFirestore(welcomeMsg);
    }
  }

  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'userId': uid,
        'message': message.text,
        'isUser': message.isUser,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  List<Map<String, String>> _buildRecentHistoryForPrompt() {
    final promptMessages = <Map<String, String>>[];
    var totalCharacters = 0;

    final historySource = _messages.length > 1
        ? _messages.sublist(0, _messages.length - 1)
        : <ChatMessage>[];

    for (final message in historySource.reversed) {
      final trimmed = message.text.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final maxLength = message.isUser
          ? _maxPromptUserMessageLength
          : _maxPromptAssistantMessageLength;

      if (!message.isUser && trimmed.length > maxLength) {
        continue;
      }

      final content = trimmed.length > maxLength
          ? trimmed.substring(0, maxLength)
          : trimmed;
      final nextTotal = totalCharacters + content.length;
      if (nextTotal > _maxPromptHistoryCharacters) {
        continue;
      }

      promptMessages.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': content,
      });
      totalCharacters = nextTotal;

      if (promptMessages.length >= _maxPromptHistoryMessages) {
        break;
      }
    }

    return promptMessages.reversed.toList(growable: false);
  }

  Widget _buildHistoryStatusCard() {
    if (_isLoadingMoreHistory) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_historyError != null && _messages.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Column(
            children: [
              Text(
                _historyError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.headingDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _loadChatHistoryPage(refresh: false),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry older messages'),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasMoreHistory) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () => _loadChatHistoryPage(refresh: false),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Load earlier messages'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showFallbackReply(String message, {String? details}) {
    final aiResponse = ChatMessage(
      text: _generateFallbackResponse(message),
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiResponse);
      _isTyping = false;
    });
    _setAiStatus('fallback');
    _scheduleHealthRetry(immediate: true);

    if (details != null && details.trim().isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(details.trim())));
    }

    _scrollToBottom();
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

    // Generate AI response via backend
    _generateAiResponse(userMessage);
  }

  Future<void> _generateAiResponse(String message) async {
    try {
      final data = await _backendClient.postJson(
        '/api/chat',
        body: {
          'userMessage': message,
          'history': _buildRecentHistoryForPrompt(),
        },
        timeout: const Duration(seconds: 75),
      );

      if (!mounted) return;

      final ok = data['ok'] != false;
      final reply = (data['reply'] ?? '').toString().trim();
      final mode = (data['mode'] ?? 'live').toString();
      final details = (data['details'] as String?)?.trim();

      if (!ok || reply.isEmpty) {
        _showFallbackReply(
          message,
          details: details?.isNotEmpty == true
              ? details
              : 'The live AI service is unavailable right now. Responses are coming from the app fallback mode and may be less personalized.',
        );
        return;
      }

      if (mode == 'crisis_override') {
        _setAiStatus('crisis');
      } else {
        _setAiStatus('connected');
      }

      final aiResponse = ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiResponse);
        _isTyping = false;
      });

      _saveMessageToFirestore(aiResponse);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _showFallbackReply(message, details: error.toString());
    }
  }

  Future<void> _handleChatMenuSelection(String action) async {
    switch (action) {
      case 'retry':
        if (!mounted) {
          return;
        }
        _setAiStatus('connecting');
        await _backendClient.getBaseUrl(refresh: true);
        await _checkBackendHealth();
        break;
      case 'clear':
        await _clearConversation();
        break;
    }
  }

  Future<void> _clearConversation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation'),
        content: const Text(
          'This removes your saved AI chat history from this account. A fresh welcome message will be added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('userId', isEqualTo: uid)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.clear();
      _isTyping = false;
      _loadedHistoryCount = 0;
      _hasMoreHistory = false;
      _historyError = null;
    });
    _addWelcomeMessage();
    _scrollToBottom();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Conversation cleared')));
  }

  bool _containsUrduScript(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  bool _looksRomanUrdu(String text) {
    final lowered = text.toLowerCase();
    const markers = [
      'mujhe',
      'mjhe',
      'mjy',
      'mera',
      'meri',
      'mere',
      'tum',
      'aap',
      'main',
      'mein',
      'mai',
      'hai',
      'hun',
      'ho',
      'kya',
      'kyun',
      'q',
      'nahi',
      'nai',
      'nh',
      'bohat',
      'boht',
      'dard',
      'samajh',
      'baat',
      'kr',
      'kar',
      'raha',
      'rahi',
    ];

    var hits = 0;
    for (final marker in markers) {
      if (RegExp(
        '(^|\\s)${RegExp.escape(marker)}(?=\\s|\$)',
      ).hasMatch(lowered)) {
        hits += 1;
      }
    }
    return hits >= 2;
  }

  String _generateRomanUrduFallbackResponse(String message) {
    final lowerMessage = message.toLowerCase().trim();

    if (lowerMessage.contains('mar') ||
        lowerMessage.contains('khudkushi') ||
        lowerMessage.contains('jaan dena') ||
        lowerMessage.contains('apni jaan')) {
      return 'Mujhe bohat afsos hai ke aap is tarah feel kar rahe hain. Agar aap ko lagta hai ke aap khud ko nuqsan pohncha sakte hain ya aap foran danger mein hain, to abhi apni local emergency service ya kisi qareebi bharosemand shakhs se rabta karein. Kya aap is waqt safe hain?';
    }

    if (RegExp(r'^(hi|hey|hello|assalam|salam)').hasMatch(lowerMessage)) {
      return 'Assalam o alaikum! Main MoodGenie hoon. Aap jis zuban mein baat karna chahein, main usi style mein jawab dene ki koshish karunga. Aaj aap kaisa feel kar rahe hain?';
    }

    if (lowerMessage.contains('dard') ||
        lowerMessage.contains('pain') ||
        lowerMessage.contains('foot') ||
        lowerMessage.contains('pair') ||
        lowerMessage.contains('soojan')) {
      return 'Mujhe afsos hai ke aap ko dard ho raha hai. Main doctor nahi hoon, lekin agar dard bohat zyada hai, soojan hai, chalna mushkil ho raha hai, ya dard barhta ja raha hai to foran doctor ya clinic se rabta karein. Agar chahein to bata dein dard kab se hai.';
    }

    if (lowerMessage.contains('sad') ||
        lowerMessage.contains('udas') ||
        lowerMessage.contains('down') ||
        lowerMessage.contains('rona') ||
        lowerMessage.contains('cry')) {
      return 'Mujhe afsos hai ke aap udaas feel kar rahe hain. Aap jo feel kar rahe hain woh important hai. Agar aap chahein to mujhe bata sakte hain ke aaj sab se zyada kis cheez ne aap ko affect kiya.';
    }

    if (lowerMessage.contains('anxious') ||
        lowerMessage.contains('ghabra') ||
        lowerMessage.contains('stress') ||
        lowerMessage.contains('tension') ||
        lowerMessage.contains('panic')) {
      return 'Main samajh sakta hoon ke ghabrahat aur tension bohat heavy feel ho sakti hai. Ek chhota sa step try karein: 4 second saans andar, 4 second hold, phir 6 second bahar. Agar chahein to bata dein is waqt sab se zyada kis baat ki tension hai.';
    }

    if (lowerMessage.contains('thank') || lowerMessage.contains('shukriya')) {
      return 'Aap ka shukriya. Main yahan hoon aur jitna ho sake support karunga. Agar aap chahein to hum araam se baat jaari rakh sakte hain.';
    }

    if (lowerMessage.contains('help')) {
      return 'Main aap ki baat sun sakta hoon, mood support de sakta hoon, aur simple guidance de sakta hoon. Aap jo feel kar rahe hain usay seedha seedha likh dein, main usi hisaab se jawab dunga.';
    }

    return 'Main aap ki baat samajhne ki koshish kar raha hoon. Aap thora aur seedha bata dein ke aap ko kis cheez mein madad chahiye, main simple Roman Urdu mein jawab dunga.';
  }

  String _generateUrduScriptFallbackResponse(String message) {
    final lowerMessage = message.trim();

    if (lowerMessage.contains('مر') ||
        lowerMessage.contains('خودکشی') ||
        lowerMessage.contains('جان')) {
      return 'مجھے بہت افسوس ہے کہ آپ اس طرح محسوس کر رہے ہیں۔ اگر آپ کو لگتا ہے کہ آپ خود کو نقصان پہنچا سکتے ہیں یا آپ فوری خطرے میں ہیں تو ابھی اپنی مقامی ایمرجنسی سروس یا کسی قابلِ اعتماد شخص سے رابطہ کریں۔ کیا آپ اس وقت محفوظ ہیں؟';
    }

    if (lowerMessage.contains('درد') ||
        lowerMessage.contains('پاؤں') ||
        lowerMessage.contains('پیر')) {
      return 'مجھے افسوس ہے کہ آپ کو درد ہو رہا ہے۔ میں ڈاکٹر نہیں ہوں، لیکن اگر درد بہت زیادہ ہے، سوجن ہے، چلنا مشکل ہو رہا ہے، یا درد بڑھ رہا ہے تو فوراً ڈاکٹر یا کلینک سے رابطہ کریں۔ اگر چاہیں تو بتا دیں درد کب سے ہے۔';
    }

    return 'میں آپ کی بات سن رہا ہوں۔ آپ ذرا واضح انداز میں بتا دیں کہ آپ کو کس چیز میں مدد چاہیے، میں سادہ اردو میں جواب دوں گا۔';
  }

  String _generateFallbackResponse(String message) {
    if (_containsUrduScript(message)) {
      return _generateUrduScriptFallbackResponse(message);
    }

    if (_looksRomanUrdu(message)) {
      return _generateRomanUrduFallbackResponse(message);
    }

    final lowerMessage = message.toLowerCase().trim();

    // --- Greetings ---
    if (RegExp(
      r'^(hi|hey|hello|hola|howdy|sup|yo|hii+|assalam|salam)',
    ).hasMatch(lowerMessage)) {
      return "Hey there! 👋 I'm MoodGenie, your wellness companion. How are you feeling today? I'm here to chat, listen, and help you track your emotional well-being. 💜";
    }

    // --- Identity questions ---
    if (lowerMessage.contains('who are you') ||
        lowerMessage.contains('what are you') ||
        lowerMessage.contains('your name') ||
        lowerMessage.contains('about you')) {
      return "I'm MoodGenie 🧞, your AI wellness companion! I'm here to:\n\n• 💬 Chat about how you're feeling\n• 📊 Help you track mood patterns\n• 🧘 Suggest wellness activities\n• 💙 Provide emotional support\n\nI'm not a therapist, but I'm always here to listen! How can I help you today?";
    }

    // --- How are you ---
    if (lowerMessage.contains('how are you') ||
        lowerMessage.contains('how r u') ||
        lowerMessage.contains('hru')) {
      return "I'm doing great, thank you for asking! 😊 But more importantly — how are YOU feeling today? That's what matters most. Tell me about your day! 💜";
    }

    // --- Sadness ---
    if (lowerMessage.contains('sad') ||
        lowerMessage.contains('down') ||
        lowerMessage.contains('depressed') ||
        lowerMessage.contains('unhappy') ||
        lowerMessage.contains('miserable') ||
        lowerMessage.contains('cry')) {
      return "I'm really sorry you're feeling this way. 💙 It's completely okay to feel sad — your feelings are valid.\n\nHere are some things that might help:\n• 🌿 Take a gentle walk outside\n• 📝 Write down 3 things you're grateful for\n• 🎵 Listen to your favorite uplifting song\n• 💬 Talk to someone you trust\n\nWould you like to tell me more about what's on your mind?";
    }

    // --- Happiness ---
    if (lowerMessage.contains('happy') ||
        lowerMessage.contains('great') ||
        lowerMessage.contains('amazing') ||
        lowerMessage.contains('wonderful') ||
        lowerMessage.contains('fantastic') ||
        lowerMessage.contains('excited')) {
      return "That's absolutely wonderful to hear! 🎉😊 Your positive energy is contagious! What's been making you feel so good? I'd love to hear about it — celebrating the good moments is so important for mental wellness! ✨";
    }

    // --- Good/Okay ---
    if (RegExp(
      r"^(good|fine|okay|ok|alright|not bad|pretty good|im good)",
    ).hasMatch(lowerMessage)) {
      return "That's nice to hear! 😊 Even 'okay' days matter. Is there anything specific on your mind today, or would you like to log your mood? I'm here if you want to chat about anything! 💜";
    }

    // --- Anxiety/Stress ---
    if (lowerMessage.contains('anxious') ||
        lowerMessage.contains('worried') ||
        lowerMessage.contains('stress') ||
        lowerMessage.contains('nervous') ||
        lowerMessage.contains('panic') ||
        lowerMessage.contains('overwhelm')) {
      return "I hear you — anxiety can feel so overwhelming. 🌸 Let's try something together:\n\n🧘 **Quick Breathing Exercise:**\n1. Breathe in for 4 seconds\n2. Hold for 4 seconds\n3. Breathe out for 6 seconds\n4. Repeat 3 times\n\nRemember: you've gotten through tough moments before, and you'll get through this too. What's weighing on your mind?";
    }

    // --- Anger ---
    if (lowerMessage.contains('angry') ||
        lowerMessage.contains('mad') ||
        lowerMessage.contains('furious') ||
        lowerMessage.contains('frustrated') ||
        lowerMessage.contains('annoyed') ||
        lowerMessage.contains('irritated')) {
      return "It sounds like you're dealing with some strong emotions right now. 🔥 Anger is a natural response — it's telling you something important.\n\nTry this: take 3 deep breaths, then ask yourself: \"What need of mine isn't being met right now?\"\n\nWould you like to talk about what's frustrating you? Sometimes just venting helps! 💙";
    }

    // --- Loneliness ---
    if (lowerMessage.contains('lonely') ||
        lowerMessage.contains('alone') ||
        lowerMessage.contains('isolated') ||
        lowerMessage.contains('no friends') ||
        lowerMessage.contains('nobody')) {
      return "Feeling lonely is really tough, and I want you to know you're not truly alone. 💜 I'm right here with you.\n\nSome ideas that might help:\n• 📱 Reach out to someone you haven't talked to in a while\n• 🚶 Visit a local café or park\n• 🎯 Join a club or group activity\n• 💬 Keep chatting with me!\n\nYou matter, and your feelings are valid. ✨";
    }

    // --- Sleep ---
    if (lowerMessage.contains('sleep') ||
        lowerMessage.contains('tired') ||
        lowerMessage.contains('exhausted') ||
        lowerMessage.contains('insomnia') ||
        lowerMessage.contains('cant sleep')) {
      return "Sleep is so important for mental health! 😴 Here are some tips:\n\n🌙 **Better Sleep Habits:**\n• Put screens away 30 min before bed\n• Keep your room cool and dark\n• Try a calming routine (reading, tea, stretching)\n• Avoid caffeine after 2 PM\n\nWould you like to talk about what's keeping you up? Sometimes clearing your mind helps. 💜";
    }

    // --- Gratitude/Thanks ---
    if (lowerMessage.contains('thank') ||
        lowerMessage.contains('thanks') ||
        lowerMessage.contains('appreciate')) {
      return "You're so welcome! 🌟 It makes me happy to be here for you. Remember, reaching out and talking about your feelings is a sign of real strength. I'm always here whenever you need me! 💜";
    }

    // --- Help ---
    if (lowerMessage.contains('help') ||
        lowerMessage.contains('what can you do') ||
        lowerMessage.contains('features')) {
      return "I'm here to support your mental wellness! Here's what I can do:\n\n🏠 **Home** — See your daily wellness overview\n😊 **Mood** — Log and track your daily moods\n💬 **Chat** — Talk to me about anything\n👤 **Profile** — View your progress\n\n💡 Try telling me how you feel, and I'll provide personalized support! 💜";
    }

    // --- Motivation ---
    if (lowerMessage.contains('motivat') ||
        lowerMessage.contains('inspire') ||
        lowerMessage.contains('give up') ||
        lowerMessage.contains('hopeless') ||
        lowerMessage.contains('no point')) {
      return "I believe in you, and I want you to believe in yourself too. 💪✨\n\n\"The darkest hour has only sixty minutes.\" — Morris Mandel\n\nEvery step forward counts, no matter how small. You've already shown courage by reaching out. What's one small thing you could do today that would make you feel accomplished? 🌟";
    }

    // --- Relationships ---
    if (lowerMessage.contains('boyfriend') ||
        lowerMessage.contains('girlfriend') ||
        lowerMessage.contains('relationship') ||
        lowerMessage.contains('breakup') ||
        lowerMessage.contains('partner') ||
        lowerMessage.contains('love')) {
      return "Relationships can bring so much joy and sometimes so much pain. 💙 Whatever you're going through, your feelings about it are completely valid.\n\nWould you like to tell me more about what's happening? Sometimes talking it through can help you see things more clearly. I'm here to listen without judgment. 🌸";
    }

    // --- Work/Study ---
    if (lowerMessage.contains('work') ||
        lowerMessage.contains('study') ||
        lowerMessage.contains('exam') ||
        lowerMessage.contains('school') ||
        lowerMessage.contains('college') ||
        lowerMessage.contains('job') ||
        lowerMessage.contains('university')) {
      return "Work and studies can definitely be a source of stress! 📚 Remember to take breaks and be kind to yourself.\n\n🎯 **Quick Productivity Tip:**\nTry the Pomodoro technique: 25 min focused work → 5 min break → repeat!\n\nBalance is key. How are you feeling about things right now? 💜";
    }

    // --- Bye/Goodbye ---
    if (lowerMessage.contains('bye') ||
        lowerMessage.contains('goodbye') ||
        lowerMessage.contains('see you') ||
        lowerMessage.contains('gotta go') ||
        lowerMessage.contains('talk later')) {
      return "Take care of yourself! 🌟 Remember, I'm always here whenever you want to chat. Wishing you a wonderful rest of your day! Come back anytime. 💜✨";
    }

    // --- Yes/No short answers ---
    if (RegExp(
      r'^(yes|yeah|yep|yea|no|nah|nope|maybe)$',
    ).hasMatch(lowerMessage)) {
      return "I understand. Would you like to tell me more about what's on your mind? I'm here to listen and chat about anything you'd like. 😊💜";
    }

    // --- Default conversational response ---
    final defaults = [
      "That's interesting! Tell me more about how that makes you feel. I'm here to listen and support you. 💜",
      "I appreciate you sharing that with me. How is this affecting your mood? Let's talk about it. 😊",
      "Thank you for opening up! Your feelings matter. Would you like to explore this further together? 🌸",
      "I'm listening! Feel free to share as much as you'd like. There's no judgment here. 💙",
    ];
    return defaults[message.length % defaults.length];
  }

  Color _statusDotColor() {
    switch (_aiStatus) {
      case 'connected':
        return const Color(0xFF4CAF50);
      case 'crisis':
        return const Color(0xFFE53935);
      case 'fallback':
        return const Color(0xFFEF6C00);
      case 'degraded':
      case 'connecting':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF6D6689);
    }
  }

  Color _statusTextColor() {
    switch (_aiStatus) {
      case 'connected':
        return const Color(0xFF4CAF50);
      case 'crisis':
        return const Color(0xFFE53935);
      case 'fallback':
        return const Color(0xFF8D4E00);
      default:
        return const Color(0xFF6D6689);
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    switch (_aiStatus) {
      case 'connected':
        return l10n.aiStatusConnected;
      case 'degraded':
        return l10n.aiStatusDegraded;
      case 'fallback':
        return l10n.aiStatusFallback;
      case 'crisis':
        return l10n.aiStatusCrisis;
      default:
        return l10n.aiStatusConnecting;
    }
  }

  Widget? _buildAiStatusBanner(AppLocalizations l10n) {
    switch (_aiStatus) {
      case 'degraded':
        return _buildStatusBanner(
          backgroundColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFE082),
          iconColor: const Color(0xFFF9A825),
          textColor: const Color(0xFF8D6E00),
          message: l10n.aiDegradedBanner,
        );
      case 'fallback':
        return _buildStatusBanner(
          backgroundColor: const Color(0xFFFFF3E0),
          borderColor: const Color(0xFFFFCC80),
          iconColor: const Color(0xFFEF6C00),
          textColor: const Color(0xFF8D4E00),
          message: l10n.aiFallbackBanner,
        );
      case 'crisis':
        return _buildStatusBanner(
          backgroundColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFEF9A9A),
          iconColor: const Color(0xFFC62828),
          textColor: const Color(0xFF8E2424),
          message: l10n.aiCrisisBanner,
        );
      default:
        return null;
    }
  }

  Widget _buildStatusBanner({
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    required String message,
  }) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    _healthRetryTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navReservedHeight = SharedBottomNavigation.reservedHeight(context);
    final statusBanner = _buildAiStatusBanner(l10n);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AppBackground(),
          Column(
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
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.88),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
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
                            colors: [AppColors.primary, AppColors.primaryDeep],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDeep.withValues(
                                alpha: 0.3,
                              ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.aiChatTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D2545),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Semantics(
                              liveRegion: true,
                              label: l10n.aiStatusSemanticLabel(
                                _statusLabel(l10n),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: _statusDotColor(),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _statusLabel(l10n),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _statusTextColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l10n.chatOptionsTooltip,
                        onSelected: _handleChatMenuSelection,
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'retry',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.refresh_rounded),
                              title: Text(l10n.retryAiConnection),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'clear',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.delete_outline_rounded),
                              title: Text(l10n.clearConversation),
                            ),
                          ),
                        ],
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ?statusBanner,

              // Messages
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _messages.isEmpty && _historyError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                size: 52,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                _historyError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.headingDark,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _loadChatHistory,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry history'),
                              ),
                            ],
                          ),
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
                                      AppColors.primary.withValues(alpha: 0.15),
                                      AppColors.primaryDeep.withValues(
                                        alpha: 0.08,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.primary,
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _messages.length + (_isTyping ? 1 : 0) + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildHistoryStatusCard();
                          }
                          final messageIndex = index - 1;
                          if (_isTyping && messageIndex == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(_messages[messageIndex]);
                        },
                      ),
              ),

              // Input area
              Padding(
                padding: EdgeInsets.only(bottom: navReservedHeight),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5DEFF).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
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
                            colors: [AppColors.primary, AppColors.primaryDeep],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDeep.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          tooltip: 'Send message',
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
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
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
                        colors: [AppColors.primary, AppColors.primaryDeep],
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
                        ? AppColors.primaryDeep.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
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
                  color: message.isUser
                      ? Colors.white
                      : const Color(0xFF2D2545),
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
              child: Icon(Icons.person, size: 18, color: Colors.grey[700]),
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
                colors: [AppColors.primary, AppColors.primaryDeep],
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
                  color: Colors.black.withValues(alpha: 0.08),
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
              color: AppColors.primary,
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
