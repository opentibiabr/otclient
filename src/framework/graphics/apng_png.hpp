#pragma once

#include <png.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <new>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

struct PngError : std::runtime_error {
  using std::runtime_error::runtime_error;
};

[[noreturn]] void pngErrorHandler(png_structp, png_const_charp message) {
  throw PngError(message ? message : "libpng error");
}

void pngWarningHandler(png_structp, png_const_charp) {}

struct MemoryReader {
  const uint8_t *data{nullptr};
  size_t size{0};
  size_t offset{0};
};

void readData(png_structp pngPtr, png_bytep output, png_size_t length) {
  const auto *reader =
      static_cast<const MemoryReader *>(png_get_io_ptr(pngPtr));
  if (!reader || reader->offset + length > reader->size)
    png_error(pngPtr, "png reader overflow");

  std::memcpy(output, reader->data + reader->offset, length);
  const_cast<MemoryReader *>(reader)->offset += length;
}

struct StreamWriter {
  std::stringstream *stream{nullptr};
};

void writeData(png_structp pngPtr, png_bytep data, png_size_t length) {
  auto *writer = static_cast<StreamWriter *>(png_get_io_ptr(pngPtr));
  if (!writer || !writer->stream)
    png_error(pngPtr, "png writer failure");

  writer->stream->write(reinterpret_cast<const char *>(data), length);
  if (!(*writer->stream))
    png_error(pngPtr, "png writer failure");
}

void flushData(png_structp pngPtr) {
  auto *writer = static_cast<StreamWriter *>(png_get_io_ptr(pngPtr));
  if (writer && writer->stream)
    writer->stream->flush();
}

struct PngReadGuard {
  png_structp pngPtr{nullptr};
  png_infop infoPtr{nullptr};

  PngReadGuard() = default;
  ~PngReadGuard() {
    if (pngPtr)
      png_destroy_read_struct(&pngPtr, infoPtr ? &infoPtr : nullptr, nullptr);
  }

  PngReadGuard(const PngReadGuard &) = delete;
  PngReadGuard &operator=(const PngReadGuard &) = delete;
  PngReadGuard(PngReadGuard &&) = delete;
  PngReadGuard &operator=(PngReadGuard &&) = delete;
};

struct PngWriteGuard {
  png_structp pngPtr{nullptr};
  png_infop infoPtr{nullptr};

  PngWriteGuard() = default;
  ~PngWriteGuard() {
    if (pngPtr)
      png_destroy_write_struct(&pngPtr, infoPtr ? &infoPtr : nullptr);
  }

  PngWriteGuard(const PngWriteGuard &) = delete;
  PngWriteGuard &operator=(const PngWriteGuard &) = delete;
  PngWriteGuard(PngWriteGuard &&) = delete;
  PngWriteGuard &operator=(PngWriteGuard &&) = delete;
};

void blendFrame(std::vector<uint8_t> &canvas,
                const std::vector<uint8_t> &framePixels,
                const png_uint_32 canvasWidth, const png_uint_32 frameWidth,
                const png_uint_32 frameHeight, const png_uint_32 xOffset,
                const png_uint_32 yOffset, const png_byte blendOp) {
  const size_t canvasStride = static_cast<size_t>(canvasWidth) * 4;
  const size_t frameStride = static_cast<size_t>(frameWidth) * 4;

  for (png_uint_32 y = 0; y < frameHeight; ++y) {
    auto *dest = canvas.data() +
                 (static_cast<size_t>(yOffset + y) * canvasStride) +
                 static_cast<size_t>(xOffset) * 4;
    const auto *src = framePixels.data() + static_cast<size_t>(y) * frameStride;

    if (blendOp == PNG_BLEND_OP_SOURCE) {
      std::memcpy(dest, src, frameStride);
      continue;
    }

    for (png_uint_32 x = 0; x < frameWidth; ++x) {
      const auto *s = src + static_cast<size_t>(x) * 4;
      auto *d = dest + static_cast<size_t>(x) * 4;

      const uint32_t srcAlpha = s[3];
      if (srcAlpha == 0)
        continue;
      if (srcAlpha == 255) {
        d[0] = s[0];
        d[1] = s[1];
        d[2] = s[2];
        d[3] = 255;
        continue;
      }

      const uint32_t invAlpha = 255 - srcAlpha;
      d[0] = static_cast<uint8_t>((s[0] * srcAlpha + d[0] * invAlpha) / 255);
      d[1] = static_cast<uint8_t>((s[1] * srcAlpha + d[1] * invAlpha) / 255);
      d[2] = static_cast<uint8_t>((s[2] * srcAlpha + d[2] * invAlpha) / 255);
      d[3] = static_cast<uint8_t>(
          std::min<uint32_t>(255, srcAlpha + (d[3] * invAlpha) / 255));
    }
  }
}

