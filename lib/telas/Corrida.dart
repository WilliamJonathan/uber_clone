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
  Position _localMotorista;

  //controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

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

      _exibeMarcadorPassageiro(position);

      _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(_posicaoCamera);

      setState(() {
        _localMotorista = position;
      });

    });

  }

  _recuperarUltimaLocalicaoConhecida() async{

    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if(position != null){

        _exibeMarcadorPassageiro(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );

        _movimentarCamera(_posicaoCamera);
        _localMotorista = position;

      }
    });

  }

  _movimentarCamera(CameraPosition cameraPosition) async{

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
            cameraPosition
        )
    );

  }

  _exibeMarcadorPassageiro(Position local) async{

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "image/motorista.png"
    ).then((BitmapDescriptor icone){

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );

      setState(() {
        _marcadores.add(marcadorPassageiro);
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

    _dadosRequisicao = documentSnapshot.data;
    _adicionarListenerRequisicao();

  }

  _adicionarListenerRequisicao() async{

    Firestore db = Firestore.instance;

    String idRequisicao = _dadosRequisicao["id"];
    await db.collection("requisicoes")
    .document(idRequisicao).snapshots().listen((snapshot){

      if(snapshot != null){

        Map<String, dynamic> dados = snapshot.data;
        String status = dados["status"];

        switch(status){
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
        }
    );

  }

  _statusAcaminho(){

    _alterarBotaoPrincipal(
        "A caminho do passageiro",
        Colors.grey,
        null
    );

  }

  _aceitarCorrida() async{

    //recuperar dados do motorista
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

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

    _recuperarUltimaLocalicaoConhecida();
    _adicionarListenerLocalizacao();

    //recuperar requisição e
    //adiciona listener para mudança de status
    _recuperarRequisicao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida"),
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
