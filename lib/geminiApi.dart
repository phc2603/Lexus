import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'volumePhone.dart';
import 'audioPhone.dart';

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

  Future<String> treatMessageRecieved(String message) async {
    final geminiReturnMessage = await geminiResponse(message);
    if (geminiReturnMessage.contains("Erro")){
      print("Algo deu errado!");
      return "!-Ok";
    }
    if (geminiReturnMessage.startsWith("!")){
      treatCommand(geminiReturnMessage);
      return "!+Ok";
    }
    return geminiReturnMessage;
  }

  Future<void> treatCommand(geminiMessage) async{
    final volumeControl = VolumeControl();
    final systemMediaControl = SystemMedia();
    String geminiMessageLowerCase = geminiMessage.toLowerCase();
    if (geminiMessageLowerCase.contains("volume")){
      geminiMessageLowerCase.contains("+") ? volumeControl.increaseVolume() : volumeControl.decreaseVolume();
    }
    else if (geminiMessageLowerCase.contains("pause")){
      systemMediaControl.pause();
    }
    else if (geminiMessageLowerCase.contains("skip")){
      systemMediaControl.skipNext();
    }
    else if (geminiMessageLowerCase.contains("back")){
      systemMediaControl.skipPrevious();
    }
    else if (geminiMessageLowerCase.contains("play")){
      systemMediaControl.play();
    }
  }

  String buildBodyRequest(text){
      return jsonEncode({
        'contents': text,
      });
  }
}
