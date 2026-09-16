import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/history_service.dart';
import '../../../../services/offline_service.dart';
import '../../../recommendation/bloc/recommendation_bloc.dart';
import '../../../recommendation/models/recommendation_model.dart';
import '../../../recommendation/views/mic_button.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final RecommendationModel? recommendation;
  final DateTime timestamp;
  int? feedback; // null = unrated, 1 = helpful (like), -1 = unhelpful (dislike)

  ChatMessage({
    required this.text,
    required this.isUser,
    this.recommendation,
    DateTime? timestamp,
    this.feedback,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'recommendation': recommendation?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'feedback': feedback,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      recommendation: map['recommendation'] != null
          ? RecommendationModel.fromJson(map['recommendation'])
          : null,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      feedback: map['feedback'] as int?,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const String _chatBoxName = 'murassikh_chat_box';
  late Box<String> _chatBox;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isBoxReady = false;

  String get _currentEmotion {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isUser && _messages[i].recommendation != null) {
        return _messages[i].recommendation!.emotion;
      }
    }
    return 'طبيعي';
  }

  Color _getEmotionColor(BuildContext context, String emotion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = isDark ? 0.05 : 0.08;
    if (['حزن', 'اكتئاب', 'يأس', 'فقد', 'وحدة'].contains(emotion)) {
      return Colors.blue.withValues(alpha: alpha);
    } else if (['غضب', 'عصبية', 'استياء'].contains(emotion)) {
      return Colors.teal.withValues(alpha: alpha);
    } else if (['خوف', 'قلق', 'توتر', 'هلع'].contains(emotion)) {
      return Colors.indigo.withValues(alpha: alpha);
    } else if (['سعادة', 'فرح', 'شكر', 'رضا', 'طمأنينة'].contains(emotion)) {
      return Colors.amber.withValues(alpha: alpha);
    }
    return Colors.transparent;
  }

  @override
  void initState() {
    super.initState();
    _initChatStorage();
  }

  Future<void> _initChatStorage() async {
    try {
      await Hive.initFlutter();
      _chatBox = await Hive.openBox<String>(_chatBoxName);
      _loadMessages();
    } catch (e) {
      debugPrint("Error loading chat storage: $e");
    }
  }

  void _loadMessages() {
    final List<ChatMessage> loaded = [];
    for (final raw in _chatBox.values) {
      try {
        final data = jsonDecode(raw);
        loaded.add(ChatMessage.fromMap(data));
      } catch (_) {}
    }

    if (loaded.isEmpty) {
      final initial = ChatMessage(
        text: 'السلام عليكم، أنا رفيقك الروحي مُرَسِّخ. كيف حالك اليوم؟ شاركني ما يدور في خاطرك أو يثقل صدرك.',
        isUser: false,
      );
      loaded.add(initial);
      _chatBox.add(jsonEncode(initial.toMap()));
    }

    if (mounted) {
      setState(() {
        _messages = loaded;
        _isBoxReady = true;
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveMessage(ChatMessage msg) async {
    if (!_isBoxReady) return;
    try {
      await _chatBox.add(jsonEncode(msg.toMap()));
    } catch (e) {
      debugPrint("Error saving chat message: $e");
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح المحادثة'),
        content: const Text(
          'هل تريد مسح رسائل المحادثة الحالية والبدء من جديد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatBox.clear();
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final userMsg = ChatMessage(text: text.trim(), isUser: true);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _saveMessage(userMsg);
    _controller.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();
    context.read<RecommendationBloc>().add(GetRecommendationEvent(text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecommendationBloc, RecommendationState>(
      listener: (context, state) {
        if (state is RecommendationLoaded) {
          final aiMsg = ChatMessage(
            text: state.recommendation.message,
            isUser: false,
            recommendation: state.recommendation,
          );
          setState(() {
            _isLoading = false;
            _messages.add(aiMsg);
          });
          _saveMessage(aiMsg);
          _scrollToBottom();
        } else if (state is RecommendationError) {
          final errMsg = ChatMessage(
            text: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ\n(تعذّر الاتصال بالخادم، تذكر دائماً أن الله قريب مجيب).',
            isUser: false,
          );
          setState(() {
            _isLoading = false;
            _messages.add(errMsg);
          });
          _saveMessage(errMsg);
          _scrollToBottom();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text('مُرَسِّخ'),
              Text(
                'الرفيق الروحي',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'مسح المحادثة',
              onPressed: _messages.length > 1 ? _clearChat : null,
            ),
          ],
        ),
        body: AnimatedContainer(
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _getEmotionColor(context, _currentEmotion),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoading && index == _messages.length) {
                      return _buildTypingIndicator(context);
                    }
                    final msg = _messages[index];
                    return msg.isUser
                        ? _buildUserMessage(context, msg.text)
                        : _buildSystemMessage(context, msg, index);
                  },
                ),
              ),
              _buildInputArea(context),
            ],
          ),
        ),
      ),
    );
  }

  void _rateMessage(int index, int rating) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];
    final newRating = msg.feedback == rating ? null : rating;

    setState(() {
      msg.feedback = newRating;
    });

    try {
      await _chatBox.putAt(index, jsonEncode(msg.toMap()));
    } catch (e) {
      debugPrint("Error updating feedback in chat storage: $e");
    }

    if (newRating != null) {
      final id = msg.recommendation?.source ?? msg.text;
      await OfflineService().savePendingFeedback(id, newRating);
      await HistoryService().updateFeedback(id, newRating);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newRating == 1
                  ? 'شكراً لتقييمك الإيجابي! 👍 سيساعد ذلك في تحسين التوصيات.'
                  : 'شكراً لملاحظتك! 🌸 سنعمل على تحسين دقة الردود.',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'جارٍ البحث في القرآن الكريم عما يواسيك...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, ChatMessage msg, int index) {
    final rec = msg.recommendation;
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 48, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(
              msg.text,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.white, height: 1.5),
            ),
          ),
          if (rec != null && rec.source != null) ...[
            _buildSourceCard(context, rec),
            const SizedBox(height: 4),
          ],
          _buildMessageActions(context, msg, index),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMessageActions(
    BuildContext context,
    ChatMessage msg,
    int index,
  ) {
    final isLiked = msg.feedback == 1;
    final isDisliked = msg.feedback == -1;

    return Container(
      margin: const EdgeInsets.only(left: 48, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'نسخ الرسالة',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            color: Colors.grey.shade600,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: msg.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ الرسالة 📋'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _rateMessage(index, 1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 16,
                    color: isLiked
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                  if (isLiked) ...[
                    const SizedBox(width: 4),
                    Text(
                      'مفيد',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _rateMessage(index, -1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDisliked
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_alt_outlined,
                    size: 16,
                    color: isDisliked
                        ? Colors.red.shade700
                        : Colors.grey.shade600,
                  ),
                  if (isDisliked) ...[
                    const SizedBox(width: 4),
                    Text(
                      'غير ملائم',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, RecommendationModel rec) {
    return Container(
      margin: const EdgeInsets.only(left: 32),
      child: Card(
        color: AppColors.primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  rec.source!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              if (rec.tafsir != null &&
                  rec.tafsir!.isNotEmpty &&
                  rec.tafsir != 'التفسير متاح عند الطلب') ...[
                const SizedBox(height: 8),
                Text(
                  rec.tafsir!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            MicButton(
              onRecordComplete: (path) {
                final userMsg = ChatMessage(
                  text: '[رسالة صوتية 🎤]',
                  isUser: true,
                );
                setState(() {
                  _messages.add(userMsg);
                  _isLoading = true;
                });
                _saveMessage(userMsg);
                _scrollToBottom();
                context.read<RecommendationBloc>().add(AnalyzeAudioEvent(path));
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'شاركني ما تشعر به...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
