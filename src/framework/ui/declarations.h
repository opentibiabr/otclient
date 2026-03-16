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

#include <framework/global.h>

enum class DrawPoolType : uint8_t;
enum FlagProp : uint64_t;
enum class DisplayType : uint8_t;
enum class FloatType : uint8_t;
enum class ClearType : uint8_t;
enum class JustifyItemsType : uint8_t;
enum class FlexDirection : uint8_t;
enum class FlexWrap : uint8_t;
enum class JustifyContent : uint8_t;
enum class AlignItems : uint8_t;
enum class AlignContent : uint8_t;
enum class AlignSelf : uint8_t;
enum class Unit : uint8_t;
enum class OverflowType : uint8_t;

class UIManager;
class UIWidget;
class UITextEdit;
class UILayout;
class UIBoxLayout;
class UIHorizontalLayout;
class UIVerticalLayout;
class UIGridLayout;
class UIAnchor;
class UIAnchorGroup;
class UIAnchorLayout;
class UIParticles;

using UIWidgetPtr = std::shared_ptr<UIWidget>;
using UIParticlesPtr = std::shared_ptr<UIParticles>;
using UITextEditPtr = std::shared_ptr<UITextEdit>;
using UILayoutPtr = std::shared_ptr<UILayout>;
using UIBoxLayoutPtr = std::shared_ptr<UIBoxLayout>;
using UIHorizontalLayoutPtr = std::shared_ptr<UIHorizontalLayout>;
using UIVerticalLayoutPtr = std::shared_ptr<UIVerticalLayout>;
using UIGridLayoutPtr = std::shared_ptr<UIGridLayout>;
using UIAnchorPtr = std::shared_ptr<UIAnchor>;
using UIAnchorGroupPtr = std::shared_ptr<UIAnchorGroup>;
using UIAnchorLayoutPtr = std::shared_ptr<UIAnchorLayout>;

using UIWidgetList = std::deque<UIWidgetPtr>;
using UIAnchorList = std::vector<UIAnchorPtr>;
