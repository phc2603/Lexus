import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:io';

class GeminiAPI{
  //static String? apiKey = dotenv.env["API_KEY"];
  static String? apiKey = "AIzaSyA32UT0ivrKPV6PXSpc8Qnisoaev4C6kxU";
  final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
  final headers = {
    'Content-Type': 'application/json',
  };

  List<Map<String, dynamic>> conversationHistory = [];
  void addToHistory(String role, String text) {
    conversationHistory.add({
      "role": role,
      "parts": [{"text": text}]
    });
  }

  Future<bool> defineGeminiPrompt() async{
    String content = "";
    try {
      content = await rootBundle.loadString("assets/geminiPrompt.txt");
    } catch (e) {
      print('Erro ao ler o arquivo: $e');
      return false;
    }
    addToHistory("user", content);
    final body = buildBodyRequest(conversationHistory);
    final response = await http.post(url, headers: headers, body: body);
    if (response != null) {
      final responseData = jsonDecode(response.body);
      addToHistory("model", responseData["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]);
    }
    return response.statusCode == 200;
  }


  Future<String> geminiResponse(String textToGemini) async {
    addToHistory("user", textToGemini);
    final body = buildBodyRequest(conversationHistory);
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final dataResponse = jsonDecode(response.body);
      final textReponse = dataResponse["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];
      addToHistory("model", textReponse);
      return textReponse;
    } else {
      print('Erro ${response.statusCode}: ${response.body}');
      return "Erro";
    }
  }

  String buildBodyRequest(text){
      return jsonEncode({
        'contents': text,
      });
  }
}
