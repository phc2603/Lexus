import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';


class BluetoothConnection {
  final flutterReactiveBle = FlutterReactiveBle();
  final serviceUuid = Uuid.parse("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");
  final characteristicUuid = Uuid.parse("YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY");
  //final espCharacteristic;

  Future<void> initBluetooth() async {

    await Permission.bluetooth.request();
    await Permission.locationWhenInUse.request(); // necessário em Android


    flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      if (device.name == 'Bluedroid_conn') {
        print('Encontrado: ${device.name} - ${device.id}');
        connectToDevice(device.id);
      }
    });
  }

  void connectToDevice(String deviceId) {
    final connection = flutterReactiveBle.connectToDevice(id: deviceId);
    connection.listen((connectionState) {
      print('Estado: ${connectionState.connectionState}');
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        print('Conectado com sucesso!');
        // Descubra serviços e leia ou escreva características aqui
      }
    });
  }

  void buildCharacteristics(){
    //espCharacteristic =
  }

}

