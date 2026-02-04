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

#include "otmldocument.h"
#include "otmlparser.h"

#include "framework/core/logger.h"

#include <optional>
#include <unordered_map>
#include <unordered_set>

namespace {
    using AliasMap = std::unordered_map<std::string, std::string>;

    struct AliasResolveResult {
        bool aliasReferenced{ false };
        std::optional<std::string> resolvedValue;
    };

    std::string stripQuotes(std::string value)
    {
        if (value.size() >= 2) {
            const char first = value.front();
            const char last = value.back();
            if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
                value = value.substr(1, value.size() - 2);
            }
        }
        return value;
    }

    std::string normalizeValue(std::string value)
    {
        stdext::trim(value);
        return stripQuotes(value);
    }

    bool isAliasTag(const std::string_view tag)
    {
        return !tag.empty() && tag.front() == '&';
    }

    std::string normalizeAliasName(std::string alias)
    {
        if (!alias.empty() && alias.front() == '&') {
            alias.erase(alias.begin());
        }
        stdext::trim(alias);
        return alias;
    }

    std::optional<std::string> resolveAliasName(const std::string& name, const AliasMap& aliases, std::unordered_set<std::string>& visited)
    {
        if (name.empty()) {
            g_logger.error("Undefined OTML variable: {}", name);
            return std::nullopt;
        }
        if (!visited.insert(name).second) {
            g_logger.error("Circular OTML variable reference: {}", name);
            return std::nullopt;
        }

        const auto it = aliases.find(name);
        if (it == aliases.end()) {
            g_logger.error("Undefined OTML variable: {}", name);
            visited.erase(name);
            return std::nullopt;
        }

        std::string value = normalizeValue(it->second);
        if (!value.empty() && value.front() == '$') {
            std::string nestedName = value.substr(1);
            if (!nestedName.empty() && nestedName.front() == '&') {
                nestedName.erase(nestedName.begin());
            }
            stdext::trim(nestedName);
            const auto nested = resolveAliasName(nestedName, aliases, visited);
            visited.erase(name);
            return nested;
        }

        visited.erase(name);
        return value;
    }

    AliasResolveResult resolveAliasValue(const std::string& value, const AliasMap& aliases)
    {
        auto trimmedValue = value;
        stdext::trim(trimmedValue);
        if (trimmedValue.empty() || trimmedValue.front() != '$') {
            return { false, std::nullopt };
        }

        std::string aliasName = trimmedValue.substr(1);
        if (!aliasName.empty() && aliasName.front() == '&') {
            aliasName.erase(aliasName.begin());
        }
        stdext::trim(aliasName);

        if (aliasName.empty()) {
            return { false, std::nullopt };
        }

        if (aliases.empty()) {
            return { false, std::nullopt };
        }

        if (aliases.find(aliasName) == aliases.end()) {
            g_logger.error("Undefined OTML variable: {}", aliasName);
            return { true, std::nullopt };
        }

        std::unordered_set<std::string> visited;
        return { true, resolveAliasName(aliasName, aliases, visited) };
    }

    void resolveVariablesRecursive(const OTMLNodePtr& node, const AliasMap& parentAliases, OTMLDocument* doc)
    {
        AliasMap aliases = parentAliases;

        std::vector<OTMLNodePtr> aliasNodes;
        aliasNodes.reserve(node->children().size());

        for (const auto& child : node->children()) {
            if (isAliasTag(child->tag())) {
                aliasNodes.emplace_back(child);
            }
        }

        // 1) primeiro processa todos os &aliases deste nível
        for (const auto& aliasNode : aliasNodes) {
            const auto aliasName = normalizeAliasName(aliasNode->tag());
            if (aliasName.empty()) {
                g_logger.error("Malformed OTML variable: {}", aliasNode->tag());
                aliasNode->setUnique(true);
                continue;
            }

            const std::string aliasValueLiteral = aliasNode->rawValue();
            std::string aliasValue = normalizeValue(aliasValueLiteral);

            const auto result = resolveAliasValue(aliasValue, aliases);
            if (result.aliasReferenced) {
                if (!result.resolvedValue) {
                    // referenciou $var mas não resolveu -> mantém para erro posterior
                    aliasNode->setUnique(true);
                    continue;
                }
                aliasValue = *result.resolvedValue;
            }

            aliasNode->setUnique(true);

            // registra no mapa local (válido para filhos)
            aliases[aliasName] = aliasValue;

            // 2) se estiver na raiz (doc != nullptr), registra como global
            if (doc) {
                if (doc->globalAliases().contains(aliasName)) {
                    g_logger.warning("Overriding global OTML variable: {}", aliasName);
                }
                doc->addGlobalAlias(aliasName, aliasValue);
            }
        }

        // 3) agora resolve valores dos filhos e desce recursivo
        const auto children = node->children();
        for (const auto& child : children) {
            if (!isAliasTag(child->tag())) {
                const auto result = resolveAliasValue(child->rawValue(), aliases);
                if (result.aliasReferenced) {
                    if (result.resolvedValue) {
                        child->setValue(normalizeValue(*result.resolvedValue));
                    } else {
                        // referenciou e falhou: mantém como está (ou zera), você decide
                    }
                }
            }

            // doc só na raiz
            resolveVariablesRecursive(child, aliases, nullptr);
        }
    }
} // namespace

