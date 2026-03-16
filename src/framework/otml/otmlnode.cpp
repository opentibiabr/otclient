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

#include "otmlnode.h"

#include "otmlemitter.h"

OTMLNodePtr OTMLNode::create(const std::string_view tag, const bool unique)
{
    const auto& node = std::make_shared<OTMLNode>();
    node->setTag(tag);
    node->setUnique(unique);
    return node;
}

OTMLNodePtr OTMLNode::create(const std::string_view tag, const std::string_view value)
{
    const auto& node = std::make_shared<OTMLNode>();
    node->setTag(tag);
    node->setValue(value);
    node->setUnique(true);
    return node;
}

bool OTMLNode::hasChildren() const
{
    int count = 0;
    for (const auto& child : m_children) {
        if (!child->isNull())
            ++count;
    }
    return count > 0;
}

OTMLNodePtr OTMLNode::get(const std::string_view childTag) const
{
    for (const auto& child : m_children) {
        if (child->tag() == childTag && !child->isNull())
            return child;
    }
    return nullptr;
}

OTMLNodePtr OTMLNode::getIndex(const int childIndex)
{
    return childIndex < size() && childIndex >= 0 ? m_children[childIndex] : nullptr;
}

OTMLNodePtr OTMLNode::at(const std::string_view childTag)
{
    for (const auto& child : m_children) {
        if (child->tag() == childTag && !child->isNull()) {
            return child;
        }
    }

    throw OTMLException(asOTMLNode(), fmt::format("child node with tag '{}' not found", childTag));
}

OTMLNodePtr OTMLNode::atIndex(const int childIndex)
{
    if (childIndex >= size() || childIndex < 0)
        throw OTMLException(asOTMLNode(), fmt::format("child node with index '{}' not found", childIndex));
    return m_children[childIndex];
}

void OTMLNode::addChild(const OTMLNodePtr& newChild)
{
    // replace is needed when the tag is marked as unique
    if (newChild->hasTag()) {
        for (const auto& node : m_children) {
            if (node->tag() == newChild->tag() && (node->isUnique() || newChild->isUnique())) {
                newChild->setUnique(true);

                if (node->hasChildren() && newChild->hasChildren()) {
                    const OTMLNodePtr tmpNode = node->clone();
                    tmpNode->merge(newChild);
                    newChild->copy(tmpNode);
                }

                replaceChild(node, newChild);

                // remove any other child with the same tag
                auto it = m_children.begin();
                while (it != m_children.end()) {
                    const OTMLNodePtr nodeChild = (*it);
                    if (nodeChild != newChild && nodeChild->tag() == newChild->tag()) {
                        it = m_children.erase(it);
                    } else
                        ++it;
                }
                return;
            }
        }
    }

    m_children.emplace_back(newChild);
}

bool OTMLNode::removeChild(const OTMLNodePtr& oldChild)
{
    const auto it = std::ranges::find(m_children, oldChild);
    if (it == m_children.end())
        return false;

    m_children.erase(it);
    return true;
}

bool OTMLNode::replaceChild(const OTMLNodePtr& oldChild, const OTMLNodePtr& newChild)
{
    auto it = std::ranges::find(m_children, oldChild);
    if (it != m_children.end()) {
        it = m_children.erase(it);
        m_children.insert(it, newChild);
        return true;
    }
    return false;
}

void OTMLNode::copy(const OTMLNodePtr& node)
{
    setTag(node->tag());
    setValue(node->rawValue());
    setUnique(node->isUnique());
    setNull(node->isNull());
    setSource(node->source());
    clear();
    for (const auto& child : node->m_children)
        addChild(child->clone());
}

void OTMLNode::merge(const OTMLNodePtr& node)
{
    for (const auto& child : node->m_children)
        addChild(child->clone());
    setTag(node->tag());
    setSource(node->source());
}

void OTMLNode::clear()
{
    m_children.clear();
}

OTMLNodeList OTMLNode::children() const
{
    OTMLNodeList children;
    for (const auto& child : m_children)
        if (!child->isNull())
            children.emplace_back(child);
    return children;
}

OTMLNodePtr OTMLNode::clone() const
{
    const auto& myClone = std::make_shared<OTMLNode>();
    myClone->setTag(m_tag);
    myClone->setValue(m_value);
    myClone->setUnique(m_unique);
    myClone->setNull(m_null);
    myClone->setSource(m_source);
    for (const auto& child : m_children)
        myClone->addChild(child->clone());
    return myClone;
}

std::string OTMLNode::emit()
{
    return OTMLEmitter::emitNode(asOTMLNode(), 0);
}