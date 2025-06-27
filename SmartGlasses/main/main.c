#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/timers.h"
#include "driver/i2s_std.h"
#include "esp_log.h"
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_gap_bt_api.h"
#include "esp_bt_device.h"
#include "esp_spp_api.h"
#include "nvs_flash.h"

#define TAG "MIC_BT"
#define SAMPLE_RATE     8000
#define RECORD_SECONDS  5
#define BUFFER_SIZE     (SAMPLE_RATE * RECORD_SECONDS * sizeof(int16_t))

static TimerHandle_t record_timer;
static uint8_t* audio_buffer = NULL;
static uint32_t spp_handle = 0;
static i2s_chan_handle_t rx_handle = NULL;

static void init_i2s()
{
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, &rx_handle, NULL));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(SAMPLE_RATE),
        .slot_cfg = I2S_STD_MSB_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = 15,
            .ws = 4,
            .dout = I2S_GPIO_UNUSED,
            .din = 2,
            .invert_flags = {
                .mclk_inv = false,
                .bclk_inv = false,
                .ws_inv = false
            }
        }
    };

    ESP_ERROR_CHECK(i2s_channel_init_std_mode(rx_handle, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(rx_handle));
}

static void bt_event_handler(esp_spp_cb_event_t event, esp_spp_cb_param_t *param)
{
    switch (event) {
        case ESP_SPP_INIT_EVT:
            esp_spp_start_srv(ESP_SPP_SEC_NONE, ESP_SPP_ROLE_SLAVE, 0, "INMP441_BT");
            break;
        case ESP_SPP_OPEN_EVT:
            spp_handle = param->open.handle;
            ESP_LOGI(TAG, "Conexão Bluetooth aberta. Handle: %lu", (unsigned long)spp_handle);
            break;
        case ESP_SPP_DATA_IND_EVT:
            ESP_LOGI(TAG, "Recebido %d bytes via SPP", param->data_ind.len);
            break;
        default:
            break;
    }
}



static void init_bt()
{
    // Inicialize o NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Inicialize o controlador Bluetooth
    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    ret = esp_bt_controller_init(&bt_cfg);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Erro ao inicializar o controlador BT: %s", esp_err_to_name(ret));
        return;
    }

    // Habilite o controlador Bluetooth
    ret = esp_bt_controller_enable(ESP_BT_MODE_BTDM);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Erro ao habilitar o controlador BT: %s", esp_err_to_name(ret));
        return;
    }

    // Inicialize e habilite o Bluedroid
    ret = esp_bluedroid_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Erro ao inicializar o Bluedroid: %s", esp_err_to_name(ret));
        return;
    }

    ret = esp_bluedroid_enable();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Erro ao habilitar o Bluedroid: %s", esp_err_to_name(ret));
        return;
    }

}



static void record_and_send(TimerHandle_t xTimer)
{
    ESP_LOGI(TAG, "Iniciando gravação.");
    size_t bytes_read = 0;

    esp_err_t result = i2s_channel_read(rx_handle, audio_buffer, BUFFER_SIZE, &bytes_read, RECORD_SECONDS * 1000 / portTICK_PERIOD_MS);
    if (result == ESP_OK) {
        ESP_LOGI(TAG, "Gravação completa, %d bytes", bytes_read);
        if (spp_handle != 0) {
            esp_spp_write(spp_handle, bytes_read, audio_buffer);
            ESP_LOGI(TAG, "Áudio enviado via Bluetooth.");
        } else {
            ESP_LOGW(TAG, "Nenhuma conexão Bluetooth ativa.");
        }
    } else {
        ESP_LOGE(TAG, "Erro na leitura do I2S: %s", esp_err_to_name(result));
    }
}

void app_main(void)
{
    audio_buffer = (uint8_t*) malloc(BUFFER_SIZE);
    if (!audio_buffer) {
        ESP_LOGE(TAG, "Falha ao alocar buffer de áudio");
        return;
    }

    init_i2s();
    init_bt();

    record_timer = xTimerCreate("recorder", pdMS_TO_TICKS(5 * 60 * 1000), pdTRUE, NULL, record_and_send);
    xTimerStart(record_timer, 0);

    ESP_LOGI(TAG, "Sistema inicializado.");
}
