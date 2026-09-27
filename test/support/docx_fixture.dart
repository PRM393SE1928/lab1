import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Uint8List docxFixture({String? body, bool missingDocument = false}) {
  final archive = Archive();
  final xml = utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
${body ?? '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>3. Functional Requirements</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>3.2 Authentication</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading3"/></w:pPr><w:r><w:t>3.2.1 Login</w:t></w:r></w:p>
<w:p><w:r><w:t>Đăng nhập &amp; verify email</w:t><w:br/><w:t>Keep original wording.</w:t><w:tab/><w:t>Password</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading4"/></w:pPr><w:r><w:t>Table 1. Login rules</w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>BR-01</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Reject invalid credentials.</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:p><w:pPr><w:pStyle w:val="Heading3"/></w:pPr><w:r><w:t>3.2.2 Reset password</w:t></w:r></w:p>
<w:p><w:r><w:t>Send a reset code.</w:t></w:r></w:p>
'''}
</w:body></w:document>''');
  archive.addFile(
    ArchiveFile(
      missingDocument ? 'other.xml' : 'word/document.xml',
      xml.length,
      xml,
    ),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
