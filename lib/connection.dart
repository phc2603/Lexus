import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'SmartGlassesConnector.dart';
import 'geminiApi.dart';

late SmartGlassesConnector connector;

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool connectedToGlassByUdp = false;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    connector = SmartGlassesConnector(GeminiAPI());
  }

  @override
  void dispose() {
    connector.dispose();
    super.dispose();
  }

  void startConnection() async {
    setState(() {
      isConnecting = true;
    });

    await connector.start();

    setState(() {
      connectedToGlassByUdp = connector.smartGlassesIp != null;
      isConnecting = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2c5364),
        title: const Text(
          "Conexão realizada",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Agora você está conectado ao Lexus Smart Glasses!",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Lexus Glass",
                style: GoogleFonts.orbitron(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: connectedToGlassByUdp ? Colors.greenAccent : Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: connectedToGlassByUdp
                          ? Colors.greenAccent.withOpacity(0.5)
                          : Colors.blueAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: isConnecting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    connectedToGlassByUdp ? "Conectado" : "Emparelhar",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (!connectedToGlassByUdp && !isConnecting)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: startConnection,
                  child: const Text(
                    "Conectar ao Lexus",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              if (connectedToGlassByUdp)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 40),
            ],
          ),
        ),
      ),
    );
  }
}
