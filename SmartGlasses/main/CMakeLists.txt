idf_component_register(
    SRCS "main.c"
    INCLUDE_DIRS "."
    REQUIRES bt driver freertos nvs_flash
)
