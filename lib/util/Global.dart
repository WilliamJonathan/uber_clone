import 'package:geolocator/geolocator.dart';
class Global{
  Position _localUsuario;

  Global(this._localUsuario);

  global( {Position position} ){

  }

  Position get localUsuario => _localUsuario;

  set localUsuario(Position value) {
    _localUsuario = value;
  }


}
