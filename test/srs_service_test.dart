import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/srs_service.dart';
import 'package:flutter_application_2/models/srs_section.dart';

import 'support/docx_fixture.dart';

void main() {
  test('Combined reports only index the explicit SRS chapter', () {
    String heading(String text) =>
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>$text</w:t></w:r></w:p>';
    const paragraph =
        '<w:p><w:r><w:t>Original requirement content.</w:t></w:r></w:p>';
    final sections = parseSrsBytes(
      docxFixture(
        body:
            '${heading('II. Project Management')}$paragraph${heading('III. Software Requirement Specification')}$paragraph${heading('IV. Design')}$paragraph',
      ),
    );
    expect(sections, hasLength(1));
    expect(sections.single.title, 'III. Software Requirement Specification');
    expect(sections.single.content, 'Original requirement content.');
  });
  test('DOCX preserves ordered headings, tables, Unicode, entities, breaks and tabs', () {
    final sections = parseSrsBytes(docxFixture());
    expect(sections, hasLength(4));
    final login = sections[2];
    expect(login.sectionNumber, '3.2.1');
    expect(login.category, 'Functional Requirement');
    expect(
      login.parentSection,
      '3. Functional Requirements > 3.2 Authentication',
    );
    expect(login.blocks, [
      'Đăng nhập & verify email\nKeep original wording.\tPassword',
      'Table 1. Login rules',
      'BR-01\t | \tReject invalid credentials.',
    ]);
    expect(login.id, startsWith('srs_section_'));
    expect(login.title, isNot(contains(login.id)));
  });
  test('Search normalizes whitespace and case, matches context, references and category', () {
    final index = SrsIndex(parseSrsBytes(docxFixture()));
    expect(index.search('  ĐĂNG   NHẬP '), hasLength(1));
    expect(index.search('3.2.1').single.title, '3.2.1 Login');
    expect(index.search('authentication credentials'), hasLength(1));
    expect(
      index.search('password', category: 'Functional Requirement'),
      hasLength(2),
    );
    expect(index.search('password', category: 'Business Rule'), isEmpty);
    expect(index.search('unknown'), isEmpty);
  });
  test(
    'Plain paragraphs do not become unrelated requirements; errors are useful',
    () {
      for (final bytes in [
        Uint8List.fromList([1, 2]),
        docxFixture(missingDocument: true),
        docxFixture(body: ''),
        docxFixture(body: '<w:p><w:r><w:t>Random paragraph.</w:t></w:r></w:p>'),
      ]) {
        expect(() => parseSrsBytes(bytes), throwsA(isA<SrsImportException>()));
      }
    },
  );
  test('Numbered fallback headings preserve explicit references', () {
    final sections = parseSrsBytes(
      docxFixture(
        body: '''
<w:p><w:r><w:t>Functional Requirements</w:t></w:r></w:p>
<w:p><w:r><w:t>3.1 Login</w:t></w:r></w:p>
<w:p><w:r><w:t>1. Enter the email.</w:t></w:r></w:p>
<w:p><w:r><w:t>2. Enter the password.</w:t></w:r></w:p>''',
      ),
    );
    expect(sections, hasLength(2));
    expect(sections.last.blocks, hasLength(2));
  });
  test(
    'Service validates extension and reports each processing stage',
    () async {
      final service = SrsService();
      await expectLater(
        service.importFile(XFile.fromData(docxFixture(), path: 'bad.pdf')),
        throwsA(isA<SrsImportException>()),
      );
      final progress = <String>[];
      final result = await service.importFile(
        XFile.fromData(docxFixture(), path: 'SRS.docx'),
        onProgress: progress.add,
      );
      expect(result.sections, hasLength(4));
      expect(progress, [
        'Reading SRS...',
        'Parsing document...',
        'Building section index...',
      ]);
    },
  );
  final path = Platform.environment['SRS_DOCX'];
  test(
    'Real project SRS: meaningful login hierarchy and searchable tables',
    () async {
      final result = await SrsService().importFile(XFile(path!));
      final login = result.sections
          .where((s) => s.title == '3.2.1 Login')
          .single;
      expect(login.parentSection, contains('Authentication'));
      expect(login.category, 'Functional Requirement');
      expect(login.content, isNotEmpty);
      expect(result.search('business rules'), isNotEmpty);
      expect(result.sections.length, greaterThan(100));
      // Diagnostic count is intentionally not fixed to one document revision.
      // ignore: avoid_print
      print(
        'Real SRS: ${result.sections.length} sections, ${result.sections.fold<int>(0, (n, s) => n + s.blocks.length)} blocks; Login: ${login.blocks.length} blocks.',
      );
    },
    skip: path == null
        ? 'Set SRS_DOCX to validate the real project document.'
        : false,
  );
}
