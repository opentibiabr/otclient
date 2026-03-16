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

#include "uiqrcode.h"

#include <framework/graphics/image.h>

#include "framework/graphics/texture.h"
#include "framework/otml/otmlnode.h"

void UIQrCode::parseCustomStyle(const OTMLNodePtr& styleNode)
{
    UIWidget::parseCustomStyle(styleNode);

    for (const auto& node : styleNode->children()) {
        if (node->tag() == "code")
            setCode(node->value(), getCodeBorder());
        else if (node->tag() == "code-border")
            setCodeBorder(node->value<int>());
    }
}

void UIQrCode::setCode(const std::string& code, const int border)
{
    if (code.empty()) {
        m_imageTexture = nullptr;
        m_qrCode = {};
        return;
    }

    m_qrCode = code;
    m_imageTexture = std::make_shared<Texture>(Image::fromQRCode(code, border));

    if (m_imageTexture && (!m_rect.isValid() || isImageAutoResize())) {
        const auto& imageSize = m_imageTexture->getSize();

        Size size = getSize();
        if (size.width() <= 0 || hasProp(PropImageAutoResize))
            size.setWidth(imageSize.width());

        if (size.height() <= 0 || hasProp(PropImageAutoResize))
            size.setHeight(imageSize.height());

        setSize(size);
    }
}