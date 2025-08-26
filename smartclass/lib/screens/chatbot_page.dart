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
        Uri.parse('http://127.0.0.1:8000/chatbot/'),
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
          duration: const Duration(milliseconds: 300),
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[200] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Text(
          message['msg'] ?? '',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[300],
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
      appBar: AppBar(
        title: const Text('AI Chatbot'),
        actions: [
          IconButton(
            tooltip: "Clear Chat",
            icon: const Icon(Icons.delete),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => sendMessage(controller.text),
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
