import 'package:system_media_controller/system_media_controller.dart';

class SystemMedia{
  final _systemMediaController = SystemMediaController();

  void play(){
    _systemMediaController.play();
  }

  void pause(){
    _systemMediaController.pause();
  }

  void skipNext(){
    _systemMediaController.skipNext();
  }

  void skipPrevious(){
    _systemMediaController.skipPrevious();
  }
}
