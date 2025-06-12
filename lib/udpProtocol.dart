import 'dart:io';
import 'dart:convert';

class UdpProtocolConnection {
  String ipv4Connection = "192.168.138.131";
  int gate = 5000;

  Future<String> listenToData() async {
    print("chegou");
    var serverSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, gate);
    await for (RawSocketEvent event in serverSocket) {
      if (event == RawSocketEvent.read) {
        final datagram = serverSocket.receive();
        if (datagram != null) {
          final message = utf8.decode(datagram.data);

          return message;
        }
      }
    }
    return "";
  }

  Future<void> sendData(String message) async {
    final socket = await RawDatagramSocket.bind(ipv4Connection, gate);

    final bytes = utf8.encode(message);

    // Envia para o servidor
    socket.send(bytes, InternetAddress(ipv4Connection), gate);
    print('Mensagem enviada para $ipv4Connection:$gate');
    socket.close();
  }

  Future<void> mostrarIpLocal() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        print('IP: ${addr.address}');
      }
    }
  }

}


