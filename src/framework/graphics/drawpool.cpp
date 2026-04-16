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

#include "drawpool.h"

#include "painter.h"
#include "textureatlas.h"

DrawPool* DrawPool::create(const DrawPoolType type)
{
    auto pool = new DrawPool;
    if (type == DrawPoolType::MAP || type == DrawPoolType::FOREGROUND) {
        pool->setFramebuffer({});
        if (type == DrawPoolType::MAP) {
            pool->m_framebuffer->m_useAlphaWriting = false;
            pool->m_framebuffer->disableBlend();
        } else if (type == DrawPoolType::FOREGROUND) {
            pool->setFPS(10);

            // creates a temporary framebuffer with smoothing.
            pool->m_temporaryFramebuffers.emplace_back(std::make_shared<FrameBuffer>());
        }
    } else if (type == DrawPoolType::LIGHT) {
        pool->m_hashCtrl = true;
    } else {
        pool->m_alwaysGroupDrawings = true; // CREATURE_INFORMATION & TEXT
        pool->setFPS(500);
    }

    pool->m_type = type;
    return pool;
}

void DrawPool::add(const Color& color, const TexturePtr& texture, DrawMethod&& method, const CoordsBufferPtr& coordsBuffer)
{
    Texture* textureAtlas = nullptr;

    if (texture) {
        if (!method.src.isValid() && (!coordsBuffer || coordsBuffer->size() == 0)) {
            resetOnlyOnceParameters();
            return; // invalid draw: texture has no source rect and no vertex coordinates
        }

        if (m_atlas) {
            if (const auto region = texture->getAtlasRegion(m_atlas->getType())) {
                if (region->isEnabled()) {
                    textureAtlas = region->atlas;

                    if (method.src.isValid())
                        method.src.translate(region->x, region->y);
                }
            }
        }
    }

    if (!updateHash(method, textureAtlas ? textureAtlas : texture.get(), color, coordsBuffer != nullptr)) {
        resetOnlyOnceParameters();
        return;
    }

    auto& list = m_objects[m_currentDrawOrder];
    auto& state = getCurrentState();

    if (!list.empty() && list.back().coords && list.back().state == state) {
        auto& last = list.back();
        coordsBuffer ? last.coords->append(coordsBuffer.get()) : addCoords(*last.coords, method);
    } else if (m_alwaysGroupDrawings) {
        auto& coords = m_coords.try_emplace(state.hash, nullptr).first->second;
        if (!coords) {
            coords = list.emplace_back(getState(texture, textureAtlas, color), getCoordsBuffer()).coords.get();
        }
        coordsBuffer ? coords->append(coordsBuffer.get()) : addCoords(*coords, method);
    } else {
        auto& draw = list.emplace_back(getState(texture, textureAtlas, color), getCoordsBuffer());
        coordsBuffer ? draw.coords->append(coordsBuffer.get()) : addCoords(*draw.coords, method);
    }

    resetOnlyOnceParameters();
}

void DrawPool::addCoords(CoordsBuffer& buffer, const DrawMethod& method)
{
    if (method.type == DrawMethodType::BOUNDING_RECT) {
        buffer.addBoudingRect(method.dest, method.intValue);
    } else if (method.type == DrawMethodType::RECT) {
        buffer.addRect(method.dest, method.src);
    } else if (method.type == DrawMethodType::TRIANGLE) {
        buffer.addTriangle(method.a, method.b, method.c);
    } else if (method.type == DrawMethodType::UPSIDEDOWN_RECT) {
        buffer.addUpsideDownRect(method.dest, method.src);
    } else if (method.type == DrawMethodType::REPEATED_RECT) {
        buffer.addRepeatedRects(method.dest, method.src);
    }
}

