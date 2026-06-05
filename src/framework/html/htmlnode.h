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
#include "declarations.h"
#include <framework/ui/declarations.h>

inline void ascii_tolower_inplace(std::string& s) { for (auto& c : s) if (c >= 'A' && c <= 'Z') c = char(c - 'A' + 'a'); }
inline std::string ascii_tolower_copy(std::string s) { ascii_tolower_inplace(s); return s; }

enum class NodeType { Element, Text, Comment, Doctype };

struct StyleValue
{
    std::string value;
    std::string inheritedFromId;
    bool important{ false };
};

class HtmlNode : public std::enable_shared_from_this<HtmlNode>
{
public:
    NodeType getType() const { return type; }
    const auto& getTag() const { return tag; }
    const auto& getAttributesMap() const { return attributes; }
    const auto& getClassList() const { return classList; }
    const auto& getChildren() const { return children; }
    const auto& getRawText() const { return text; }
    const auto getParent() const { return parent.lock(); }

    HtmlNodePtr getById(const std::string& id) const {
        auto root = documentRoot();
        auto it = root->idIndex.find(id);
        if (it == root->idIndex.end()) return nullptr;
        return it->second.lock();
    }
    std::vector<HtmlNodePtr> getByClass(const std::string& cls) const {
        std::vector<HtmlNodePtr> out;
        auto root = documentRoot();
        auto it = root->classIndex.find(cls);
        if (it == root->classIndex.end()) return out;
        out.reserve(it->second.size());
        for (auto& w : it->second) { if (auto sp = w.lock()) out.push_back(sp); }
        return out;
    }
    std::vector<HtmlNodePtr> getByTag(const std::string& t) const {
        std::vector<HtmlNodePtr> out;
        auto root = documentRoot();
        auto key = ascii_tolower_copy(t);
        auto it = root->tagIndex.find(key);
        if (it == root->tagIndex.end()) return out;
        out.reserve(it->second.size());
        for (auto& w : it->second) { if (auto sp = w.lock()) out.push_back(sp); }
        return out;
    }
    std::string getAttr(const std::string& name) const;
    bool removeAttr(const std::string& name);

    void setAttr(const std::string& name, const std::string& value);
    std::string textContent() const;
    std::string getText() const { return text; }

    bool hasAttr(const std::string& name) const;

    size_t indexInParent() const;
    bool isOnlyChild() const;
    bool isLastChild() const;
    bool isEmpty() const;

    int indexAmongElements() const;
    int indexAmongType() const;

    std::string innerHTML() const;
    std::string outerHTML() const;
    void setInnerHTML(const std::string& html);
    void setOuterHTML(const std::string& html);

    HtmlNodePtr documentRoot() const;

    std::vector<HtmlNodePtr> querySelectorAll(const std::string& selector);
    HtmlNodePtr querySelector(const std::string& selector);

    friend HtmlNodePtr parseHtml(const std::string& html);
    friend void invalidateIndexCachesUp(HtmlNode* n);

    const UIWidgetPtr& getWidget() const { return m_widget; }
    void setWidget(const UIWidgetPtr& widget) { m_widget = widget; }

    HtmlNodePtr getPrev() const { return prev.lock(); }
    HtmlNodePtr getNext() const { return next.lock(); }

    auto& getStyles() { return m_styles; }

    std::string getStyle(std::string_view style) const;
    auto& getAttrStyles() { return m_attrStyles; }

    auto& getInheritableStyles() {
        return m_inheritableStyles;
    }

    void append(const HtmlNodePtr& child);
    void prepend(const HtmlNodePtr& child);
    void insert(const HtmlNodePtr& child, size_t pos);
    void destroy();
    void remove(const HtmlNodePtr& child);
    void clear();
    void setParent(const HtmlNodePtr& node) { parent = node; }

    bool isHovered{ false };
    bool isFocused{ false };
    bool isActive{ false };

    bool isExpression() const { return m_isExpression; }
    void setExpression(bool v) { m_isExpression = v; }

    bool isStyleResolved() const { return m_styleResolved; }
    void setStyleResolved(bool v) { m_styleResolved = v; }

    std::string toString(bool recursive = true) const;
    HtmlNodePtr clone(bool deep = true) const;

private:
    NodeType type{ NodeType::Element };
    std::string tag;
    std::unordered_map<std::string, std::string> attributes;
    std::vector<std::string> classList;
    std::vector<HtmlNodePtr> children;
    std::string text;
    std::weak_ptr<HtmlNode> parent;
    std::weak_ptr<HtmlNode> prev;
    std::weak_ptr<HtmlNode> next;

    std::unordered_map<std::string, std::weak_ptr<HtmlNode>> idIndex;
    std::unordered_map<std::string, std::vector<std::weak_ptr<HtmlNode>>> classIndex;
    std::unordered_map<std::string, std::vector<std::weak_ptr<HtmlNode>>> tagIndex;

    std::unordered_map< std::string, std::map<std::string, StyleValue>> m_styles; // value, inheritable
    std::unordered_map<std::string, std::map<std::string, std::string>> m_inheritableStyles;

    std::map<std::string, std::string> m_attrStyles;
    UIWidgetPtr m_widget;

    mutable int cacheIndexAmongElements = -1;
    mutable int cacheIndexAmongType = -1;

    bool m_isExpression{ false };
    bool m_styleResolved{ false };

private:
    static void rebuildIndexes(const HtmlNodePtr& root);
    void attachChild(const HtmlNodePtr& child, size_t pos);
    void registerInIndexes(const HtmlNodePtr& child);
    void registerSubtreeInIndexes(const HtmlNodePtr& node);
    void unregisterSubtreeFromIndexes(const HtmlNodePtr& node);
    void detachFromCurrentParent(const HtmlNodePtr& child);
};

inline void invalidateIndexCachesUp(HtmlNode* n) {
    while (n) {
        n->cacheIndexAmongElements = -1;
        n->cacheIndexAmongType = -1;
        auto p = n->parent.lock();
        n = p ? p.get() : nullptr;
    }
}
