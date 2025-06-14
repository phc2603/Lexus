import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'geminiApi.dart';

class UdpProtocolConnection {
  RawDatagramSocket? _socket;

  Future<void> startListening() async {
    final geminiLLM = GeminiAPI();
    geminiLLM.defineGeminiPrompt();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5000);
    print('Escutando na porta 4210...');

    _socket!.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          String message = String.fromCharCodes(datagram.data);
          print('Dados recebidos: $message');
          treatListenedMessage(message, geminiLLM);

        }
      }
    });
  }

  Future<void> treatListenedMessage(String message, GeminiAPI geminiLLM) async{
    final geminiResponse = await geminiLLM.treatMessageRecieved(message);
    sendData(geminiResponse, "123", 12);
  }

  /// Envia dados via UDP
  Future<void> sendData(String message, String targetIp, int targetPort) async {
    final RawDatagramSocket sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5000);
    Uint8List dataToSend = Uint8List.fromList(message.codeUnits);
    sendSocket.send(dataToSend, InternetAddress(targetIp), targetPort);
    print('Enviado: $message para $targetIp:$targetPort');
    sendSocket.close();
  }

  void dispose() {
    print('Fechando socket UDP...');
    _socket?.close();
  }
}
