import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/srs_section.dart';

class SrsImportException implements Exception {
  const SrsImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

String? _attr(XmlElement? e, String name) =>
    e?.attributes.where((a) => a.name.local == name).firstOrNull?.value;
Iterable<XmlElement> _desc(XmlElement e, String name) =>
    e.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
String _text(XmlElement e) {
  final out = StringBuffer();
  for (final n in e.descendants.whereType<XmlElement>()) {
    if (n.name.local == 't') out.write(n.innerText);
    if (n.name.local == 'tab') out.write('\t');
    if (n.name.local == 'br' || n.name.local == 'cr') out.write('\n');
  }
  return out.toString().trim();
}

String _category(String title, String inherited) {
  final t = title.toLowerCase();
  if (t.contains('non-functional') || t.contains('non functional')) {
    return 'Non-Functional Requirement';
  }
  if (t.contains('functional requirement')) return 'Functional Requirement';
  if (t.contains('use case')) return 'Use Case';
  if (t.contains('business rule')) return 'Business Rule';
  if (t.contains('common requirement')) return 'Common Requirement';
  if (t.contains('application message')) return 'Application Message';
  return inherited;
}

/// Parses once in a background isolate on desktop. Literal source numbering is
/// retained; automatic Word numbering is not guessed.
List<SrsSection> parseSrsBytes(Uint8List bytes) {
  try {
    // Verification of the entire ZIP inflates every embedded image. The real
    // report is 65 MB, mostly media; only inflate and verify the XML we consume.
    final zip = ZipDecoder().decodeBytes(bytes);
    String? part(String name) {
      final entry = zip.findFile(name);
      if (entry == null) return null;
      final content = entry.content as List<int>;
      if (getCrc32(content) != entry.crc32) {
        throw SrsImportException(
          'The DOCX contains damaged $name. Save a fresh .docx copy and try again.',
        );
      }
      return utf8.decode(content);
    }

    final xml = part('word/document.xml');
    if (xml == null) {
      throw const SrsImportException('This DOCX has no word/document.xml.');
    }
    final document = XmlDocument.parse(xml);
    final body = document.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'body')
        .firstOrNull;
    if (body == null) {
      throw const SrsImportException('The DOCX document is empty.');
    }
    final styles = <String, int>{};
    final stylesXml = part('word/styles.xml');
    if (stylesXml != null) {
      final styleDoc = XmlDocument.parse(stylesXml);
      for (final s in styleDoc.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'style',
      )) {
        final name = _attr(_desc(s, 'name').firstOrNull, 'val') ?? '';
        final match = RegExp(
          r'heading\s*(\d)',
          caseSensitive: false,
        ).firstMatch(name);
        final outline = int.tryParse(
          _attr(_desc(s, 'outlineLvl').firstOrNull, 'val') ?? '',
        );
        final level = match == null
            ? (outline == null || outline > 8 ? null : outline + 1)
            : int.parse(match[1]!);
        if (level != null) styles[_attr(s, 'styleId') ?? ''] = level;
      }
    }
    final sections = <SrsSection>[];
    final stack = <({int level, String title, String category})>[];
    String? title, number, parent;
    var category = 'Other';
    var blocks = <String>[];
    void flush() {
      if (title == null) {
        blocks = [];
        return;
      }
      sections.add(
        SrsSection(
          id: 'srs_section_${sections.length + 1}',
          title: title,
          blocks: List.unmodifiable(blocks),
          order: sections.length,
          sectionNumber: number,
          parentSection: parent,
          category: category,
        ),
      );
      blocks = [];
    }

    // Only block-level paragraphs are headings. Table paragraphs stay in rows.
    Iterable<XmlElement> flow(XmlElement e) sync* {
      for (final child in e.childElements) {
        if (child.name.local == 'p' || child.name.local == 'tbl') {
          yield child;
        } else if (child.name.local != 'sectPr') {
          yield* flow(child);
        }
      }
    }

