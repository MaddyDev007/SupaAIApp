import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🔹 Global list to persist chat messages while app is open
List<Map<String, String>> chatHistory = [];

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  int dotIndex = 0; // for animated dots
  Timer? _timer;

  List<Map<String, String>> get messages => chatHistory;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startDotAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (isLoading) {
        setState(() {
          dotIndex = (dotIndex + 1) % 3;
        });
      }
    });
  }

  Future<void> sendMessage(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'msg': question});
      isLoading = true;
      dotIndex = 0;
    });

    controller.clear();
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse('https://supaaiapp.onrender.com/chatbot/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body)['answer'];
        setState(() {
          messages.add({'role': 'bot', 'msg': response});
          isLoading = false;
        });
      } else {
        setState(() {
          messages.add({'role': 'bot', 'msg': '⚠️ Failed to get response.'});
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add({'role': 'bot', 'msg': '❌ Error: $e'});
        isLoading = false;
      });
    }
    _scrollToBottom();
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

  void _clearChat() {
    setState(() {
      chatHistory.clear();
      isLoading = false;
    });
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    bool isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message['msg'] ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isUser ? Colors.black87 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xfff5f7fb),
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        title: const Text(
          'AI Chatbot',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Clear Chat",
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < messages.length) {
                  return _buildMessageBubble(messages[index]);
                } else {
                  return _buildTypingIndicator();
                }
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "Ask something...",
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade600,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => sendMessage(controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
