import 'package:flutter/material.dart';
import 'package:uber/model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  String _mensagemErro = "";
  bool _carregando = false;

  _validarCampos(){
    //recuperar dados dos campos
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    //valida campos
    if(email.isNotEmpty && email.contains("@")){
      if(senha.isNotEmpty && senha.length > 6){
        //se cair aqui cadastra usuario
        Usuario usuario = Usuario();
        usuario.email = email;
        usuario.senha = senha;

        //logar usuario
        _logarUsuario(usuario);

      }else{
        setState(() {
          _mensagemErro = "Preencha a senha e digite mais de 6 caracteres";
        });
      }
    }else{
      setState(() {
        _mensagemErro = "Preencha o E-mail válido";
      });
    }

  }

  _logarUsuario(Usuario usuario){

    setState(() {
      _carregando = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;

    auth.signInWithEmailAndPassword(
        email: usuario.email,
        password: usuario.senha
    ).then((firebaseUser){

      _redirecionaPainelPorTipoUsuario(firebaseUser.user.uid);
      
    }).catchError((error){
      setState(() {
        _carregando = false;
        _mensagemErro = "Erro ao logar usuario, verifique o e-mail e senha";
      });
    });

  }

  _redirecionaPainelPorTipoUsuario(String idUsuario) async{

    Firestore db = Firestore.instance;

    DocumentSnapshot snapshot = await db.collection("usuarios")
          .document(idUsuario)
          .get();
    Map<String, dynamic> dados = snapshot.data;
    String tipoUsurio = dados["tipoUsuario"];

    setState(() {
      _carregando = false;
    });

    switch(tipoUsurio){
      case "motorista":
        Navigator.pushReplacementNamed(context, "/painel-motorista");
        break;
      case "passageiro":
        Navigator.pushReplacementNamed(context, "/painel-passageiro");
        break;
    }

  }

  //Verifica se usuario já esta logado

  _verificaUsuarioLogado() async {

    FirebaseAuth auth = FirebaseAuth.instance;

    FirebaseUser usuarioLogado = await auth.currentUser();
    if(usuarioLogado != null){
      String idUsuario = usuarioLogado.uid;
      _redirecionaPainelPorTipoUsuario(idUsuario);
    }


  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _verificaUsuarioLogado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("image/fundo.png"),
            fit: BoxFit.cover
          )
        ),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Image.asset(
                      "image/logo.png",
                    width: 200,
                    height: 150,
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    hintText: "E-mail",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)
                    )
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _controllerSenha,
                    obscureText: true,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "Senha",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)
                        )
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                    child: Text(
                        "Entrar",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: Color(0xff1ebbd8),
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: (){
                      _validarCampos();
                    },
                  ),
                ),
                Center(
                  child: GestureDetector(
                    child: Text(
                        "Não tem conta? Cadastre-se!",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: (){
                      Navigator.pushNamed(context, "/cadastro");
                    },
                  ),
                ),
                _carregando
                ? Center(
                  child: CircularProgressIndicator(backgroundColor: Colors.white,),
                )
                : Container(),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _mensagemErro,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