bool DrawPool::updateHash(const DrawMethod& method, const Texture* texture, const Color& color, const bool hasCoord) {
    auto& state = getCurrentState();
    state.hash = 0;

    { // State Hash
        if (m_bindedFramebuffers > -1)
            stdext::hash_combine(state.hash, m_lastFramebufferId);

        if (state.blendEquation != BlendEquation::ADD)
            stdext::hash_combine(state.hash, state.blendEquation);

        if (state.compositionMode != CompositionMode::NORMAL)
            stdext::hash_combine(state.hash, state.compositionMode);

        if (state.opacity < 1.f)
            stdext::hash_combine(state.hash, state.opacity);

        if (state.clipRect.isValid())
            stdext::hash_union(state.hash, state.clipRect.hash());

        if (state.shaderProgram)
            stdext::hash_union(state.hash, state.shaderProgram->hash());

        if (state.transformMatrix != DEFAULT_MATRIX3)
            stdext::hash_union(state.hash, state.transformMatrix.hash());

        if (color != Color::white)
            stdext::hash_union(state.hash, color.hash());

        if (texture)
            stdext::hash_union(state.hash, texture->hash());
    }

    if (hasFrameBuffer()) { // Pool Hash
        size_t hash = state.hash;

        if (method.type == DrawMethodType::TRIANGLE) {
            if (!method.a.isNull()) stdext::hash_union(hash, method.a.hash());
            if (!method.b.isNull()) stdext::hash_union(hash, method.b.hash());
            if (!method.c.isNull()) stdext::hash_union(hash, method.c.hash());
        } else if (method.type == DrawMethodType::BOUNDING_RECT) {
            if (method.intValue) stdext::hash_combine(hash, method.intValue);
        } else {
            if (method.dest.isValid()) stdext::hash_union(hash, method.dest.hash());
            if (method.src.isValid()) stdext::hash_union(hash, method.src.hash());
        }

        // check to skip the next drawing that is the same as the previous one.
        if (!hasCoord && m_hashCtrl.isLast(hash))
            return false;

        m_hashCtrl.put(hash);
    }

    return true;
}

DrawPool::PoolState DrawPool::getState(const TexturePtr& texture, Texture* textureAtlas, const Color& color)
{
    PoolState copy = getCurrentState();

    if (copy.color != color)
        copy.color = color;

    if (textureAtlas) {
        // Texture is batched inside an atlas
        copy.textureId = textureAtlas->getId();
        copy.textureMatrixId = textureAtlas->getTransformMatrixId();
    } else if (texture) {
        if (texture->isEmpty() || // Texture not initialized in the current OpenGL context
            !texture->canCacheInAtlas() || // Texture is marked as non-atlas-cacheable (short-lived/temporary, e.g. minimap)
            (m_atlas && m_atlas->canAdd(texture)) // Force this texture to be packed into the current pool atlas,
                                                  // even if it might already belong to another DrawPool's atlas
        ) {
            copy.texture = texture;
        } else {
            // Standalone GL texture cached in memory (non-atlased)
            copy.textureId = texture->getId();
            copy.textureMatrixId = texture->getTransformMatrixId();
        }
    }

    return copy;
}
void DrawPool::setCompositionMode(const CompositionMode mode, const bool onlyOnce)
{
    if (onlyOnce && !(m_onlyOnceStateFlag & STATE_COMPOSITE_MODE)) {
        m_previousCompositionMode = getCurrentState().compositionMode;
        m_onlyOnceStateFlag |= STATE_COMPOSITE_MODE;
    }
    getCurrentState().compositionMode = mode;
}

void DrawPool::setBlendEquation(const BlendEquation equation, const bool onlyOnce)
{
    if (onlyOnce && !(m_onlyOnceStateFlag & STATE_BLEND_EQUATION)) {
        m_previousBlendEquation = getCurrentState().blendEquation;
        m_onlyOnceStateFlag |= STATE_BLEND_EQUATION;
    }
    getCurrentState().blendEquation = equation;
}

void DrawPool::setClipRect(const Rect& clipRect, const bool onlyOnce)
{
    if (onlyOnce && !(m_onlyOnceStateFlag & STATE_CLIP_RECT)) {
        m_previousClipRect = getCurrentState().clipRect;
        m_onlyOnceStateFlag |= STATE_CLIP_RECT;
    }
    getCurrentState().clipRect = clipRect;
}

void DrawPool::setOpacity(const float opacity, const bool onlyOnce)
{
    if (onlyOnce && !(m_onlyOnceStateFlag & STATE_OPACITY)) {
        m_previousOpacity = getCurrentState().opacity;
        m_onlyOnceStateFlag |= STATE_OPACITY;
    }
    getCurrentState().opacity = opacity;
}

