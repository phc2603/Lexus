using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;

namespace SmartGlassesUDP
{
    class Program
    {
        private const int DISCOVERY_PORT = 6000;
        private const int AUDIO_SEND_PORT = 5000;
        private const int AUDIO_RECEIVE_PORT = 5001;
        private const int CHUNK_SIZE = 8192;
        private const int HEADER_SIZE = 8;
        private const string DISCOVERY_REQUEST = "discover_smartglasses";
        private const string DISCOVERY_RESPONSE = "smartglasses_found";

        private static UdpClient responseReceiver;
        private static string lastClientIp = null;
        private static WaveInEvent waveIn;
        private static WaveFileWriter writer;
        private static MemoryStream memStream;
        private static bool isRecording = false;
        private static Dictionary<int, AudioAssembler> audioBuffers = new();

        [DllImport("user32.dll", SetLastError = true)]
        static extern short GetAsyncKeyState(int vKey);
        private const int VK_SPACE = 0x20;

        static void Main()
        {
            Console.WriteLine("=== SmartGlassesUDP iniciado ===");
            Console.WriteLine("Pressione ESPAÇO para gravar, solte para enviar e ouvir resposta.");

            StartDiscoveryListener();
            StartResponseListener();
            StartMainLoop();
        }

        static void StartResponseListener()
        {
            responseReceiver = new UdpClient(new IPEndPoint(IPAddress.Any, AUDIO_RECEIVE_PORT));
            responseReceiver.Client.ReceiveBufferSize = 2 * 1024 * 1024; // 2 MB

            Console.WriteLine($"🔊 Aguardando resposta em chunks na porta {AUDIO_RECEIVE_PORT}...");

            _ = Task.Run(async () =>
            {
                while (true)
                {
                    try
                    {
                        var result = await responseReceiver.ReceiveAsync();
                        var buffer = result.Buffer;

                        if (buffer.Length < HEADER_SIZE) continue;

                        int id = BitConverter.ToInt32(buffer, 0);
                        int totalChunks = BitConverter.ToUInt16(buffer, 4);
                        int currentChunk = BitConverter.ToUInt16(buffer, 6);
                        var chunkData = buffer[HEADER_SIZE..];

                        if (!audioBuffers.ContainsKey(id))
                        {
                            audioBuffers[id] = new AudioAssembler { TotalChunks = totalChunks };
                        }

                        var assembler = audioBuffers[id];
                        bool isComplete = assembler.AddChunk(chunkData, currentChunk);

                        if (isComplete)
                        {
                            var finalAudio = assembler.Reconstruct();
                            PlayWavFromBytes(finalAudio);
                            audioBuffers.Remove(id);
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"❌ Erro no chunk UDP: {ex.Message}");
                        await Task.Delay(100);
                    }
                }
            });
        }

        static void StartDiscoveryListener()
        {
            new Thread(() =>
            {
                using var udp = new UdpClient(DISCOVERY_PORT);
                var remoteEP = new IPEndPoint(IPAddress.Any, 0);

                while (true)
                {
                    try
                    {
                        byte[] data = udp.Receive(ref remoteEP);
                        string msg = Encoding.UTF8.GetString(data);

                        if (msg == DISCOVERY_REQUEST)
                        {
                            lastClientIp = remoteEP.Address.ToString();
                            Console.WriteLine($"🔍 Descoberto por {lastClientIp}");

                            byte[] response = Encoding.UTF8.GetBytes(DISCOVERY_RESPONSE);
                            udp.Send(response, response.Length, remoteEP);
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"❌ Erro discovery: {ex.Message}");
                    }
                }
            }).Start();
        }

        static void StartMainLoop()
        {
            bool wasPressed = false;

            while (true)
            {
                bool isPressed = (GetAsyncKeyState(VK_SPACE) & 0x8000) != 0;

                if (isPressed && !wasPressed)
                {
                    Console.WriteLine("🎙️ Iniciando gravação...");
                    memStream = new MemoryStream();
                    waveIn = new WaveInEvent
                    {
                        WaveFormat = new WaveFormat(16000, 16, 1)
                    };
                    writer = new WaveFileWriter(memStream, waveIn.WaveFormat);
                    waveIn.DataAvailable += (s, a) => writer.Write(a.Buffer, 0, a.BytesRecorded);
                    waveIn.StartRecording();
                    isRecording = true;
                }

                if (!isPressed && wasPressed && isRecording)
                {
                    Console.WriteLine("🛑 Parando gravação...");
                    waveIn.StopRecording();
                    waveIn.Dispose();
                    writer.Flush();
                    writer.Dispose();

                    byte[] audioBytes = memStream.ToArray();
                    memStream.Dispose();
                    isRecording = false;

                    if (!string.IsNullOrEmpty(lastClientIp))
                    {
                        Console.WriteLine($"📤 Enviando áudio em chunks para {lastClientIp}:{AUDIO_SEND_PORT}...");
                        using var sender = new UdpClient();
                        int id = new Random().Next();
                        int totalChunks = (int)Math.Ceiling((double)audioBytes.Length / CHUNK_SIZE);

                        for (int i = 0; i < totalChunks; i++)
                        {
                            int offset = i * CHUNK_SIZE;
                            int size = Math.Min(CHUNK_SIZE, audioBytes.Length - offset);
                            byte[] chunk = new byte[HEADER_SIZE + size];

                            BitConverter.GetBytes(id).CopyTo(chunk, 0);
                            BitConverter.GetBytes((ushort)totalChunks).CopyTo(chunk, 4);
                            BitConverter.GetBytes((ushort)i).CopyTo(chunk, 6);
                            Array.Copy(audioBytes, offset, chunk, HEADER_SIZE, size);

                            sender.Send(chunk, chunk.Length, lastClientIp, AUDIO_SEND_PORT);
                            Thread.Sleep(5);
                        }
                        Console.WriteLine("✅ Envio por chunks finalizado.");
                    }
                    else
                    {
                        Console.WriteLine("❌ Nenhum cliente detectado para envio.");
                    }
                }

                wasPressed = isPressed;
                Thread.Sleep(30);
            }
        }

        static void PlayWavFromBytes(byte[] wavBytes)
        {
            try
            {
                using var ms = new MemoryStream(wavBytes);
                using var reader = new WaveFileReader(ms);
                using var outputDevice = new WaveOutEvent();
                outputDevice.Init(reader);
                outputDevice.Play();

                while (outputDevice.PlaybackState == PlaybackState.Playing)
                    Thread.Sleep(50);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Erro na reprodução: {ex.Message}");
            }
        }

        class AudioAssembler
        {
            private readonly Dictionary<int, byte[]> _chunks = new();
            public int TotalChunks { get; set; }

            public bool AddChunk(byte[] chunkData, int index)
            {
                if (_chunks.ContainsKey(index)) return false;

                _chunks[index] = chunkData;
                return _chunks.Count == TotalChunks;
            }

            public byte[] Reconstruct()
            {
                using var ms = new MemoryStream();
                for (int i = 0; i < TotalChunks; i++)
                {
                    if (_chunks.TryGetValue(i, out var chunk))
                    {
                        ms.Write(chunk, 0, chunk.Length);
                    }
                    else
                    {
                        Console.WriteLine($"⚠️ Chunk {i} está faltando!");
                    }
                }
                return ms.ToArray();
            }
        }
    }
}