void clearRegion(std::vector<uint8_t> &canvas, const png_uint_32 canvasWidth,
                 const png_uint_32 frameWidth, const png_uint_32 frameHeight,
                 const png_uint_32 xOffset, const png_uint_32 yOffset) {
  const size_t canvasStride = static_cast<size_t>(canvasWidth) * 4;
  for (png_uint_32 y = 0; y < frameHeight; ++y) {
    auto *dest = canvas.data() +
                 (static_cast<size_t>(yOffset + y) * canvasStride) +
                 static_cast<size_t>(xOffset) * 4;
    std::fill(dest, dest + frameWidth * 4, 0);
  }
}

uint16_t delayToMilliseconds(const png_uint_16 numerator,
                             png_uint_16 denominator) {
  if (numerator == 0)
    return 0;

  if (denominator == 0)
    denominator = 100;

  const uint32_t milliseconds =
      (static_cast<uint32_t>(numerator) * 1000u) / denominator;
  return static_cast<uint16_t>(
      std::min<uint32_t>(milliseconds, std::numeric_limits<uint16_t>::max()));
}

int png_load_apng(std::stringstream &file, apng_data *apng) {
  if (!apng)
    return -1;

  std::memset(apng, 0, sizeof(*apng));

  const std::string buffer = file.str();
  if (buffer.empty())
    return -1;

  try {
    MemoryReader reader;
    reader.data = reinterpret_cast<const uint8_t *>(buffer.data());
    reader.size = buffer.size();

    PngReadGuard pngGuard;
    pngGuard.pngPtr = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr,
                                             nullptr, nullptr);
    if (!pngGuard.pngPtr)
      return -1;

    pngGuard.infoPtr = png_create_info_struct(pngGuard.pngPtr);
    if (!pngGuard.infoPtr)
      return -1;

    png_set_error_fn(pngGuard.pngPtr, nullptr, pngErrorHandler,
                     pngWarningHandler);
    png_set_read_fn(pngGuard.pngPtr, &reader, readData);

    png_read_info(pngGuard.pngPtr, pngGuard.infoPtr);

    png_uint_32 width = png_get_image_width(pngGuard.pngPtr, pngGuard.infoPtr);
    png_uint_32 height =
        png_get_image_height(pngGuard.pngPtr, pngGuard.infoPtr);
    int colorType = png_get_color_type(pngGuard.pngPtr, pngGuard.infoPtr);
    int bitDepth = png_get_bit_depth(pngGuard.pngPtr, pngGuard.infoPtr);

    if (bitDepth == 16)
      png_set_strip_16(pngGuard.pngPtr);
    if (colorType == PNG_COLOR_TYPE_PALETTE)
      png_set_palette_to_rgb(pngGuard.pngPtr);
    if (colorType == PNG_COLOR_TYPE_GRAY && bitDepth < 8)
      png_set_expand_gray_1_2_4_to_8(pngGuard.pngPtr);
    if (png_get_valid(pngGuard.pngPtr, pngGuard.infoPtr, PNG_INFO_tRNS))
      png_set_tRNS_to_alpha(pngGuard.pngPtr);
    if (!(colorType & PNG_COLOR_MASK_ALPHA))
      png_set_add_alpha(pngGuard.pngPtr, 0xFF, PNG_FILLER_AFTER);
    if (colorType == PNG_COLOR_TYPE_GRAY ||
        colorType == PNG_COLOR_TYPE_GRAY_ALPHA)
      png_set_gray_to_rgb(pngGuard.pngPtr);

    const png_uint_32 passes = png_set_interlace_handling(pngGuard.pngPtr);
    png_read_update_info(pngGuard.pngPtr, pngGuard.infoPtr);

    const int channels = png_get_channels(pngGuard.pngPtr, pngGuard.infoPtr);
    if (channels != 4)
      throw PngError("unexpected channel count");

    if (width == 0 || height == 0)
      throw PngError("invalid image dimensions");

    const size_t pixelCount =
        static_cast<size_t>(width) * static_cast<size_t>(height);
    if (pixelCount / width != height)
      throw PngError("image too large");

    const size_t frameStride = pixelCount * static_cast<size_t>(channels);

    bool hasAnimation =
        png_get_valid(pngGuard.pngPtr, pngGuard.infoPtr, PNG_INFO_acTL) != 0;
    png_uint_32 declaredFrames = 1;
    png_uint_32 plays = 0;
    png_uint_32 totalFrames = 1;
    png_byte hiddenFirst = 0;

    if (hasAnimation) {
      if (png_get_acTL(pngGuard.pngPtr, pngGuard.infoPtr, &declaredFrames,
                       &plays) == 0)
        hasAnimation = false;
      else {
        totalFrames = png_get_num_frames(pngGuard.pngPtr, pngGuard.infoPtr);
        hiddenFirst =
            png_get_first_frame_is_hidden(pngGuard.pngPtr, pngGuard.infoPtr);
        if (totalFrames < declaredFrames + hiddenFirst)
          totalFrames = declaredFrames + hiddenFirst;
      }
    }

    if (!hasAnimation) {
      declaredFrames = 1;
      plays = 0;
      totalFrames = 1;
      hiddenFirst = 0;
    }

    if (frameStride != 0 &&
        totalFrames > std::numeric_limits<size_t>::max() / frameStride)
      throw PngError("image too large");

    std::vector<uint8_t> canvas(frameStride, 0);
    std::vector<uint8_t> frames(totalFrames * frameStride, 0);
    std::vector<uint16_t> delays(hasAnimation ? declaredFrames : 0, 0);
    uint32_t delayIndex = 0;

    for (png_uint_32 frameIndex = 0; frameIndex < totalFrames; ++frameIndex) {
      if (hasAnimation)
        png_read_frame_head(pngGuard.pngPtr, pngGuard.infoPtr);

      png_uint_32 frameWidth = width;
      png_uint_32 frameHeight = height;
      png_uint_32 xOffset = 0;
      png_uint_32 yOffset = 0;
      png_uint_16 delayNum = 0;
      png_uint_16 delayDen = 100;
      png_byte disposeOp = PNG_DISPOSE_OP_NONE;
      png_byte blendOp = PNG_BLEND_OP_SOURCE;

      if (hasAnimation &&
          png_get_valid(pngGuard.pngPtr, pngGuard.infoPtr, PNG_INFO_fcTL)) {
        png_get_next_frame_fcTL(pngGuard.pngPtr, pngGuard.infoPtr, &frameWidth,
                                &frameHeight, &xOffset, &yOffset, &delayNum,
                                &delayDen, &disposeOp, &blendOp);
      }

      if (frameWidth == 0 || frameHeight == 0 || xOffset + frameWidth > width ||
          yOffset + frameHeight > height)
        throw PngError("invalid frame dimensions");

      std::vector<uint8_t> framePixels(frameWidth * frameHeight * channels);
      std::vector<png_bytep> rowPointers(frameHeight);
      for (png_uint_32 y = 0; y < frameHeight; ++y)
        rowPointers[y] =
            framePixels.data() + static_cast<size_t>(y) * frameWidth * channels;

      for (png_uint_32 pass = 0; pass < passes; ++pass) {
        for (png_uint_32 y = 0; y < frameHeight; ++y)
          png_read_row(pngGuard.pngPtr, rowPointers[y], nullptr);
      }

      auto composed = canvas;
      blendFrame(composed, framePixels, width, frameWidth, frameHeight, xOffset,
                 yOffset, blendOp);

      std::memcpy(frames.data() + static_cast<size_t>(frameIndex) * frameStride,
                  composed.data(), frameStride);

      if (hasAnimation) {
        const bool visible = !(hiddenFirst && frameIndex == 0);
        if (visible && delayIndex < delays.size())
          delays[delayIndex++] = delayToMilliseconds(delayNum, delayDen);
      }

      if (hasAnimation) {
        switch (disposeOp) {
        case PNG_DISPOSE_OP_NONE:
          canvas = std::move(composed);
          break;
        case PNG_DISPOSE_OP_BACKGROUND:
          canvas = std::move(composed);
          clearRegion(canvas, width, frameWidth, frameHeight, xOffset, yOffset);
          break;
        case PNG_DISPOSE_OP_PREVIOUS:
          break;
        default:
          canvas = std::move(composed);
          break;
        }
      } else {
        canvas = std::move(composed);
      }
    }

    png_read_end(pngGuard.pngPtr, pngGuard.infoPtr);

    if (hasAnimation && delayIndex < delays.size())
      std::fill(delays.begin() + delayIndex, delays.end(), 0);

    auto *pixelData = static_cast<uint8_t *>(std::malloc(frames.size()));
    if (!pixelData)
      throw std::bad_alloc();
    std::memcpy(pixelData, frames.data(), frames.size());

    uint16_t *delayData = nullptr;
    if (!delays.empty()) {
      delayData = static_cast<uint16_t *>(
          std::malloc(delays.size() * sizeof(uint16_t)));
      if (!delayData) {
        std::free(pixelData);
        throw std::bad_alloc();
      }
      std::memcpy(delayData, delays.data(), delays.size() * sizeof(uint16_t));
    }

    apng->pdata = pixelData;
    apng->frames_delay = delayData;

    apng->width = static_cast<uint32_t>(width);
    apng->height = static_cast<uint32_t>(height);
    apng->first_frame = static_cast<uint32_t>(hiddenFirst);
    apng->last_frame =
        totalFrames > 0 ? static_cast<uint32_t>(totalFrames - 1) : 0;
    apng->bpp = static_cast<uint8_t>(channels);
    apng->coltype = PNG_COLOR_TYPE_RGBA;
    apng->num_frames = hasAnimation ? static_cast<uint32_t>(declaredFrames) : 1;
    apng->num_plays = hasAnimation ? static_cast<uint32_t>(plays) : 0;

    return 0;
  } catch (...) {
    std::memset(apng, 0, sizeof(*apng));
  }

  return -1;
}