void DrawPool::setShaderProgram(const PainterShaderProgramPtr& shaderProgram, const bool onlyOnce, const std::function<void()>& action)
{
    if (g_painter->isReplaceColorShader(getCurrentState().shaderProgram))
        return;

    if (onlyOnce && !(m_onlyOnceStateFlag & STATE_SHADER_PROGRAM)) {
        m_previousShaderProgram = getCurrentState().shaderProgram;
        m_previousShaderAction = getCurrentState().action;
        m_onlyOnceStateFlag |= STATE_SHADER_PROGRAM;
    }

    if (shaderProgram) {
        if (!g_painter->isReplaceColorShader(shaderProgram.get()))
            m_shaderRefreshDelay = FPS20;

        getCurrentState().shaderProgram = shaderProgram.get();
        getCurrentState().action = action;
    } else {
        getCurrentState().shaderProgram = nullptr;
        getCurrentState().action = nullptr;
    }
}

void DrawPool::resetState()
{
    m_coords.clear();
    m_parameters.clear();

    m_hashCtrl.reset();

    getCurrentState() = {};
    m_lastFramebufferId = 0;
    m_shaderRefreshDelay = 0;
    m_scale = DEFAULT_DISPLAY_DENSITY;
}

bool DrawPool::canRepaint()
{
    if (!m_enabled || shouldRepaint())
        return false;

    return canRefresh();
}

void DrawPool::release() {
    if (hasFrameBuffer() && !m_hashCtrl.wasModified() && !canRefresh()) {
        for (auto& objs : m_objects)
            objs.clear();
        m_objectsFlushed.clear();
        return;
    }

    m_refreshTimer.restart();

    SpinLock::Guard guard(m_threadLock);

    m_objectsDraw[0].clear();

    if (!m_objectsFlushed.empty()) {
        if (m_objectsDraw[0].size() < m_objectsFlushed.size())
            m_objectsDraw[0].swap(m_objectsFlushed);

        if (!m_objectsFlushed.empty()) {
            m_objectsDraw[0].insert(
                m_objectsDraw[0].end(),
                std::make_move_iterator(m_objectsFlushed.begin()),
                std::make_move_iterator(m_objectsFlushed.end()));
        }
        m_objectsFlushed.clear();
    }

    for (auto& objs : m_objects) {
        if (m_objectsDraw[0].size() < objs.size())
            m_objectsDraw[0].swap(objs);

        bool addFirst = true;

        if (!m_objectsDraw[0].empty() && !objs.empty()) {
            auto& last = m_objectsDraw[0].back();
            auto& first = objs.front();

            if (last.state == first.state && last.coords && first.coords) {
                last.coords->append(first.coords.get());
                addFirst = false;
            }
        }

        if (!objs.empty()) {
            m_objectsDraw[0].insert(
                m_objectsDraw[0].end(),
                std::make_move_iterator(objs.begin() + (addFirst ? 0 : 1)),
                std::make_move_iterator(objs.end()));
            objs.clear();
        }
    }

    m_shouldRepaint.store(true, std::memory_order_relaxed);
}

void DrawPool::flush()
{
    m_coords.clear();

    for (auto& objs : m_objects) {
        bool addFirst = true;
        if (!objs.empty() && !m_objectsFlushed.empty()) {
            auto& last = m_objectsFlushed.back();
            auto& first = objs.front();

            if (last.state == first.state && last.coords && first.coords) {
                last.coords->append(first.coords.get());
                addFirst = false;
            }
        }

        m_objectsFlushed.insert(
            m_objectsFlushed.end(),
            std::make_move_iterator(objs.begin() + (addFirst ? 0 : 1)),
            std::make_move_iterator(objs.end())
        );
        objs.clear();
    }
}

void DrawPool::scale(const float factor)
{
    if (m_scale == factor)
        return;

    m_scale = factor;
    getCurrentState().transformMatrix = DEFAULT_MATRIX3 * Matrix3{
      factor,   0.0f,  0.0f,
        0.0f, factor,  0.0f,
        0.0f,   0.0f,  1.0f
    }.transposed();
}

void DrawPool::translate(const float x, const float y)
{
    const Matrix3 translateMatrix = {
            1.0f,  0.0f,     x,
            0.0f,  1.0f,     y,
            0.0f,  0.0f,  1.0f
    };

    getCurrentState().transformMatrix = getCurrentState().transformMatrix * translateMatrix.transposed();
}

void DrawPool::rotate(const float angle)
{
    const Matrix3 rotationMatrix = {
            std::cos(angle), -std::sin(angle),  0.0f,
            std::sin(angle),  std::cos(angle),  0.0f,
                       0.0f,             0.0f,  1.0f
    };

    getCurrentState().transformMatrix = getCurrentState().transformMatrix * rotationMatrix.transposed();
}

