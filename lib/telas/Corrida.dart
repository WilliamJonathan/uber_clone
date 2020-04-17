import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/util/StatusRequisicao.dart';

class Corrida extends StatefulWidget {
  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _recuperarUltimaLocalicaoConhecida();
    _adicionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
