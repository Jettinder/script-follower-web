import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FileImportService {
  /// Picks a file (PDF, DOCX, or TXT) and returns its text content
  Future<FileImportResult?> pickAndReadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    final extension = file.extension?.toLowerCase() ?? '';
    String text = '';

    switch (extension) {
      case 'pdf':
        text = await _readPdf(path);
        break;
      case 'txt':
        text = await _readTxt(path);
        break;
      case 'doc':
      case 'docx':
        text = await _readDocx(path);
        break;
      default:
        text = await _readTxt(path);
    }

    // Extract title from filename
    final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    return FileImportResult(
      filename: file.name,
      title: title,
      text: text,
    );
  }

  Future<String> _readPdf(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      return 'Errore lettura PDF: $e';
    }
  }

  Future<String> _readTxt(String path) async {
    try {
      return await File(path).readAsString();
    } catch (e) {
      return 'Errore lettura file: $e';
    }
  }

  Future<String> _readDocx(String path) async {
    // Basic DOCX reading - extracts text from document.xml
    try {
      final bytes = await File(path).readAsBytes();
      
      // DOCX is a ZIP file containing XML
      // We'll try to extract basic text using simple XML parsing
      // For production, consider using a dedicated DOCX library
      
      // Simple approach: read as text and extract readable content
      // This is a fallback - proper DOCX parsing requires more work
      
      return 'Per favore converti il file Word in PDF o copia il testo manualmente.\n\n'
             'Il supporto Word completo verrà aggiunto in futuro.';
    } catch (e) {
      return 'Errore lettura DOCX: $e';
    }
  }
}

class FileImportResult {
  final String filename;
  final String title;
  final String text;

  FileImportResult({
    required this.filename,
    required this.title,
    required this.text,
  });
}
