import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String nome = "Pedro";
  String sobrenome = "Caillaux";
  int idade = 22;
  String dataNascimento = "26/03/2003";
  String pais = "Brasil";
  String estado = "Minas Gerais";
  String cidade = "Belo Horizonte";

  File? imagemPerfil;

  Future<void> escolherImagem() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imagemPerfil = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Usuário'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: escolherImagem,
              child: CircleAvatar(
                radius: 60,
                backgroundImage:
                imagemPerfil != null ? FileImage(imagemPerfil!) : AssetImage('assets/image1.png'),
                child: imagemPerfil == null
                    ? null
                    : null,
                backgroundColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            buildInfoTile("Nome", nome),
            buildInfoTile("Sobrenome", sobrenome),
            buildInfoTile("Idade", idade.toString()),
            buildInfoTile("D"
                "ata de nascimento", dataNascimento),
            buildInfoTile("País", pais),
            buildInfoTile("Estado", estado),
            buildInfoTile("Cidade", cidade),
          ],
        ),
      ),
    );
  }

  Widget buildInfoTile(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 3,
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