void DrawPool::rotate(const float x, const float y, const float angle)
{
    translate(-x, -y);
    rotate(angle);
    translate(x, y);
}

void DrawPool::pushTransformMatrix()
{
    m_transformMatrixStack.emplace_back(getCurrentState().transformMatrix);
    assert(m_transformMatrixStack.size() < 100);
}

void DrawPool::popTransformMatrix()
{
    assert(!m_transformMatrixStack.empty());
    getCurrentState().transformMatrix = m_transformMatrixStack.back();
    m_transformMatrixStack.pop_back();
}

void DrawPool::PoolState::execute(DrawPool* pool) const {
    g_painter->setColor(color);
    g_painter->setOpacity(opacity);
    g_painter->setCompositionMode(compositionMode);
    g_painter->setBlendEquation(blendEquation);
    g_painter->setClipRect(clipRect);
    g_painter->setShaderProgram(shaderProgram);
    g_painter->setTransformMatrix(transformMatrix);
    if (action) action();
    if (texture) {
        texture->create();
        g_painter->setTexture(texture);
        if (texture->canCacheInAtlas() && pool->m_atlas && !texture->getAtlasRegion(pool->m_atlas->getType())) {
            pool->m_atlas->addTexture(texture);
        }
    } else
        g_painter->setTexture(textureId, textureMatrixId);
}

void DrawPool::setFramebuffer(const Size& size) {
    if (!m_framebuffer) {
        m_framebuffer = std::make_shared<FrameBuffer>();
        m_framebuffer->m_isScene = true;
    }

    if (size.isValid() && m_framebuffer->resize(size)) {
        m_framebuffer->prepare({}, {});
        repaint();
    }
}

void DrawPool::removeFramebuffer() {
    m_hashCtrl.reset();
    m_framebuffer = nullptr;
}

void DrawPool::addAction(const std::function<void()>& action, size_t hash)
{
    const uint8_t order = m_type == DrawPoolType::MAP ? THIRD : FIRST;
    m_objects[order].emplace_back(action);
    if (hasFrameBuffer() && hash > 0 && !m_hashCtrl.isLast(hash)) {
        m_hashCtrl.put(hash);
    }
}

void DrawPool::bindFrameBuffer(const Size& size, const Color& color)
{
    ++m_bindedFramebuffers;
    ++m_lastFramebufferId;

    if (color != Color::white)
        getCurrentState().color = color;

    nextStateAndReset();

    addAction([this, size, frameIndex = m_bindedFramebuffers] {
        static const PoolState state;

        state.execute(this);

        const auto& frame = getTemporaryFrameBuffer(frameIndex);
        frame->resize(size);
        frame->bind();
    });
}
void DrawPool::releaseFrameBuffer(const Rect& dest)
{
    releaseFrameBuffer(dest, 0);
}

void DrawPool::releaseFrameBuffer(const Rect& dest, uint8_t flipDirection)
{
    backState();

    addAction([this, dest, flipDirection, frameIndex = m_bindedFramebuffers, drawState = getCurrentState()] {
        const auto& frame = getTemporaryFrameBuffer(frameIndex);
        frame->release();
        drawState.execute(this);
        frame->draw(dest, flipDirection);
    });

    if (hasFrameBuffer() && !dest.isNull()) m_hashCtrl.put(dest.hash());
    --m_bindedFramebuffers;
}

const FrameBufferPtr& DrawPool::getTemporaryFrameBuffer(const uint8_t index) {
    if (index < m_temporaryFramebuffers.size()) {
        return m_temporaryFramebuffers[index];
    }

    const auto& tempfb = m_temporaryFramebuffers.emplace_back(std::make_shared<FrameBuffer>());
    tempfb->setSmooth(false);
    return tempfb;
}

std::shared_ptr<CoordsBuffer> DrawPool::getCoordsBuffer() {
    CoordsBuffer* coordsBuffer = nullptr;

    if (!m_coordsCache.empty()) {
        coordsBuffer = m_coordsCache.back();
        m_coordsCache.pop_back();
    } else
        coordsBuffer = new CoordsBuffer();

    return std::shared_ptr<CoordsBuffer>(coordsBuffer, [this](CoordsBuffer* ptr) {
        if (m_enabled) {
            ptr->clear();
            m_coordsCache.emplace_back(ptr);
        } else {
            delete ptr;
        }
    });
}