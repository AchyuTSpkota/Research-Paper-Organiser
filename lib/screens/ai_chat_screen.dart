import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/ai_tools.dart';
import '../services/database_helper.dart';
import '../services/local_llm_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final _llm = LocalLlmService();

  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await _llm.initialize();
    if (!mounted) return;
    setState(() {
      _initialized = true;
      if (!_llm.isReady) {
        _messages.add({
          'role': 'assistant',
          'content': 'Ollama is not reachable at http://localhost:11434.\n\n'
              'In a terminal, run:\n  ollama serve\n  ollama pull llama3.2:3b',
        });
      }
    });
  }

  Future<void> _askQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _controller.clear();
      _loading = true;
      _messages.add({'role': 'assistant', 'content': ''});
    });

    final papers = await DatabaseHelper.instance.search(question);
    final allPapers = await DatabaseHelper.instance.search('');

    final buffer = StringBuffer();
    final assistantIndex = _messages.length - 1;

    try {
      await for (final chunk in _llm.streamAnswer(
        question: question,
        papers: papers,
        allLibraryPapers: allPapers,
      )) {
        buffer.write(chunk);
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex] = {
            'role': 'assistant',
            'content': buffer.toString(),
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[assistantIndex] = {
          'role': 'assistant',
          'content': 'Error: $e',
        };
        _loading = false;
      });
    }
  }

  Future<void> _grantFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (!AiToolRegistry.grantedFolders.contains(path)) {
      AiToolRegistry.grantedFolders.add(path);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Granted: $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Grant folder to AI',
            onPressed: _grantFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _initialized
                ? ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 500),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.indigo
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            msg['content'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your papers...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _askQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _loading ? null : _askQuestion,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}