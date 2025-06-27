import 'package:volume_controller/volume_controller.dart';

class VolumeControl {
  void setVolume(double value) {
    // value vai de /0.0 a 1.0 (0% a 100%)
    VolumeController().setVolume(value);
  }

  Future<double> getCurrentVolume() async {
    double currentVolume = await VolumeController().getVolume();//pega o volume atual do sistema
    return currentVolume;
  }

  Future<void> increaseVolume() async {
    double currentVolume = await getCurrentVolume();
    double newVolume = (currentVolume + 0.1).clamp(0.0, 1.0);
    VolumeController().setVolume(newVolume);
  }

  Future<void> decreaseVolume() async {
    double currentVolume = await getCurrentVolume();
    double newVolume = (currentVolume - 0.1).clamp(0.0, 1.0);
    VolumeController().setVolume(newVolume);
  }
}