import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'geminiApi.dart';
import 'udpProtocol.dart';

Future<void> main() async {
  //await dotenv.load();
  runApp(const HomePage());
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inicio',
      theme: ThemeData(primarySwatch: Colors.yellow),

      home: HomePageData(),
    );
  }
}

class HomePageData extends StatefulWidget {
  const HomePageData({super.key});
  @override
  State<HomePageData> createState() => _HomePageDataState();//stateful widget precisa retornar um createState
}

class _HomePageDataState extends State<HomePageData> {
  bool connectedToBluetooth = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFA7B49E),
      body: Center(
        child: GestureDetector(
          onTap: connectedToBluetooth ? null : () async {
            print("Círculo clicado!");
            //final x = GeminiAPI();
            //final aux = await x.defineGeminiPrompt();
            //final phrase = await x.geminiResponse("Quantos graus em belo horirzonte agora");
           // print(phrase);

            final x = UdpProtocolConnection();
            x.mostrarIpLocal();
            final z = x.sendData("aaa");
            print(z);

            //todo: criar e chamar método para conectar no bluetooth
            setState(() {
              connectedToBluetooth = false;
            });
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(connectedToBluetooth ? "Sucesso no emparelhamento" : "Erro no emparelhamento"),
                    content: Text(connectedToBluetooth ? "Bluetooth conectado! Desfrute da melhor experiência do Cyber Glass" : "Erro ao conectar no bluetooth"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          //todo: mudar a tela do plano de fundo, fazendo com que o botão fique desativado e o texto diferente
                          Navigator.of(context).pop(); // Fecha o diálogo
                        },
                        child: Text("Fechar",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold
                            ),
                        ),
                      ),
                    ],
                    backgroundColor: Colors.blue,
                  );
                },
              );
          },
          child: LayoutBuilder(
            builder: (context, constraints){
              double screenWidth = constraints.maxWidth;
              double screenHeight = constraints.maxHeight;
              double fontSize = screenWidth * 0.1;
              return Container(
                width: screenWidth * 0.7,
                height: screenHeight * 0.7,
                decoration: const BoxDecoration(
                  color: Color(0xFF9ACBD0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                      connectedToBluetooth ? "Conectado ao CyberGlass" : "Emparelhar",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                      textStyle: TextStyle(
                          color: Color(0xFF1D1616),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold
                      ),
                    )
                  ),
                ),
              );
            }
          )
        )
      ),
    );
  }
}


