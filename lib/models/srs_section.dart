class SrsSection {
  const SrsSection({
    required this.id,
    required this.title,
    required this.blocks,
    required this.order,
    this.sectionNumber,
    this.parentSection,
    this.category = 'Other',
    this.keywords = const [],
  });

  /// Application key, never an official source reference.
  final String id;
  final String title;
  final List<String> blocks;
  final int order;
  final String? sectionNumber;
  final String? parentSection;
  final String category;
  final List<String> keywords;
  String get content => blocks.join('\n\n');
  String get path => [?parentSection, title].join(' > ');
}

String normalizeSrsSearch(String value) =>
    value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

class SrsIndex {
  SrsIndex(List<SrsSection> sections) : sections = List.unmodifiable(sections) {
    _text = [
      for (final s in sections)
        normalizeSrsSearch(
          '${s.sectionNumber ?? ''} ${s.path} ${s.category} ${s.keywords.join(' ')} ${s.content}',
        ),
    ];
    byId = {for (final s in sections) s.id: s};
  }
  final List<SrsSection> sections;
  late final List<String> _text;
  late final Map<String, SrsSection> byId;
  List<SrsSection> search(String query, {String? category}) {
    final tokens = normalizeSrsSearch(query)
        .split(' ')
        .where((t) => t.isNotEmpty);
    return [
      for (var i = 0; i < sections.length; i++)
        if ((category == null || sections[i].category == category) &&
            tokens.every(_text[i].contains))
          sections[i],
    ];
  }
}
