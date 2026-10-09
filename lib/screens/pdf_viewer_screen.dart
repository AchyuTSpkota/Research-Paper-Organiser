import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  const PdfViewerScreen({required this.filePath, super.key});

  Future<void> _openPdf(BuildContext context) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not found.')),
        );
      }
      return;
    }

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPdf(context));
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Viewer')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 48),
            const SizedBox(height: 16),
            const Text('Opening in your default PDF viewer…'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _openPdf(context),
              child: const Text('Open Again'),
            ),
          ],
        ),
      ),
    );
  }
}