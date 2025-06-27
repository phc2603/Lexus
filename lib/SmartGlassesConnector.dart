import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'geminiApi.dart';

class SmartGlassesConnector {
  static const discoveryPort = 6000;
  static const audioReceivePort = 5000;
  static const audioResponsePort = 5001;
  static const discoveryRequest = 'discover_smartglasses';
  static const discoveryResponse = 'smartglasses_found';

  RawDatagramSocket? _receiverSocket;
  String? _smartGlassesIp;
  final GeminiAPI _gemini;

  SmartGlassesConnector(this._gemini);

  String? get smartGlassesIp => _smartGlassesIp;
  final List<String> transcriptionQueue = [];
  final Map<int, List<List<int>>> _receivedChunks = {};
  final Map<int, int> _expectedChunks = {};

  Future<void> start() async {
    await _discoverDevice();
    if (_smartGlassesIp == null) {
      print('❌ Dispositivo SmartGlasses não encontrado.');
      return;
    }

    print('✅ Conectado a $_smartGlassesIp');
    _receiverSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, audioReceivePort);
    _receiverSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _receiverSocket!.receive();
        if (datagram != null) {
          _handleChunk(datagram.data);
        }
      }
    });

    print('🎧 Aguardando áudios em $audioReceivePort...');
  }

  Future<void> _discoverDevice() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final message = utf8.encode(discoveryRequest);
    socket.send(Uint8List.fromList(message), InternetAddress("255.255.255.255"), discoveryPort);
    print('🔍 Enviando broadcast para descoberta...');

    final completer = Completer<String?>();
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final response = utf8.decode(datagram.data);
          if (response == discoveryResponse) {
            completer.complete(datagram.address.address);
            socket.close();
          }
        }
      }
    });

    _smartGlassesIp = await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
  }

  void _handleChunk(Uint8List data) {
    final id = ByteData.sublistView(data, 0, 4).getUint32(0, Endian.little);
    final total = ByteData.sublistView(data, 4, 6).getUint16(0, Endian.little);
    final index = ByteData.sublistView(data, 6, 8).getUint16(0, Endian.little);
    final chunk = data.sublist(8);

    _receivedChunks.putIfAbsent(id, () => List.generate(total, (_) => []))[index] = chunk;
    _expectedChunks[id] = total;

    final received = _receivedChunks[id]!;
    if (received.where((c) => c.isNotEmpty).length == total) {
      final full = received.expand((e) => e).toList();
      print("📥 Áudio completo recebido (${full.length} bytes), processando...");
      _handleAudio(Uint8List.fromList(full));
      _receivedChunks.remove(id);
      _expectedChunks.remove(id);
    }
  }

  void _handleAudio(Uint8List data) async {
    final transcript = await transcribeAudio(data);

    if (transcript != null && transcript.isNotEmpty) {
      transcriptionQueue.add(transcript);
      print("Transcrição: $transcript");

      final geminiResponse = await _gemini.treatMessageRecieved(transcript);
      print("Lexus disse: $geminiResponse");

      final rawPcm = await textToSpeechAzure(geminiResponse);
      final responseAudio = rawPcm != null ? addWavHeader(rawPcm) : null;

      if (responseAudio != null)
      {
        await _sendInChunks(responseAudio, InternetAddress(_smartGlassesIp!), audioResponsePort);
      }
    }
  }

  Future<void> _sendInChunks(Uint8List data, InternetAddress ip, int port) async {
    const chunkSize = 1400;
    final totalChunks = (data.length / chunkSize).ceil();
    final id = Random().nextInt(1 << 31);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
    print("IP: ${ip} (PORTA: ${port})");
    print("Porta local usada: ${socket.port} (interface: ${socket.address.address})");

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, data.length);
      final chunk = data.sublist(start, end);

      final header = BytesBuilder();
      final byteData = ByteData(8);
      byteData.setUint32(0, id, Endian.little);
      byteData.setUint16(4, totalChunks, Endian.little);
      byteData.setUint16(6, i, Endian.little);
      header.add(byteData.buffer.asUint8List());
      header.add(chunk);

      final packet = header.toBytes();
      //print("📤 Enviando chunk $i para ${ip.address}:$port | totalChunks: $totalChunks");
      socket.send(packet, ip, port);
      await Future.delayed(Duration(milliseconds: 5));
    }
    await Future.delayed(const Duration(seconds: 3));
    socket.close();
    print("✅ Envio de áudio em blocos finalizado.");
  }

  Future<String?> transcribeAudio(Uint8List data) async {
    const azureKey = '937lRJcOpd9YQw5CDXtj5uvrvrFgDXfYJNaFjs75D1ZV61m5wUMAJQQJ99BFACZoyfiXJ3w3AAAYACOGfTpV';
    const azureRegion = 'brazilsouth';

    final uri = Uri.parse(
      'https://$azureRegion.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=pt-BR',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Ocp-Apim-Subscription-Key': azureKey,
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        },
        body: data,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['DisplayText'] ?? '';
      }
    } catch (e) {
      print('❌ Erro ao transcrever: $e');
    }
    return null;
  }

  Future<Uint8List?> textToSpeechAzure(String text) async {
    const azureKey = '937lRJcOpd9YQw5CDXtj5uvrvrFgDXfYJNaFjs75D1ZV61m5wUMAJQQJ99BFACZoyfiXJ3w3AAAYACOGfTpV';
    const region = 'brazilsouth';
    final uri = Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1');

    final ssml = '''<speak version='1.0' xml:lang='pt-BR'><voice xml:lang='pt-BR' xml:gender='Male' name='pt-BR-FabioNeural'>${text.replaceAll('&', '&amp;')}</voice></speak>''';

    final response = await http.post(uri, headers: {
      'Ocp-Apim-Subscription-Key': azureKey,
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': 'raw-16khz-16bit-mono-pcm',
      'User-Agent': 'SmartGlassesApp'
    }, body: ssml);

    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  Uint8List addWavHeader(Uint8List pcm, {int sampleRate = 16000, int bits = 16, int channels = 1}) {
    final byteRate = sampleRate * channels * bits ~/ 8;
    final blockAlign = channels * bits ~/ 8;
    final dataSize = pcm.length;

    final header = BytesBuilder();
    header.add(ascii.encode('RIFF'));
    header.add(_intToBytes(36 + dataSize, 4));
    header.add(ascii.encode('WAVE'));
    header.add(ascii.encode('fmt '));
    header.add(_intToBytes(16, 4));
    header.add(_intToBytes(1, 2));
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bits, 2));
    header.add(ascii.encode('data'));
    header.add(_intToBytes(dataSize, 4));
    header.add(pcm);

    return header.toBytes();
  }

  Uint8List _intToBytes(int value, int bytes) {
    final data = ByteData(bytes);
    if (bytes == 2) data.setInt16(0, value, Endian.little);
    if (bytes == 4) data.setInt32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  void dispose() => _receiverSocket?.close();
}
