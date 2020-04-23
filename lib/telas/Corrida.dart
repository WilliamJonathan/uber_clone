import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {

  String idRequisicao;

  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera = CameraPosition(
      target: LatLng(-23.563999, -46.653256)
  );
  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequisicao;
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;

  //controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _mensagemStatus = "";

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });

  }

  _onMapCreated(GoogleMapController controller){

    _controller.complete(controller);

  }

  _adicionarListenerLocalizacao(){

    var geolocator = Geolocator();
    var locationoptions = LocationOptions(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10
    );

    geolocator.getPositionStream(locationoptions).listen((Position position){

      if(position != null){

        if(_idRequisicao != null && _idRequisicao.isNotEmpty){

          if(_statusRequisicao != StatusRequisicao.AGUARDANDO){
            //atualiza local motorista
            UsuarioFirebase .atualizarDadosLocalizacao(
                _idRequisicao,
                position.latitude,
                position.longitude
            );
          }

        }else if(position != null){
          setState(() {
            _localMotorista = position;
          });
        }

      }
    });

  }

  _recuperarUltimaLocalicaoConhecida() async{

    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if(position != null){

      //atualizar a posição do motorista em tempo real

    }

  }

  _movimentarCamera(CameraPosition cameraPosition) async{

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
            cameraPosition
        )
    );

  }

  _exibeMarcador(Position local, String icone, String infoWindow) async{

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        icone
    ).then((BitmapDescriptor bitmapDescriptor){

      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: infoWindow
          ),
          icon: bitmapDescriptor
      );

      setState(() {
        _marcadores.add(marcador);
      });

    });

  }

  _recuperarRequisicao() async{

    String idRequisicao = widget.idRequisicao;

    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicoes")
        .document(idRequisicao)
        .get();


  }

  _adicionarListenerRequisicao() async{

    Firestore db = Firestore.instance;

    String idRequisicao = _dadosRequisicao["id"];
    await db.collection("requisicoes")
    .document(_idRequisicao).snapshots().listen((snapshot){

      if(snapshot != null){

        _dadosRequisicao = snapshot.data;

        Map<String, dynamic> dados = snapshot.data;
        _statusRequisicao = dados["status"];

        switch(_statusRequisicao){
          case StatusRequisicao.AGUARDANDO :
            _statusUberAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusAcaminho();
            break;
          case StatusRequisicao.VIAGEM :

            break;
          case StatusRequisicao.FINALIZADA :

            break;
        }

      }

    });

  }

  _statusUberAguardando(){

    _alterarBotaoPrincipal(
        "Aceitar corrida",
        Color(0xff1ebbd8),
            (){
          _aceitarCorrida();
        });

    double motoristaLat = _localMotorista.latitude;
    double motoristaLon = _localMotorista.longitude;
    Position position = Position(
      latitude: motoristaLat, longitude: motoristaLon
    );
    _exibeMarcador(
        position,
      "image/motorista.png",
      "motorista"
    );

    CameraPosition posicaoCamera = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 19
    );
    _movimentarCamera(posicaoCamera);

  }

  _statusAcaminho(){

    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida",
        Color(0xff1ebbd8),
        (){
          _iniciarCorrida();
        }
    );

    double latitudePassageiro =_dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro =_dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista =_dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista =_dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(
      LatLng(latitudeMotorista, longitudeMotorista),
      LatLng(latitudePassageiro, longitudePassageiro)
    );

    //southwest.latitude <= northheast.latitude
    var nLat , nLon, sLat, sLon;

    if(latitudeMotorista <= latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if(longitudeMotorista <= longitudePassageiro){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBounds(
      LatLngBounds(
          northeast: LatLng(nLat, nLon),//nordeste
          southwest: LatLng(sLat, sLon)//sudoeste
      )
    );

  }

  _iniciarCorrida(){

  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async{

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newLatLngBounds(
            latLngBounds,
            100
        )
    );

  }


  _exibirDoisMarcadores(LatLng latLngMotorista, LatLng latLngPassageiro){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "image/motorista.png"
    ).then((BitmapDescriptor icone){

      Marker marcadorMotorista = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLngMotorista.latitude, latLngMotorista.longitude),
          infoWindow: InfoWindow(
              title: "Local motorista"
          ),
          icon: icone
      );

      _listaMarcadores.add(marcadorMotorista);

    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "image/passageiro.png"
    ).then((BitmapDescriptor icone){

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLngPassageiro.latitude, latLngPassageiro.longitude),
          infoWindow: InfoWindow(
              title: "Local passageiro"
          ),
          icon: icone
      );

      _listaMarcadores.add(marcadorPassageiro);
      _movimentarCamera(CameraPosition(
        target: LatLng(latLngMotorista.latitude, latLngMotorista.longitude),
        zoom: 18
      ));

    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _aceitarCorrida() async{

    //recuperar dados do motorista
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _dadosRequisicao["motorista"]["latitude"];
    motorista.longitude = _dadosRequisicao["motorista"]["longitude"];

    Firestore db = Firestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes")
    .document(idRequisicao).updateData({
      "motorista" : motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO,
    }).then((_){

      //atualiza requisição ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa")
          .document(idPassageiro)
          .updateData({
          "status" : StatusRequisicao.A_CAMINHO,
      });

      //salva requisição ativa motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista")
          .document(idMotorista)
          .setData({
          "id_requisicao" : idRequisicao,
          "id_usuario" : idMotorista,
          "status" : StatusRequisicao.A_CAMINHO,
      });

    });

  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _idRequisicao = widget.idRequisicao;

    //adiciona listener para mudanças na requisição
    _adicionarListenerRequisicao();

    //_recuperarUltimaLocalicaoConhecida();
    _adicionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - " + _mensagemStatus),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Positioned(
                right: 0,
                left: 0,
                bottom: 0,
                child: Padding(
                  padding: Platform.isIOS
                      ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                      : EdgeInsets.all(10),
                  child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao,
                  ),
                )
            )
          ],
        ),
      ),
    );
  }
}