    int? headingLevel(XmlElement element) {
      final style = _attr(_desc(element, 'pStyle').firstOrNull, 'val') ?? '';
      final match = RegExp(
        r'^heading\s*(\d)$',
        caseSensitive: false,
      ).firstMatch(style);
      final outline = int.tryParse(
        _attr(_desc(element, 'outlineLvl').firstOrNull, 'val') ?? '',
      );
      return styles[style] ??
          (match == null ? null : int.parse(match[1]!)) ??
          (outline == null || outline > 8 ? null : outline + 1);
    }

    final elements = flow(body).toList();
    // Combined capstone reports include design, testing and user manuals after
    // the SRS chapter. Only use the explicit SRS chapter when one is present.
    final srsStart = elements.indexWhere(
      (e) =>
          e.name.local == 'p' &&
          headingLevel(e) != null &&
          RegExp(
            r'^(?:[IVX]+[.)]?\s+|\d+[.)]?\s+)?Software Requirements? Specification$',
            caseSensitive: false,
          ).hasMatch(_text(e)),
    );
    var srsEnd = elements.length;
    if (srsStart >= 0) {
      final rootLevel = headingLevel(elements[srsStart])!;
      for (var i = srsStart + 1; i < elements.length; i++) {
        if (elements[i].name.local != 'p') continue;
        final level = headingLevel(elements[i]);
        if (level != null && level <= rootLevel) {
          srsEnd = i;
          break;
        }
      }
    }
    final numbered = RegExp(r'^((?:\d+\.)*\d+|[IVX]+)[.)]?\s+(.+)$');
    for (final element
        in elements
            .skip(srsStart < 0 ? 0 : srsStart)
            .take(srsEnd - (srsStart < 0 ? 0 : srsStart))) {
      if (element.name.local == 'tbl') {
        for (final row in element.childElements.where(
          (e) => e.name.local == 'tr',
        )) {
          final cells = row.childElements
              .where((e) => e.name.local == 'tc')
              .map(
                (c) => _desc(
                  c,
                  'p',
                ).map(_text).where((t) => t.isNotEmpty).join('\n'),
              )
              .toList();
          if (cells.any((c) => c.isNotEmpty)) blocks.add(cells.join('\t | \t'));
        }
        continue;
      }
      final text = _text(element);
      if (text.isEmpty) continue;
      final style = _attr(_desc(element, 'pStyle').firstOrNull, 'val') ?? '';
      if (style.toLowerCase().startsWith('toc')) continue;
      int? level = headingLevel(element);
      final match = numbered.firstMatch(text);
      // Numbered prose/list steps are not headings; fallback requires dotted
      // numbering, short text and no sentence-ending punctuation.
      if (level == null &&
          match != null &&
          match[1]!.contains('.') &&
          text.length < 100 &&
          !RegExp(r'[.;:]$').hasMatch(text)) {
        level = match[1]!.split('.').length + 1;
      }
      if (level == null &&
          RegExp(
            r'^(Functional Requirements|Non-Functional Requirements|Business Rules|Common Requirements|Application Messages(?: List)?|Use Cases|Authentication)$',
            caseSensitive: false,
          ).hasMatch(text)) {
        level = 2;
      }
      // This project's Word file styles captions as Heading4.
      if (RegExp(
        r'^(Table|Figure)\s+\d',
        caseSensitive: false,
      ).hasMatch(text)) {
        level = null;
      }
      if (level != null) {
        flush();
        while (stack.isNotEmpty && stack.last.level >= level) {
          stack.removeLast();
        }
        parent = stack.isEmpty ? null : stack.map((s) => s.title).join(' > ');
        category = _category(
          text,
          stack.isEmpty ? 'Other' : stack.last.category,
        );
        title = text;
        number =
            match?[1] ??
            RegExp(r'^([A-Z]{2,8}[-_]\d+(?:\.\d+)*)\b').firstMatch(text)?[1];
        stack.add((level: level, title: text, category: category));
      } else if (title != null) {
        blocks.add(text);
      }
    }
    flush();
    if (sections.isEmpty || sections.every((s) => s.blocks.isEmpty)) {
      throw const SrsImportException(
        'No useful SRS sections found. Use a DOCX with headings and requirement content.',
      );
    }
    return List.unmodifiable(sections);
  } on SrsImportException {
    rethrow;
  } catch (_) {
    throw const SrsImportException(
      'Unable to parse this DOCX. It may be corrupted or unsupported.',
    );
  }
}