void png_save(std::stringstream &file, const uint32_t width,
              const uint32_t height, const int channels, uint8_t *pixels) {
  if (width == 0 || height == 0 || pixels == nullptr)
    throw PngError("invalid image");

  PngWriteGuard pngGuard;
  pngGuard.pngPtr =
      png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
  if (!pngGuard.pngPtr)
    throw PngError("failed to create png writer");

  pngGuard.infoPtr = png_create_info_struct(pngGuard.pngPtr);
  if (!pngGuard.infoPtr)
    throw PngError("failed to create png info");

  png_set_error_fn(pngGuard.pngPtr, nullptr, pngErrorHandler,
                   pngWarningHandler);

  StreamWriter writer{&file};
  png_set_write_fn(pngGuard.pngPtr, &writer, writeData, flushData);

  int colorType = PNG_COLOR_TYPE_RGBA;
  switch (channels) {
  case 1:
    colorType = PNG_COLOR_TYPE_GRAY;
    break;
  case 2:
    colorType = PNG_COLOR_TYPE_GRAY_ALPHA;
    break;
  case 3:
    colorType = PNG_COLOR_TYPE_RGB;
    break;
  case 4:
    colorType = PNG_COLOR_TYPE_RGBA;
    break;
  default:
    throw PngError("unsupported channel count");
  }

  png_set_IHDR(pngGuard.pngPtr, pngGuard.infoPtr, width, height, 8, colorType,
               PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
               PNG_FILTER_TYPE_DEFAULT);

  std::vector<png_bytep> rowPointers(height);
  const size_t rowStride =
      static_cast<size_t>(width) * static_cast<size_t>(channels);
  for (uint32_t y = 0; y < height; ++y)
    rowPointers[y] = pixels + y * rowStride;

  png_write_info(pngGuard.pngPtr, pngGuard.infoPtr);
  png_write_image(pngGuard.pngPtr, rowPointers.data());
  png_write_end(pngGuard.pngPtr, pngGuard.infoPtr);
}

void png_free_apng(const apng_data *apng) {
  if (apng->pdata)
    std::free(apng->pdata);
  if (apng->frames_delay)
    std::free(apng->frames_delay);
}

} // namespace

