#include "apngloader.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <new>
#include <stdexcept>
#include <utility>
#include <vector>

#include "apng_png.hpp"

#ifndef PNG_APNG_SUPPORTED
#error "libpng must be built with APNG support"
#endif

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
