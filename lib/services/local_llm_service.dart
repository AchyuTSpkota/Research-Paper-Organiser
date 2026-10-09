import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/paper.dart';

enum _Route { chat, rag }

class LocalLlmService {
  static const String _baseUrl = 'http://localhost:11434';
  static const String _chatModel = 'llama3.2:1b';
  static const String _ragModel = 'llama3.2:3b';

  bool _ready = false;
  Set<String> _installed = {};

  bool get isReady => _ready;

  Future<void> initialize({String modelPath = ''}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['models'] as List?) ?? [];
        _installed = list.map((m) => (m['name'] as String?) ?? '').toSet();
        _ready = _installed.any((n) => n.startsWith(_chatModel)) &&
            _installed.any((n) => n.startsWith(_ragModel));
      }
    } catch (_) {
      _ready = false;
    }
  }

  // ---------------- ROUTER ----------------

  _Route _route(String question, List<Paper> retrieved) {
    final q = question.toLowerCase().trim();

    if (RegExp(
      r'^(hi|hello|hey|yo|sup|howdy|'
      r'good (morning|evening|afternoon)|'
      r'how are you|thanks|thank you|'
      r'bye|goodbye|ok|okay|cool|nice)'
      r'[\s!?.]*$',
    ).hasMatch(q)) {
      return _Route.chat;
    }

    if (retrieved.isNotEmpty) return _Route.rag;

    const ragKeywords = [
      'paper', 'papers', 'document', 'documents', 'library',
      'summarize', 'summary', 'abstract', 'author', 'authors',
      'doi', 'citation', 'pdf', 'research', 'study',
      'list', 'find', 'search', 'show me',
      'what do i have', 'what papers',
    ];
    if (ragKeywords.any(q.contains)) return _Route.rag;

    if (q.length < 40) return _Route.chat;
    return _Route.rag;
  }

  // ---------------- MAIN ENTRY ----------------

  Stream<String> streamAnswer({
    required String question,
    required List<Paper> papers,
    List<Paper>? allLibraryPapers,
  }) async* {
    if (!_ready) {
      yield 'Ollama is not reachable at $_baseUrl.\n\n'
          'Run in a terminal:\n'
          '  ollama serve\n'
          '  ollama pull $_chatModel\n'
          '  ollama pull $_ragModel';
      return;
    }

    final route = _route(question, papers);

    if (route == _Route.chat) {
      yield* _streamChat(question);
    } else {
      yield* _streamRag(question, papers);
    }
  }

  // ---------------- CHAT PATH ----------------

  Stream<String> _streamChat(String question) async* {
    yield* _streamRaw(
      model: _chatModel,
      system: 'You are MyPaperHub, a friendly assistant inside a personal '
          'paper library app. You can chat casually. If the user asks about '
          'specific papers, tell them to ask a clear question like '
          '"summarize my paper on X". Keep replies short and warm.',
      user: question,
    );
  }

  // ---------------- RAG PATH ----------------

  Stream<String> _streamRag(String question, List<Paper> papers) async* {
    final ctx = StringBuffer();
    if (papers.isEmpty) {
      ctx.writeln('(No papers matched this query.)');
    } else {
      for (var i = 0; i < papers.length && i < 4; i++) {
        final p = papers[i];
        final body = p.fullText.isNotEmpty ? p.fullText : p.abstractText;
        final snippet =
            body.length > 2000 ? '${body.substring(0, 2000)}…' : body;
        ctx
          ..writeln('[${i + 1}] "${p.title}" — ${p.authors}, ${p.year} '
              '| Category: ${p.category}')
          ..writeln(snippet)
          ..writeln('---');
      }
    }

    final system = '''
You are MyPaperHub's research assistant. The user's local paper library
retrieved these excerpts for their question:

$ctx

Rules:
- Answer using the excerpts. Cite papers as [1], [2].
- If nothing is relevant, say "I don't have papers about that in your library."
- Never invent titles, authors, DOIs, or links.
- Be concise.
''';

    yield* _streamRaw(model: _ragModel, system: system, user: question);
  }

  // ---------------- SHARED HTTP ----------------

  Stream<String> _streamRaw({
    required String model,
    required String system,
    required String user,
  }) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final msg = json['message'] as Map<String, dynamic>?;
          final chunk = msg?['content'] as String?;
          if (chunk != null && chunk.isNotEmpty) yield chunk;
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  // ---------------- CLASSIFIER (used by library screen) ----------------

  Future<String> classifyPaper({
    required String title,
    required String text,
  }) async {
    const cats = [
      'Computer Science & AI',
      'Medicine & Biology',
      'Physics & Mathematics',
      'Psychology & Social Sciences',
      'Law & Political Science',
      'Engineering & Other',
    ];

    if (!_ready) return cats.last;

    final snippet = text.length > 1500 ? text.substring(0, 1500) : text;

    final prompt = '''
Classify the following academic paper into EXACTLY ONE of these categories:

1. Computer Science & AI
2. Medicine & Biology
3. Physics & Mathematics
4. Psychology & Social Sciences
5. Law & Political Science
6. Engineering & Other

Respond with ONLY the number (1, 2, 3, 4, 5, or 6). No explanation.

Title: $title

Text:
$snippet
''';

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _chatModel,
              'stream': false,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) return cats.last;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = data['message'] as Map<String, dynamic>?;
      final content = (msg?['content'] as String?)?.trim() ?? '';

      final m = RegExp(r'[1-6]').firstMatch(content);
      if (m == null) return cats.last;
      final idx = int.parse(m.group(0)!) - 1;
      return cats[idx];
    } catch (_) {
      return cats.last;
    }
  }
}