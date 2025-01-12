import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// A service to call your RAG backend (FastAPI + Haystack).
class RagService {
  // Adjust base URL to your local dev or production server
  static const String _baseUrl = 'http://127.0.0.1:8000';

  /// Upload a PDF via multipart to /upload-pdf
  static Future<bool> uploadPdf(File pdfFile) async {
    try {
      final uri = Uri.parse("$_baseUrl/upload-pdf");
      final request = http.MultipartRequest("POST", uri);

      final fileStream = http.ByteStream(pdfFile.openRead());
      final length = await pdfFile.length();
      final fileName = pdfFile.path.split('/').last;

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        length,
        filename: fileName,
      );

      request.files.add(multipartFile);

      final response = await request.send();
      if (response.statusCode == 200) {
        // success
        return true;
      } else {
        // error
        final responseBody = await response.stream.bytesToString();
        print('Upload PDF failed: ${response.statusCode} $responseBody');
        return false;
      }
    } catch (e) {
      print('Error uploading PDF: $e');
      return false;
    }
  }

  /// Send a query to /query endpoint
  /// Provide the user query, selected text, etc.
  static Future<String> queryRag({
    required String userQuery,
    required String selectedText,
    required String bookTitle,
    required int pageNumber,
    required int totalPages,
    required String aiName,
    required String aiPersonality,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/query");
      final body = {
        "user_query": userQuery,
        "selected_text": selectedText,
        "book_title": bookTitle,
        "page_number": pageNumber,
        "total_pages": totalPages,
        "ai_name": aiName,
        "ai_personality": aiPersonality,
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        final answer = jsonResp["answer"] ?? "No answer found.";
        return answer;
      } else {
        print('Query RAG failed: ${response.statusCode} ${response.body}');
        return "Error: ${response.statusCode}";
      }
    } catch (e) {
      print('Error calling RAG: $e');
      return "Error: $e";
    }
  }
}
