import 'dart:io';

import 'package:path/path.dart' as p;

import 'database_helper.dart';

class AiToolResult {
  final String content;
  final bool isError;
  const AiToolResult(this.content, {this.isError = false});
}

class AiToolRegistry {
  /// Folders the user has explicitly granted the AI read access to.
  /// Safe by default: empty until the user grants one via the folder icon.
  static final List<String> grantedFolders = [];

  static List<Map<String, dynamic>> get definitions => [
        _listLibraryDef,
        _searchLibraryDef,
        _readPaperDef,
        _listFolderDef,
      ];

  static Future<AiToolResult> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'list_library':
        return _listLibrary();
      case 'search_library':
        return _searchLibrary(args['query'] as String? ?? '');
      case 'read_paper':
        return _readPaper(args['paper_id'] as int?);
      case 'list_folder':
        return _listFolder(args['path'] as String? ?? '');
      default:
        return AiToolResult('Unknown tool: $name', isError: true);
    }
  }

  static const _listLibraryDef = {
    'type': 'function',
    'function': {
      'name': 'list_library',
      'description':
          'List every paper currently stored in the app\'s local library. '
              'Use this whenever the user asks what papers they have, how many '
              'papers they have, or to summarize the library.',
      'parameters': {'type': 'object', 'properties': {}, 'required': []},
    },
  };

  static const _searchLibraryDef = {
    'type': 'function',
    'function': {
      'name': 'search_library',
      'description':
          'Search the local paper library by title, author, keyword, year, or DOI.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'What to search for.'},
        },
        'required': ['query'],
      },
    },
  };

  static const _readPaperDef = {
    'type': 'function',
    'function': {
      'name': 'read_paper',
      'description':
          'Fetch the full extracted text of a specific paper by its numeric ID. '
              'Use for summaries or detailed questions. Get the ID from '
              'list_library or search_library first.',
      'parameters': {
        'type': 'object',
        'properties': {
          'paper_id': {
            'type': 'integer',
            'description': 'The paper\'s numeric ID.',
          },
        },
        'required': ['paper_id'],
      },
    },
  };

  static const _listFolderDef = {
    'type': 'function',
    'function': {
      'name': 'list_folder',
      'description':
          'List the contents of a folder the user has granted access to.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'Absolute path. Must be inside a folder the user granted.',
          },
        },
        'required': ['path'],
      },
    },
  };

  // ---------------- implementations ----------------

  static Future<AiToolResult> _listLibrary() async {
    final papers = await DatabaseHelper.instance.search('');
    if (papers.isEmpty) return const AiToolResult('The library is empty.');
    final buf = StringBuffer('Library has ${papers.length} paper(s):\n');
    for (final paper in papers) {
      buf.writeln('ID ${paper.id}: "${paper.title}" — '
          '${paper.authors}, ${paper.year}');
    }
    return AiToolResult(buf.toString());
  }

  static Future<AiToolResult> _searchLibrary(String query) async {
    if (query.trim().isEmpty) {
      return const AiToolResult('Empty query.', isError: true);
    }
    final papers = await DatabaseHelper.instance.search(query);
    if (papers.isEmpty) {
      return AiToolResult('No papers matched "$query".');
    }
    final buf = StringBuffer('Found ${papers.length} matching "$query":\n');
    for (final paper in papers) {
      buf.writeln('ID ${paper.id}: "${paper.title}" — '
          '${paper.authors}, ${paper.year}');
    }
    return AiToolResult(buf.toString());
  }

  static Future<AiToolResult> _readPaper(int? id) async {
    if (id == null) {
      return const AiToolResult('paper_id is required.', isError: true);
    }
    final papers = await DatabaseHelper.instance.search('');
    final match = papers.where((p) => p.id == id).toList();
    if (match.isEmpty) {
      return AiToolResult('No paper with ID $id.', isError: true);
    }
    final paper = match.first;
    final body =
        paper.fullText.isNotEmpty ? paper.fullText : paper.abstractText;
    if (body.isEmpty) {
      return AiToolResult(
        'Paper "${paper.title}" has no extracted text.',
        isError: true,
      );
    }
    final truncated = body.length > 6000 ? '${body.substring(0, 6000)}…' : body;
    return AiToolResult(
      'Title: ${paper.title}\n'
      'Authors: ${paper.authors}\n'
      'Year: ${paper.year}\n\n'
      '$truncated',
    );
  }

  static Future<AiToolResult> _listFolder(String rawPath) async {
    if (rawPath.isEmpty) {
      return const AiToolResult('path is required.', isError: true);
    }
    final dir = Directory(rawPath);
    if (!dir.existsSync()) {
      return AiToolResult('Folder does not exist: $rawPath', isError: true);
    }
    if (!_isAllowed(dir.path)) {
      return const AiToolResult(
        'Access denied. That folder is not in the user\'s granted list.',
        isError: true,
      );
    }
    try {
      final entries = dir.listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (entries.isEmpty) return const AiToolResult('Folder is empty.');
      final buf = StringBuffer('Contents of $rawPath:\n');
      for (final e in entries.take(200)) {
        final isDir = e is Directory;
        final size = e is File ? ' (${e.lengthSync()} bytes)' : '';
        buf.writeln('${isDir ? "[dir]" : "[file]"} ${p.basename(e.path)}$size');
      }
      return AiToolResult(buf.toString());
    } catch (e) {
      return AiToolResult('Error reading folder: $e', isError: true);
    }
  }

  static bool _isAllowed(String path) {
    final normalised = p.normalize(p.absolute(path));
    for (final granted in grantedFolders) {
      final g = p.normalize(p.absolute(granted));
      if (normalised == g || normalised.startsWith('$g${p.separator}')) {
        return true;
      }
    }
    return false;
  }
}