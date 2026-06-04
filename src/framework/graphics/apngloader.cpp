#include "apngloader.h"

#include "apng_png.hpp"

int load_apng(std::stringstream &file, apng_data *apng) {
  return png_load_apng(file, apng);
}

void save_png(std::stringstream &file, const uint32_t width,
              const uint32_t height, const int channels, uint8_t *pixels) {
  png_save(file, width, height, channels, pixels);
}

void free_apng(const apng_data *apng) {
  png_free_apng(apng);
}
