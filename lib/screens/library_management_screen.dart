import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/paper.dart';
import '../services/database_helper.dart';
import '../services/local_llm_service.dart';
import '../services/pdf_metadata_service.dart';
import '../services/pdf_storage.dart';

class LibraryManagementScreen extends StatefulWidget {
  const LibraryManagementScreen({super.key});

  @override
  State<LibraryManagementScreen> createState() =>
      _LibraryManagementScreenState();
}

class _LibraryManagementScreenState extends State<LibraryManagementScreen> {
  final _metadataService = PdfMetadataService();
  final _llm = LocalLlmService();
  bool _isLoading = false;
  String _statusMessage = '';
  int _addedThisSession = 0;

  @override
  void initState() {
    super.initState();
    _llm.initialize();
  }

  Future<void> _pickAndImportPdf() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Picking file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _statusMessage = 'Copying file...');
      final savedPath = await PdfStorage.saveCopyToLibrary(
        filePath,
        p.basename(filePath),
      );

      setState(() => _statusMessage = 'Extracting text...');
      final meta = await _metadataService.read(savedPath);

      setState(() => _statusMessage = 'Classifying with AI...');
      final category = await _llm.classifyPaper(
        title: meta['title'] as String,
        text: meta['fullText'] as String,
      );

      final paper = Paper(
        title: meta['title'] as String,
        authors: meta['authors'] as String,
        year: meta['year'] as int,
        abstractText: meta['abstract'] as String,
        keywords: meta['keywords'] as String,
        doi: meta['doi'] as String,
        filePath: savedPath,
        fullText: meta['fullText'] as String,
        createdAt: DateTime.now(),
        readStatus: 'unread',
        category: category,
      );

      await DatabaseHelper.instance.insertPaper(paper);

      if (mounted) {
        setState(() {
          _addedThisSession++;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added as "$category" ($_addedThisSession this session)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_addedThisSession > 0);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Library Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'This app is for accessing papers you own or have permission to use.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You are responsible for ensuring you have the right to add any PDFs.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAndImportPdf,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_isLoading ? 'Importing...' : 'Add PDF'),
                ),
                const SizedBox(height: 16),
                if (_isLoading && _statusMessage.isNotEmpty)
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (!_isLoading && _addedThisSession > 0)
                  Text(
                    '$_addedThisSession paper(s) added this session',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}