OTMLParser::OTMLParser(const OTMLDocumentPtr& doc, std::istream& in) :
    currentDepth(0), currentLine(0),
    doc(doc), currentParent(doc), previousNode(nullptr),
    in(in)
{
}

void OTMLParser::parse()
{
    if (!in.good())
        throw OTMLException(doc, "cannot read from input stream");

    while (!in.eof())
        parseLine(getNextLine());

    resolveVariablesRecursive(doc->asOTMLNode(), {}, doc.get());
}

std::string OTMLParser::getNextLine()
{
    ++currentLine;
    std::string line;
    std::getline(in, line);
    return line;
}

int OTMLParser::getLineDepth(const std::string_view line, const bool multilining) const
{
    auto _line = std::string{ line };
    stdext::trim(_line); // fix for lines without content.
    if (_line.empty())
        return 0;

    // count number of spaces at the line beginning
    std::size_t spaces = 0;
    while (line[spaces] == ' ') {
        if (++spaces == line.length()) {
            --spaces; break;
        }
    }

    // pre calculate depth
    const int depth = spaces / 2;

    if (!multilining || depth <= currentDepth) {
        // check the next character is a tab
        if (line[spaces] == '\t')
            throw OTMLException(doc, "indentation with tabs are not allowed", currentLine);

        // must indent every 2 spaces
        if (spaces % 2 != 0)
            throw OTMLException(doc, "must indent every 2 spaces", currentLine);
    }

    return depth;
}

void OTMLParser::parseLine(std::string line)
{
    const int depth = getLineDepth(line);

    if (depth == -1)
        return;

    // remove line sides spaces
    stdext::trim(line);

    // skip empty lines
    if (line.empty())
        return;

    // skip comments
    if (line.starts_with("//") || line.starts_with("#"))
        return;

    // a depth above, change current parent to the previous added node
    if (depth == currentDepth + 1) {
        currentParent = previousNode;
        // a depth below, change parent to previous parent
    } else if (depth < currentDepth) {
        for (int i = 0; i < currentDepth - depth; ++i)
            currentParent = parentMap[currentParent];
        // if it isn't the current depth, it's a syntax error
    } else if (depth != currentDepth)
        throw OTMLException(doc, "invalid indentation depth, are you indenting correctly?", currentLine);

    // sets current depth
    currentDepth = depth;

    // alright, new depth is set, the line is not empty and it isn't a comment
    // then it must be a node, so we parse it
    parseNode(line);
}

