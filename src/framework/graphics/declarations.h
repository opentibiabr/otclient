/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma once

#include "glutil.h"
#include <framework/global.h>

enum class CompositionMode
{
    NORMAL,
    MULTIPLY,
    ADD,
    REPLACE,
    DESTINATION_BLENDING,
    LIGHT
};

enum class DrawMode
{
    NONE = GL_NONE,
    TRIANGLES = GL_TRIANGLES,
    TRIANGLE_STRIP = GL_TRIANGLE_STRIP
};

enum class BlendEquation
{
    ADD = GL_FUNC_ADD,
    MAX = GL_MAX,
    MIN = GL_MIN,
    SUBTRACT = GL_FUNC_SUBTRACT,
    REVER_SUBTRACT = GL_FUNC_REVERSE_SUBTRACT,
};

enum class DrawPoolType : uint8_t
{
    MAP,
    CREATURE_INFORMATION,
    LIGHT,
    FOREGROUND_MAP,
    FOREGROUND,
    LAST
};

enum DrawOrder : uint8_t
{
    FIRST,  // GROUND
    SECOND, // BORDER
    THIRD,  // BOTTOM & TOP
    FOURTH, // TOP ~ TOP
    FIFTH,  // ABOVE ALL - MISSILE
    LAST
};

enum class ShaderType
{
    VERTEX = GL_VERTEX_SHADER,
    FRAGMENT = GL_FRAGMENT_SHADER
};

class Texture;
class TextureManager;
class Image;
class AnimatedTexture;
class BitmapFont;
class CachedText;
class FrameBuffer;
class FrameBufferManager;
class Shader;
class ShaderProgram;
class PainterShaderProgram;
class Particle;
class ParticleType;
class ParticleEmitter;
class ParticleAffector;
class ParticleSystem;
class ParticleEffect;
class ParticleEffectType;
class SpriteSheet;
class DrawPool;
class DrawPoolManager;
class CoordsBuffer;
class ApplicationDrawEvents;
class ApplicationContext;
class GraphicalApplicationContext;
class TextureAtlas;
class AtlasRegion;

using ImagePtr = std::shared_ptr<Image>;
using TexturePtr = std::shared_ptr<Texture>;
using TextureAtlasPtr = std::shared_ptr<TextureAtlas>;
using AnimatedTexturePtr = std::shared_ptr<AnimatedTexture>;
using BitmapFontPtr = std::shared_ptr<BitmapFont>;
using CachedTextPtr = std::shared_ptr<CachedText>;
using FrameBufferPtr = std::shared_ptr<FrameBuffer>;
using ShaderPtr = std::shared_ptr<Shader>;
using ShaderProgramPtr = std::shared_ptr<ShaderProgram>;
using PainterShaderProgramPtr = std::shared_ptr<PainterShaderProgram>;
using ParticlePtr = std::shared_ptr<Particle>;
using ParticleTypePtr = std::shared_ptr<ParticleType>;
using ParticleEmitterPtr = std::shared_ptr<ParticleEmitter>;
using ParticleAffectorPtr = std::shared_ptr<ParticleAffector>;
using ParticleSystemPtr = std::shared_ptr<ParticleSystem>;
using ParticleEffectPtr = std::shared_ptr<ParticleEffect>;
using SpriteSheetPtr = std::shared_ptr<SpriteSheet>;
using ApplicationDrawEventsPtr = std::shared_ptr<ApplicationDrawEvents>;
using ApplicationContextPtr = std::shared_ptr<ApplicationContext>;
using GraphicalApplicationContextPtr = std::shared_ptr<GraphicalApplicationContext>;
using CoordsBufferPtr = std::shared_ptr<CoordsBuffer>;
using ParticleEffectTypePtr = std::shared_ptr<ParticleEffectType>;

using ShaderList = std::vector<ShaderPtr>;