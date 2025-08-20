import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController controller = TextEditingController();
  List<Map<String, String>> messages = [];

  Future<void> sendMessage(String question) async {
    setState(() {
      messages.add({'role': 'user', 'msg': question});
    });

    controller.clear();

    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/chatbot/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );

      if (!mounted) return; // ✅ Prevent crash if widget is gone

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body)['answer'];
        setState(() {
          messages.add({'role': 'bot', 'msg': response});
        });
      } else {
        setState(() {
          messages.add({
            'role': 'bot',
            'msg': 'Sorry, failed to get response.',
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add({'role': 'bot', 'msg': 'Error: $e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chatbot')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: messages.map((m) {
                return ListTile(
                  title: Text(
                    m['msg']!,
                    textAlign: m['role'] == 'user'
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
                  tileColor: m['role'] == 'user'
                      ? Colors.blue[50]
                      : Colors.grey[300],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Ask something...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => sendMessage(controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
