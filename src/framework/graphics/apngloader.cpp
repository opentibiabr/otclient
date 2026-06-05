#include "apngloader.h"

#include "apng_png.hpp"
#include <framework/stdext/exception.h>

#ifndef USE_PRECOMPILED_HEADERS
#include <exception>
#endif

int load_apng(std::stringstream &file, apng_data *apng) {
  return png_load_apng(file, apng);
}

void save_png(std::stringstream &file, const uint32_t width,
              const uint32_t height, const int channels, uint8_t *pixels) {
  try {
    png_save(file, width, height, channels, pixels);
  } catch (const std::exception &e) {
    throw Exception("failed to save PNG: {}", e.what());
  }
}

void free_apng(const apng_data *apng) {
  png_free_apng(apng);
}
