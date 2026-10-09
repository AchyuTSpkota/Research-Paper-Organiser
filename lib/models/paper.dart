class Paper {
  final int? id;
  final String title;
  final String authors;
  final int year;
  final String abstractText;
  final String keywords;
  final String doi;
  final String filePath;
  final String fullText;
  final DateTime createdAt;
  final String readStatus;
  final String category;

  Paper({
    this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.abstractText,
    required this.keywords,
    required this.doi,
    required this.filePath,
    required this.fullText,
    required this.createdAt,
    this.readStatus = 'unread',
    this.category = 'Engineering & Other',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'authors': authors,
        'year': year,
        'abstract': abstractText,
        'keywords': keywords,
        'doi': doi,
        'file_path': filePath,
        'full_text': fullText,
        'created_at': createdAt.millisecondsSinceEpoch,
        'read_status': readStatus,
        'category': category,
      };

  static Paper fromMap(Map<String, dynamic> m) => Paper(
        id: m['id'] as int?,
        title: (m['title'] as String?) ?? 'Untitled',
        authors: (m['authors'] as String?) ?? '',
        year: (m['year'] as int?) ?? DateTime.now().year,
        abstractText: (m['abstract'] as String?) ?? '',
        keywords: (m['keywords'] as String?) ?? '',
        doi: (m['doi'] as String?) ?? '',
        filePath: (m['file_path'] as String?) ?? '',
        fullText: (m['full_text'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0,
        ),
        readStatus: (m['read_status'] as String?) ?? 'unread',
        category: (m['category'] as String?) ?? 'Engineering & Other',
      );
}