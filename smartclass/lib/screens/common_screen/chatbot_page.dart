import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

// ---------------- GLOBAL CHAT MEMORY ----------------
// (kept global intentionally for persistent chat)
final List<Map<String, String>> chatHistory = [];

class ChatbotPage extends StatefulWidget {
  final String classId; 
  const ChatbotPage({super.key,
  required this.classId,});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _showFAB = false;

  int _dotIndex = 0;
  Timer? _dotTimer;

  List<Map<String, String>> get _messages => chatHistory;

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _startDotAnimation();
    _attachScrollListener();

    if (chatHistory.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          chatHistory.add({
            'role': 'bot_typing',
            'msg': '👋 Hi there! How can I help you today?',
          });
        });
      });
    }

    _scrollToBottom();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _dotTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------- DOT ANIMATION ----------------
  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_isLoading && mounted) {
        setState(() => _dotIndex = (_dotIndex + 1) % 3);
      }
    });
  }

  // ---------------- SCROLL HANDLING ----------------
  void _attachScrollListener() {
    bool lastAtBottom = true;

    _scrollController.addListener(() {
      final atBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 50;

      if (atBottom != lastAtBottom && mounted) {
        lastAtBottom = atBottom;
        setState(() => _showFAB = !atBottom);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- SEND MESSAGE ----------------
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
      final res = await http
          .post(
            Uri.parse('https://supaaiapp-1.onrender.com/chatbot/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              // 🔹 future-ready (optional)
             'class_id': widget.classId,
            }),
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final answer = jsonDecode(res.body)['answer'];
        setState(() {
          _isLoading = false;
          _messages.add({'role': 'bot_typing', 'msg': answer});
        });
      } else {
        _handleError('⚠️ Failed to get response from server.');
      }
    } catch (e) {
      if (!mounted) return;
      _handleError(
        e is TimeoutException
            ? '⏳ Request timed out. Try again.'
            : '🌐 Network error. Please check your connection.',
      );
    }

    _scrollToBottom();
  }

  void _handleError(String msg) {
    setState(() {
      _isLoading = false;
      _messages.add({'role': 'bot', 'msg': msg});
    });
  }

  // ---------------- CLEAR CHAT ----------------
  void _clearChat() {
    setState(() {
      chatHistory.clear();
      _isLoading = false;
    });
  }

  Future<void> _confirmClearChat() async {
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
          'Are you sure you want to clear the chat history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) _clearChat();
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMessageList(),
              _MessageInputBar(
                controller: _controller,
                isLoading: _isLoading,
                onSend: _sendMessage,
              ),
            ],
          ),
          _buildScrollFAB(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'AI Chatbot',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: _confirmClearChat,
        ),
      ],
    );
  }

  Widget _buildScrollFAB() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      right: 16,
      bottom: _showFAB ? 80 : -70,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showFAB ? 1 : 0,
        child: GestureDetector(
          onTap: _scrollToBottom,
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return _TypingIndicator(dotIndex: _dotIndex);
          }

          final msg = _messages[index];
          final role = msg['role'];
          final text = msg['msg']!;

          if (role == 'bot_typing') {
            return _TypingMessageBubble(
              fullText: text,
              scrollController: _scrollController,
              onTypingComplete: () {
                final i = chatHistory.indexOf(msg);
                if (i != -1 && mounted) {
                  setState(() {
                    chatHistory[i] = {'role': 'bot', 'msg': text};
                  });
                }
              },
            );
          }

          return _MessageBubble(text: text, isUser: role == 'user');
        },
      ),
    );
  }
}
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? Theme.of(context).canvasColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: isUser
              ? SelectableText(text)
              : SelectionArea(child: MarkdownBody(data: text)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(0),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedOpacity(
              opacity: dotIndex == i ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  shape: BoxShape.circle
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
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.25 * 255).toInt()),
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
                cursorColor: Theme.of(context).primaryColor,
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.isLoading
                      ? "Bot is responding..."
                      : "Ask something...",
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: blocked
                  ? Theme.of(context).textTheme.bodySmall!.color!.withAlpha(100)
                  : Theme.of(context).primaryColor,
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
    required this.onTypingComplete, required this.scrollController,
    
  });

  final String fullText;
  final VoidCallback onTypingComplete;
  final ScrollController scrollController;



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
    if (_displayedText.length < widget.fullText.length) {
      widget.onTypingComplete();
    }
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

      // 👇 Smooth Auto-scroll Fix
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 5)); // tiny delay
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            widget.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOut,
          );
        }
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(0),
            bottomRight: const Radius.circular(16),
          ),
          
        ),
        child: MarkdownBody(
          data: _displayedText.isEmpty ? "..." : _displayedText,
        ),
      ),
    );
  }
}
