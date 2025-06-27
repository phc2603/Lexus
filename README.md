# Documentação Técnica do Projeto Lexus – Óculos Inteligente com Assistente de Voz

O projeto Lexus é uma solução de óculos inteligentes que integra hardware (Raspberry Orange com microfone e alto-falante) com software embarcado e um aplicativo Flutter para Android. O sistema é capaz de:

- Capturar áudio do usuário

- Enviar o áudio via UDP para o aplicativo Android

- Usar a API Gemini (via prompt) para gerar respostas inteligentes

- Retornar a resposta ao dispositivo via UDP, que a converte em áudio com a API Azure TTS

- Reproduzir a fala no alto-falante embutido nos óculos

## Estrutura do projeto

Lexus-master/
├── pubspec.yaml # Configuração do app Flutter<br>
├── SmartGlasses/ # Código do firmware dos óculos<br>
├── Documentação/ # Relatórios e documentação adicional<br>
├── apiKey.env # Chaves de API (Azure/Gemini)<br>


Aplicativo Flutter (Android)

## Dependências do projeto
- http	Requisições REST à API do Gemini
- flutter_tts	Para reprodução de texto como fala (fallback/local)
- udp ou raw_datagram_socket	Comunicação UDP
- dotenv	Leitura de chaves no apiKey.env
- system_media_controller Controlar widgets do celular, como pular de música, pausar
- volume_controller Obtém e controla o volume do android
- google_fonts Fontes do google para customizar os textos do APP


Arquivos .lib do programa:
- audioPhone.dart Para controlar o audio do android em comandos do gemini
- connection.dart Para conectar no IP do HOST do protocolo UDP via wifi
- geminiApi.dart Para conectar na API


## Lógica do projeto

- Existe uma aplicação no PC escrita em C#, responsável por hostear toda a aplicação, sendo um servidor UDP, com uma porta de broadcast
- Foi escrita outra aplicação em C#, para conectar nesta porta e ser a responsável pelo intermédio
- 












