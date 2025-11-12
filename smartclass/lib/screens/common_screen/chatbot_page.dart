import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Global chat history
List<Map<String, String>> chatHistory = [];

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _showFAB = false; // ✅ Controls floating button visibility

  int _dotIndex = 0;
  Timer? _dotAnimationTimer;

  List<Map<String, String>> get _messages => chatHistory;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();
    _scrollToBottom();

    if (chatHistory.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        setState(() {
          chatHistory.add({
            'role': 'bot_typing',
            'msg': '👋 Hi there! How can I help you today?',
          });
        });
      });
    }

    // ✅ Track scroll to show/hide FAB
    _scrollController.addListener(() {
      final atBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 50;

      setState(() {
        _showFAB = !atBottom;
      });
    });
  }

  @override
  void dispose() {
    _dotAnimationTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Typing dots animation
  void _startDotAnimation() {
    _dotAnimationTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_isLoading) {
        setState(() => _dotIndex = (_dotIndex + 1) % 3);
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // API call
  Future<void> _sendMessage() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'msg': question});
      _isLoading = true;
      _dotIndex = 0;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse('https://supaaiapp-1.onrender.com/chatbot/'),
        // Uri.parse('http://127.0.0.1:8000/chatbot/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body)['answer'];
        setState(() {
          _isLoading = false;
          _messages.add({'role': 'bot_typing', 'msg': response});
        });
      } else {
        _handleApiError('⚠️ Failed to get response.');
      }
    } catch (e) {
      if (!mounted) return;
      if (e is http.ClientException) {
        _handleApiError('🌐 Network error. Please check your connection.');
        return;
      }
      _handleApiError('❌ Error occurred: $e');
    }

    _scrollToBottom();
  }

  void _handleApiError(String errorMessage) {
    setState(() {
      _isLoading = false;
      _messages.add({'role': 'bot', 'msg': errorMessage});
    });
  }

  void _clearChat() {
    setState(() {
      chatHistory.clear();
      _isLoading = false;
    });
  }

  Future<void> _showClearChatDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Clear Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear the chat history?\nThis action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Clear',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: _buildAppBar(),

      body: Stack(
        children: [
          Column(
            children: [
              _buildMessageList(),
              _MessageInputBar(
                controller: _controller,
                onSend: _sendMessage,
                isLoading: _isLoading,
              ),
            ],
          ),

          // ✅ Glassmorphic Floating Scroll-To-Bottom Button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            right: 16,
            bottom: _showFAB ? 80 : -70, // slide out
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showFAB ? 1 : 0,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.blue, width: 1.3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue.shade600,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'AI Chatbot',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: _showClearChatDialog,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: _messages.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return _TypingIndicator(dotIndex: _dotIndex);
            }

            final msg = _messages[index];
            final role = msg['role'];
            final text = msg['msg']!;

            if (role == "bot_typing") {
              return _TypingMessageBubble(
                fullText: text,
                onTypingComplete: () {
                  final i = chatHistory.indexOf(msg);
                  if (i != -1) {
                    setState(() {
                      chatHistory[i] = {'role': 'bot', 'msg': text};
                    });
                  }
                },
              );
            }

            return _MessageBubble(text: text, isUser: role == "user");
          },
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// ✅ MESSAGE BUBBLES + INDICATORS + INPUT BAR + TYPING EFFECT
////////////////////////////////////////////////////////////////////////////////

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUser
            ? Text(text, style: const TextStyle(fontSize: 15))
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 15),
                ),
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.dotIndex});

  final int dotIndex;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedOpacity(
              opacity: dotIndex == i ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatefulWidget {
  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  bool isEmpty = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {
        isEmpty = widget.controller.text.trim().isEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = isEmpty || widget.isLoading;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                enabled: !widget.isLoading,
                cursorColor: Colors.blue,
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.isLoading
                      ? "Bot is responding..."
                      : "Ask something...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: blocked
                  ? Colors.grey.shade300
                  : Colors.blue.shade600,
              radius: 24,
              child: IconButton(
                icon: Icon(
                  blocked ? Icons.send : Icons.send,
                  color: Colors.white,
                ),
                onPressed: blocked ? null : widget.onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingMessageBubble extends StatefulWidget {
  const _TypingMessageBubble({
    required this.fullText,
    required this.onTypingComplete,
  });

  final String fullText;
  final VoidCallback onTypingComplete;

  @override
  State<_TypingMessageBubble> createState() => _TypingMessageBubbleState();
}

class _TypingMessageBubbleState extends State<_TypingMessageBubble> {
  String _displayedText = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTypingAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTypingAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 12), (timer) {
      if (_displayedText.length < widget.fullText.length) {
        setState(() {
          _displayedText = widget.fullText.substring(
            0,
            _displayedText.length + 1,
          );
        });
      } else {
        timer.cancel();
        widget.onTypingComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 5),
          ],
        ),
        child: MarkdownBody(
          data: _displayedText.isEmpty ? "..." : _displayedText,
        ),
      ),
    );
  }
}
