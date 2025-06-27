// main.c + audio_task.c juntos para envio UDP com gravação por botão em D23
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2s_std.h"
#include "driver/gpio.h"
#include "nvs_flash.h"
#include "esp_log.h"
#include "lwip/sockets.h"
#include "lwip/netdb.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "lwip/err.h"
#include "lwip/sys.h"

#define DISCOVERY_PORT 6000
#define AUDIO_SEND_PORT 5000
#define DISCOVERY_REQUEST "discover_smartglasses"
#define DISCOVERY_RESPONSE "smartglasses_found"
#define CHUNK_SIZE 8192
#define HEADER_SIZE 8
#define WIFI_SSID "Lemoscosonet"
#define WIFI_PASS "nettiigbn"
#define BUTTON_GPIO GPIO_NUM_23

static const char *TAG = "AUDIO_UDP";
static char last_client_ip[INET_ADDRSTRLEN] = "";
static i2s_chan_handle_t rx_handle;
static uint8_t *audio_buffer;

static void wifi_event_handler(void* arg, esp_event_base_t event_base,int32_t event_id, void* event_data);

static void wifi_init_sta(void)
{
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASS,
            .threshold.authmode = WIFI_AUTH_WPA2_PSK
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI("wifi", "wifi_init_sta finished.");
}

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI("wifi", "Disconnected. Trying to reconnect...");
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI("wifi", "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
    }
}

void init_i2s_inmp441() {
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, NULL, &rx_handle));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(16000),
        .slot_cfg = {
            .data_bit_width = I2S_DATA_BIT_WIDTH_16BIT,
            .slot_mode       = I2S_SLOT_MODE_MONO,
            .slot_mask       = I2S_STD_SLOT_LEFT,
            .ws_width        = I2S_DATA_BIT_WIDTH_16BIT,
            .ws_pol          = false,
            .bit_shift       = true
        },
        .gpio_cfg = {
            .mclk = GPIO_NUM_0,
            .bclk = GPIO_NUM_15,
            .ws   = GPIO_NUM_4,
            .dout = I2S_GPIO_UNUSED,
            .din  = GPIO_NUM_2,
            .invert_flags = { .bclk_inv = false, .ws_inv = false }
        },
    };

    ESP_ERROR_CHECK(i2s_channel_init_std_mode(rx_handle, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(rx_handle));

    audio_buffer = malloc(32000);
    if (!audio_buffer) {
        ESP_LOGE(TAG, "Falha ao alocar audio_buffer");
    }
}

void send_audio_udp(uint8_t *data, size_t len) {
    if (strlen(last_client_ip) == 0) return;

    struct sockaddr_in dest_addr;
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(AUDIO_SEND_PORT);
    inet_pton(AF_INET, last_client_ip, &dest_addr.sin_addr);

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (sock < 0) return;

    int id = esp_random();
    int total_chunks = (len + CHUNK_SIZE - 1) / CHUNK_SIZE;

    for (int i = 0; i < total_chunks; i++) {
        int offset = i * CHUNK_SIZE;
        int size = (len - offset > CHUNK_SIZE) ? CHUNK_SIZE : (len - offset);
        uint8_t *packet = malloc(HEADER_SIZE + size);

        memcpy(packet + 0, &id, 4);
        uint16_t total = total_chunks;
        uint16_t idx = i;
        memcpy(packet + 4, &total, 2);
        memcpy(packet + 6, &idx, 2);
        memcpy(packet + HEADER_SIZE, data + offset, size);

        sendto(sock, packet, HEADER_SIZE + size, 0, (struct sockaddr *)&dest_addr, sizeof(dest_addr));
        free(packet);
        vTaskDelay(pdMS_TO_TICKS(5));
    }

    close(sock);
}

void audio_record_task(void *arg) {
    const size_t chunk_size = 32000;
    while (1) {
        int pressed = gpio_get_level(BUTTON_GPIO) == 0;

        if (pressed) {
            size_t bytes_read = 0;
            ESP_LOGI(TAG, "🎙️ Gravando áudio...");
            i2s_channel_read(rx_handle, audio_buffer, chunk_size, &bytes_read, pdMS_TO_TICKS(1000));

            if (bytes_read > 0) {
                send_audio_udp(audio_buffer, bytes_read);
            }
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void udp_discovery_task(void *arg) {
    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    struct sockaddr_in server_addr, client_addr;
    socklen_t addr_len = sizeof(client_addr);

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(DISCOVERY_PORT);
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    bind(sock, (struct sockaddr *)&server_addr, sizeof(server_addr));

    char rx_buffer[128];
    while (1) {
        int len = recvfrom(sock, rx_buffer, sizeof(rx_buffer) - 1, 0,
                           (struct sockaddr *)&client_addr, &addr_len);
        if (len > 0) {
            rx_buffer[len] = 0;
            if (strcmp(rx_buffer, DISCOVERY_REQUEST) == 0) {
                inet_ntop(AF_INET, &client_addr.sin_addr, last_client_ip, sizeof(last_client_ip));
                ESP_LOGI(TAG, "Cliente descoberto: %s", last_client_ip);

                sendto(sock, DISCOVERY_RESPONSE, strlen(DISCOVERY_RESPONSE), 0,
                       (struct sockaddr *)&client_addr, addr_len);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void app_main(void) {
    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    gpio_config_t btn_cfg = {
        .pin_bit_mask = 1ULL << BUTTON_GPIO,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    ESP_ERROR_CHECK(gpio_config(&btn_cfg));

    wifi_init_sta(); 
    init_i2s_inmp441();
    xTaskCreate(audio_record_task, "audio_record", 8192, NULL, 5, NULL);
    xTaskCreate(udp_discovery_task, "udp_discovery", 8192, NULL, 5, NULL);
}