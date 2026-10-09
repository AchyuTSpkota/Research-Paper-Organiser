import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/paper.dart';
import '../services/database_helper.dart';
import '../widgets/category_pie_chart.dart';
import 'ai_chat_screen.dart';
import 'library_management_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Paper> _results = [];
  Map<String, int> _counts = {};
  bool _loading = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final matches = await DatabaseHelper.instance.search(query);
    final counts = await DatabaseHelper.instance.categoryCounts();
    if (!mounted) return;
    setState(() {
      _results = matches;
      _counts = counts;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'read':
        return Colors.green;
      case 'reading':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'read':
        return 'Read';
      case 'reading':
        return 'Reading';
      default:
        return 'Unread';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'read':
        return Icons.check_circle;
      case 'reading':
        return Icons.menu_book;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Future<void> _changeStatus(Paper paper) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Reading status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked,
                  color: Colors.grey),
              title: const Text('Unread'),
              trailing: paper.readStatus == 'unread'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, 'unread'),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.orange),
              title: const Text('Reading'),
              trailing: paper.readStatus == 'reading'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, 'reading'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Read'),
              trailing:
                  paper.readStatus == 'read' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'read'),
            ),
          ],
        ),
      ),
    );

    if (selected == null || selected == paper.readStatus) return;
    if (paper.id == null) return;
    await DatabaseHelper.instance.updateReadStatus(paper.id!, selected);
    if (!mounted) return;
    _search(_searchController.text);
  }

  Future<void> _changeCategory(Paper paper) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              for (final cat in DatabaseHelper.categories)
                ListTile(
                  title: Text(cat),
                  trailing: paper.category == cat
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(ctx, cat),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || selected == paper.category) return;
    if (paper.id == null) return;
    await DatabaseHelper.instance.updateCategory(paper.id!, selected);
    if (!mounted) return;
    _search(_searchController.text);
  }

  Future<void> _openPaper(Paper paper) async {
    if (paper.readStatus == 'unread' && paper.id != null) {
      await DatabaseHelper.instance.updateReadStatus(paper.id!, 'reading');
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(filePath: paper.filePath),
      ),
    );

    if (!mounted) return;
    _search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LibraryManagementScreen(),
                ),
              );
              if (result == true || mounted) {
                _search('');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // ---- Pie chart section ----
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  'Library by category',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                CategoryPieChart(counts: _counts),
                              ],
                            ),
                          ),
                        ),
                        // ---- Paper cards ----
                        if (_results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text(tr('no_results'))),
                          ),
                        for (final paper in _results)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(paper.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${paper.authors} • ${paper.year}'),
                                  Text(
                                    paper.abstractText.isNotEmpty
                                        ? paper.abstractText
                                        : tr('no_abstract'),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      // Status chip
                                      GestureDetector(
                                        onTap: () => _changeStatus(paper),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(paper.readStatus)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _statusColor(
                                                  paper.readStatus),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _statusIcon(paper.readStatus),
                                                size: 14,
                                                color: _statusColor(
                                                    paper.readStatus),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _statusLabel(paper.readStatus),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _statusColor(
                                                      paper.readStatus),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Category chip
                                      GestureDetector(
                                        onTap: () => _changeCategory(paper),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.category_outlined,
                                                size: 14,
                                                color: Colors.indigo,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                paper.category,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.indigo,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: FilledButton(
                                onPressed: () => _openPaper(paper),
                                child: Text(tr('view_pdf')),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
