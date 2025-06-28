# Documentação Técnica do Projeto Lexus – Óculos Inteligente com Assistente de Voz

O projeto Lexus é uma solução de óculos inteligentes que integra hardware (Raspberry Orange com microfone e alto-falante) com software embarcado e um aplicativo Flutter para Android. O sistema é capaz de:

- Capturar áudio do usuário

- Enviar o áudio via UDP para o aplicativo Android

- Usar a API Gemini (via prompt) para gerar respostas inteligentes

- Retornar a resposta ao dispositivo via UDP, que a converte em áudio com a API Azure TTS

- Reproduzir a fala no alto-falante embutido nos óculos

## Estrutura do projeto

├── pubspec.yaml # Configuração do app Flutter<br>
├── SmartGlasses/ # Código do firmware dos óculos<br>
├── Documentação/ # Relatórios e documentação adicional<br>
├── apiKey.env # Chaves de API (Azure/Gemini)<br>


## Aplicativo Flutter (Android)

Dependências do projeto
- http	Requisições REST à API do Gemini
- flutter_tts	Para reprodução de texto como fala (fallback/local)
- udp ou raw_datagram_socket	Comunicação UDP
- dotenv	Leitura de chaves no apiKey.env
- system_media_controller Controlar widgets do celular, como pular de música, pausar
- volume_controller Obtém e controla o volume do android
- google_fonts Fontes do google para customizar os textos do APP


Arquivos .lib do programa:
- audioPhone.dart
  - Para controlar o audio do android em comandos do gemini
  - Permite dar play, pause, pular para próxima ou anterior mídia.
  - Serve como controle remoto da reprodução de áudio.
- connection.dart
  - Para conectar no IP do HOST do protocolo UDP via wifi
  - Gerencia a tentativa de conexão com os óculos
  - Usa a classe SmartGlassesConnector
  - Interface para exibir o estado da conexão (conectado ou não)
- geminiApi.dart
  - Para conectar na API
  - Enviar requisições para a API do Google Gemini (modelo de IA generativa)
  - Usa métodos HTTP POST
  - Depende de audioPhone.dart e volumePhone.dart, sugerindo que respostas da IA podem controlar o áudio e o volume do telefone.
- main.dart
  - Arquivo principal renderizando o front do APP com os botões e a navigation bar
  - Inicia o app com o tema escuro
  - Usa duas páginas: ConnectionPage e UserProfilePage
  - Define o título como “Lexus Smart Glasses”
- profile.dart
  - Tela de perfil do usuário
  - Permite ao usuário visualizar ou alterar seu perfil (nome, idade, estado etc.)
  - Permite capturar uma imagem com o ImagePicker
- SmartGlassesConnector.dart
  - Tela princial do APP
  - Descoberta de dispositivos "Smart Glasses" via UDP
  - Recebimento e resposta de áudio usando sockets (RawDatagramSocket)
  - Comunicação com uma API externa (geminiApi.dart)
- volumePhone.dart
  - Controlador de volume do celular
  - Ajusta o volume do sistema com a biblioteca volume_controller
  - Pode aumentar ou consultar o volume atual

## Lógica do projeto

O projeto consiste em uma aplicação C# que ocupa o papel de host para um protocolo UDP, sendo o broadcaster, transmitindo as mensagens nas redes para os dispositivos conectados.
O protocolo UDP possui baixa latência e alta velocidade, sendo interessante para transmissão que usufruem de fortes conexões e dependências de internet. Como o Lexus funciona em forma de um assistente de voz, integrado com uma LLM, são usadas diversas apis para aprendizado de máquina e Text to Speech.
Dessa forma, o uso de UDP para transmissão dos comandos de voz são muito eficientes, apesar de não garantir a entrega da mensagem e ser aberto para qualquer usuário da rede.

Foi feita uma outra aplicação em C# para ser o publisher e subscriber da arquitetura do projeto. Ela é responsável por conectar no host UDP e, através do microfone do sistema, faz a leitura de voz do usuário. Via desktop, ele utiliza o microfone padrão e quando o projeto foi implementado no Orange Pi, foi utilizado
o módulo Max4466. A aplicação envia um vetor de bytes para a rede UDP, contendo toda a informação que o usuário falou. Para engatilhar o momento de fala, pode ser segurada a barra de espaço no computador, ou um push bottom no microcontrolador.

Como agente principal, foi criado um APP mobile em flutter/dart, para servir como subscriber do modelo acima. Esse APP possui uma interface gráfica responsiva, para que o usuário possa fazer cadastro preenchendo seus dados e, posteriormente, conectar no host UDP.
O APP é subscriber da aplicação em C#, recebendo um vetor de bytes representando a fala do usuário. Esse vetor de bytes é tratado, e é convertido para string, para que, enfim, possa ser feita uma requisição via HTTP para a API do Gemini, que está treinada para ser uma assistente de voz com acesso à internet e algumas
funções do celular do usuário. 

Quando a resposta final é retornada pelo modelo do Gemini, a mensagem é enviada para a rede UDP, em que a aplicação C# recebe e faz um novo tratamento, convertendo o vetor de bytes recebido para string. Posteriormente, é feita uma requisição HTTP para uma API da Azure, enviando a String para que seja aplicada a lógica
do text to speech. Esta é uma API Rest que converte o texto em fala, utilizando vozes pré-gravadas pela própria azure.