void OTMLParser::parseNode(const std::string_view data)
{
    std::string tag;
    std::string value;
    std::size_t dotsPos = std::string::npos;
    const int nodeLine = currentLine;

    // Perform right-trim to avoid issues with spaces/tabs
    std::string line = std::string(data);
    while (!line.empty() && (line.back() == ' ' || line.back() == '\t' || line.back() == '\r'))
        line.pop_back();

    const bool isUrlWithColon = (line.starts_with("http://") || line.starts_with("https://")) && line.back() == ':';
    const bool isUrlKey = line.starts_with("http://") || line.starts_with("https://");

    if (isUrlWithColon) {
        // URL ending in ':' → treat as a key without ':' and no value on the same line
        tag = line.substr(0, line.size() - 1);
        // Value remains empty
    } else {
        // Normal processing (list item, key-value, or just key)
        if (isUrlKey) {
            // For URLs, prefer a separator colon followed by whitespace (avoids port/path colons)
            const size_t schemeEnd = line.find("://");
            const size_t searchFrom = (schemeEnd != std::string::npos) ? schemeEnd + 3 : 0;
            const size_t sepPosSpace = line.find(": ", searchFrom);
            const size_t sepPosTab = line.find(":\t", searchFrom);
            if (sepPosSpace != std::string::npos)
                dotsPos = sepPosSpace;
            else if (sepPosTab != std::string::npos)
                dotsPos = sepPosTab;
            else
                dotsPos = std::string::npos;
        } else {
            dotsPos = line.find(':');
        }

        if (!line.empty() && line.front() == '-') {
            // "- item"
            value = line.substr(1);
            stdext::trim(value);
        } else if (dotsPos != std::string::npos) {
            // "key: value"
            tag = line.substr(0, dotsPos);
            if (dotsPos + 1 < line.size())
                value = line.substr(dotsPos + 1);
        } else {
            // "key"
            tag = line;
        }
    }

    stdext::trim(tag);
    stdext::trim(value);

    // process multitine values
    if (value == "|" || value == "|-" || value == "|+") {
        // reads next lines until we can a value below the same depth
        std::string multiLineData;
        do {
            const size_t lastPos = in.tellg();
            std::string line = getNextLine();
            const int depth = getLineDepth(line, true);

            // depth above current depth, add the text to the multiline
            if (depth > currentDepth) {
                multiLineData += line.substr((currentDepth + 1) * 2);
                // it has contents below the current depth
            } else {
                // if not empty, its a node
                stdext::trim(line);
                if (!line.empty()) {
                    // rewind and break
                    in.seekg(lastPos, std::ios::beg);
                    --currentLine;
                    break;
                }
            }
            multiLineData += "\n";
        } while (!in.eof());

        /* determine how to treat new lines at the end
         * | strip all new lines at the end and add just a new one
         * |- strip all new lines at the end
         * |+ keep all the new lines at the end (the new lines until next node)
         */
        if (value == "|" || value == "|-") {
            // remove all new lines at the end
            int lastPos = multiLineData.length();
            while (multiLineData[--lastPos] == '\n')
                multiLineData.erase(lastPos, 1);

            if (value == "|")
                multiLineData.append("\n");
        } // else it's |+

        value = multiLineData;
    }

    // create the node
    const auto& node = OTMLNode::create(tag);

    node->setUnique(isUrlWithColon || dotsPos != std::string::npos);
    node->setTag(tag);
    node->setSource(doc->source() + ":" + stdext::unsafe_cast<std::string>(nodeLine));

    // ~ is considered the null value
    if (value == "~")
        node->setNull(true);
    else {
        if (value.starts_with("[") && value.ends_with("]")) {
            const auto& tmp = value.substr(1, value.length() - 2);
            const std::vector tokens = stdext::split(tmp, ",");
            for (std::string v : tokens) {
                stdext::trim(v);
                node->writeIn(v);
            }
        } else
            node->setValue(value);
    }

    if (currentParent) {
        currentParent->addChild(node);
        parentMap[node] = currentParent;
    } else {
        throw OTMLException(doc, fmt::format("orphaned node detected (indentation error?): '{}'", tag), currentLine);
    }
    previousNode = node;
}
