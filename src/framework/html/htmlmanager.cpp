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

#include "htmlmanager.h"
#include "htmlparser.h"
#include "htmlnode.h"
#include "framework/core/resourcemanager.h"
#include "framework/luaengine/luainterface.h"
#include "framework/otml/otmlnode.h"
#include "framework/ui/uimanager.h"
#include "framework/ui/uiwidget.h"

HtmlManager g_html;

namespace {
    static std::vector<css::StyleSheet> GLOBAL_STYLES;

    static const std::unordered_map<std::string, std::string> IMG_ATTR_TRANSLATED = {
        {"offset-x", "image-offset-x"},
        {"offset-y", "image-offset-y"},
        {"offset", "image-offset"},
        {"width", "image-width"},
        {"height", "image-height"},
        {"size", "image-size"},
        {"rect", "image-rect"},
        {"clip", "image-clip"},
        {"fixed-ratio", "image-fixed-ratio"},
        {"repeated", "image-repeated"},
        {"smooth", "image-smooth"},
        {"color", "image-color"},
        {"border-top", "image-border-top"},
        {"border-right", "image-border-right"},
        {"border-bottom", "image-border-bottom"},
        {"border-left", "image-border-left"},
        {"border", "image-border"},
        {"auto-resize", "image-auto-resize"},
        {"individual-animation", "image-individual-animation"},
        {"src", "image-source"},
        {"*src", "*image-source"}
    };

    static const std::unordered_set<std::string_view> kProps = {
        "color",
        "cursor",
        "direction",
        "font",
        "font-family",
        "font-scale",
        "font-size",
        "font-style",
        "font-variant",
        "font-weight",
        "letter-spacing",
        "line-height",
        "text-align",
        "text-indent",
        "text-transform",
        "unicode-bidi",
        /*"visibility",*/
        "white-space",
        "word-spacing",
        "writing-mode",
        "hyphens",
        "text-lang"
    };

    static inline bool isInheritable(std::string_view prop) noexcept {
        if (prop.starts_with("*"))
            prop.remove_prefix(1);
        return kProps.find(prop) != kProps.end();
    }

    // Cascade precedence: !important > the node's own matched rule > inherited value > universal (*) default.
    inline bool canInheritOver(const StyleValue& current) noexcept {
        return !current.important && (current.universal || !current.inheritedFromId.empty());
    }

    void setChildrenStyles(std::string_view htmlId, HtmlNode* n, const std::string& style, const std::string& prop, const std::string& value) {
        if (n->getType() == NodeType::Element)
            n->getInheritableStyles()[style][prop] = value;

        for (const auto& child : n->getChildren()) {
            auto& styleMap = child->getStyles()[style];
            auto it = styleMap.find(prop);
            if (it == styleMap.end() || canInheritOver(it->second)) {
                styleMap[prop] = { value , std::string{htmlId} };
                setChildrenStyles(htmlId, child.get(), style, prop, value);
            }
        }
    }

    void parseAttrPropList(std::string_view attrsStr, std::map<std::string, std::string>& attrsMap) {
        for (auto& data : stdext::split(attrsStr, ";")) {
            stdext::trim(data);
            auto attr = stdext::split(data, ":");
            if (attr.size() > 1) {
                stdext::trim(attr[0]);
                stdext::trim(attr[1]);
                attrsMap[attr[0]] = attr[1];
            }
        }
    }

    std::string toCssLength(std::string value) {
        stdext::trim(value);
        if (!value.empty() && std::ranges::all_of(value, [](const unsigned char c) { return std::isdigit(c); }))
            value += "px";
        return value;
    }

    HtmlNode* findAncestorTable(HtmlNode* node) {
        for (auto parent = node->getParent(); parent; parent = parent->getParent()) {
            if (parent->getTag() == "table")
                return parent.get();
        }
        return nullptr;
    }

    bool isHeadingTag(std::string_view tag) {
        return tag.size() == 2 && tag[0] == 'h' && tag[1] >= '1' && tag[1] <= '6';
    }

    // Legacy presentational attributes (align, valign, width, cellpadding...) are mapped to
    // styles with the lowest author precedence: CSS rules and inline styles always win.
    // Returns the attributes consumed, which must not be forwarded to Lua setters.
    std::unordered_set<std::string> applyPresentationalHints(UIWidget* widget, HtmlNode* node) {
        std::unordered_set<std::string> consumed;
        if (node->getType() != NodeType::Element)
            return consumed;

        const auto& tag = node->getTag();
        const bool isTable = tag == "table";
        const bool isCell = tag == "td" || tag == "th";
        const bool isRow = tag == "tr";
        const bool isImg = tag == "img";
        const bool isBlockText = tag == "p" || tag == "div" || isHeadingTag(tag);
        if (!isTable && !isCell && !isRow && !isImg && !isBlockText)
            return consumed;

        std::vector<std::pair<std::string, std::string>> hints;
        const auto attrValue = [&](const std::string& name) {
            auto value = node->getAttr(name);
            stdext::trim(value);
            return ascii_tolower_copy(value);
        };
        const auto consume = [&](const std::string& name) {
            if (!node->hasAttr(name))
                return std::string{};
            consumed.emplace(name);
            return attrValue(name);
        };

        if (isTable || isCell || isRow) {
            if (!isRow) {
                if (const auto width = consume("width"); !width.empty())
                    hints.emplace_back("width", toCssLength(width));
            }
            if (const auto height = consume("height"); !height.empty())
                hints.emplace_back("height", toCssLength(height));
            if (const auto bgcolor = consume("bgcolor"); !bgcolor.empty())
                hints.emplace_back("background-color", bgcolor);
        }

        if (const auto align = consume("align"); !align.empty()) {
            if (isImg || isTable) {
                if (align == "left" || align == "right")
                    hints.emplace_back("float", align);
                else if (isTable && align == "center") {
                    hints.emplace_back("margin-left", "auto");
                    hints.emplace_back("margin-right", "auto");
                } else if (isImg && (align == "middle" || align == "top" || align == "bottom"))
                    hints.emplace_back("vertical-align", align);
            } else if (align == "left" || align == "right" || align == "center" || align == "justify") {
                hints.emplace_back("text-align", align);
            }
        }

        if (isCell || isRow) {
            if (const auto valign = consume("valign"); !valign.empty())
                hints.emplace_back("vertical-align", valign);
        }

        if (isImg) {
            // Not consumed: they still reach image-width/image-height. As layout hints they reserve
            // the box before a remote image finishes downloading.
            for (const auto* dimension : { "width", "height" }) {
                const auto value = attrValue(dimension);
                if (!value.empty() && stdext::to_number(value) > 0)
                    hints.emplace_back(dimension, toCssLength(value));
            }
            if (const auto hspace = consume("hspace"); !hspace.empty()) {
                hints.emplace_back("margin-left", toCssLength(hspace));
                hints.emplace_back("margin-right", toCssLength(hspace));
            }
            if (const auto vspace = consume("vspace"); !vspace.empty()) {
                hints.emplace_back("margin-top", toCssLength(vspace));
                hints.emplace_back("margin-bottom", toCssLength(vspace));
            }
        }

        if (isTable) {
            consume("cellpadding");
            consume("cellspacing");
            if (const auto border = consume("border"); stdext::to_number(border) > 0) {
                hints.emplace_back("border-width", toCssLength(border));
                hints.emplace_back("border-color", "#808080");
            }
        }

        if (isCell) {
            if (const auto* table = findAncestorTable(node)) {
                if (const auto padding = table->getAttr("cellpadding"); !padding.empty())
                    hints.emplace_back("padding", toCssLength(padding));
                if (stdext::to_number(table->getAttr("border")) > 0) {
                    hints.emplace_back("border-width", "1px");
                    hints.emplace_back("border-color", "#808080");
                }
            }
        }

        auto& attrStyles = node->getAttrStyles();
        auto& ruleStyles = node->getStyles()["styles"];
        for (const auto& [prop, value] : hints) {
            if (attrStyles.contains(prop))
                continue;

            const auto it = ruleStyles.find(prop);
            if (it != ruleStyles.end() && !canInheritOver(it->second))
                continue;

            attrStyles[prop] = value;
            if (isInheritable(prop))
                setChildrenStyles(widget->getHtmlId(), node, "styles", prop, value);
        }

        return consumed;
    }

    void translateAttribute(std::string_view styleName, std::string_view tagName, std::string& attr, std::string& /*value*/) {
        if (attr == "*style") {
            attr = "*mergeStyle";
        } else if (attr == "*if") {
            attr = "*condition-if";
        }

        if (styleName != "CheckBox" && styleName != "ComboBox") {
            if (attr == "*value") {
                attr = "*text";
            } else if (attr == "value") {
                attr = "text";
            }
        }

        if (tagName == "img") {
            auto it = IMG_ATTR_TRANSLATED.find(attr);
            if (it != IMG_ATTR_TRANSLATED.end()) {
                attr = it->second;
            }
        }
    }

    std::string_view translateStyleName(std::string_view styleName, const HtmlNodePtr& el) {
        if (styleName == "select") {
            return "QtComboBox";
        }

        if (styleName == "hr") {
            return "HorizontalSeparator";
        }

        if (styleName == "input") {
            const auto& type = el->getAttr("type");
            if (type == "checkbox" || type == "radio") {
                return "QtCheckBox";
            }
            return "TextEdit";
        }

        if (styleName == "textarea") {
            return "MultilineTextEdit";
        }

        // Style lookup is case-insensitive, so <table> would resolve to the OTUI "Table" (UITable)
        // widget instead of the HTML table layout.
        if (styleName == "table") {
            return "UIHTML";
        }

        return styleName;
    }

    void createRadioGroup(const HtmlNode* node, std::unordered_map<std::string, UIWidgetPtr>& groups) {
        const auto& name = node->getAttr("name");
        if (name.empty())
            return;

        UIWidgetPtr group;
        auto it = groups.find(name);
        if (it == groups.end()) {
            group = groups
                .emplace(name, g_lua.callGlobalField<UIWidgetPtr>("UIRadioGroup", "create"))
                .first->second;
        } else group = it->second;

        group->callLuaField("addWidget", node->getWidget());
    }

    void applyStyleSheet(HtmlNode* mainNode, std::string_view htmlPath, const css::StyleSheet& sheet, bool checkRuleExist) {
        for (const auto& rule : sheet.rules) {
            const auto& selectors = stdext::join(rule.selectors);
            const auto& nodes = mainNode->querySelectorAll(selectors);
            const auto is_all = selectors == "*";

            if (checkRuleExist && nodes.empty()) {
                g_logger.warning("[{}][style] selector({}) no element was found.", htmlPath, selectors);
                continue;
            }

            for (const auto& node : nodes) {
                const auto widget = node->getWidget().get();
                if (widget && !node->isStyleResolved()) {
                    const auto applyDecl = [&](const std::string& style, const css::Declaration& decl) {
                        auto& styleMap = node->getStyles()[style];
                        const auto it = styleMap.find(decl.property);
                        const bool canSet = it == styleMap.end() || (is_all
                            ? (it->second.universal
                                ? !it->second.important || decl.important
                                : decl.important && !it->second.important)
                            : !it->second.important || (it->second.universal && decl.important));
                        if (!canSet)
                            return;

                        styleMap[decl.property] = { decl.value, "", decl.important, is_all };
                        if (!is_all && isInheritable(decl.property)) {
                            setChildrenStyles(widget->getHtmlId(), node.get(), style, decl.property, decl.value);
                        }
                    };

                    bool hasMeta = false;
                    for (const auto& metas : rule.selectorMeta) {
                        for (const auto& state : metas.pseudos) {
                            std::string style = "$";
                            if (state.negated)
                                style += "!";
                            style += state.name;

                            for (const auto& decl : rule.decls)
                                applyDecl(style, decl);
                            hasMeta = true;
                        }
                    }

                    if (hasMeta)
                        continue;

                    for (const auto& decl : rule.decls)
                        applyDecl("styles", decl);
                }
            }
        }
    };
}

bool checkSpecialCase(const HtmlNodePtr& node, const UIWidgetPtr& parent, const std::string& moduleName) {
    if (!parent || !parent->getHtmlNode())
        return true;

    if (!node->getAttr("*for").empty()) {
        const auto condition = node->getAttr("*for");
        const auto finished = node->getAttr("*for-finished");
        node->removeAttr("*for");
        node->removeAttr("*for-finished");
        parent->callLuaField("__childFor", moduleName, condition, node->outerHTML(), parent->getChildren().size(), finished);
        return false;
    }

    if (parent->getHtmlNode()->getTag() == "select") {
        parent->callLuaField("addOptionFromHtml", node->textContent(), node->getAttr("value"));
        return false;
    }

    return true;
}

UIWidgetPtr createWidgetFromNode(const HtmlNodePtr& node, const UIWidgetPtr& parent, std::vector<HtmlNodePtr>& textNodes, uint32_t htmlId, const std::string& moduleName, std::vector<UIWidgetPtr>& widgets) {
    if (!checkSpecialCase(node, parent, moduleName))
        return nullptr;

    if (node->getType() == NodeType::Comment || node->getType() == NodeType::Doctype)
        return nullptr;

    const auto& styleName = g_ui.getStyleName(translateStyleName(node->getTag(), node));

    auto widget = g_ui.createWidget(styleName.empty() ? "UIHTML" : styleName, parent);
    widgets.emplace_back(widget);

    node->setWidget(widget);

    widget->setHtmlNode(node);
    widget->setHtmlRootId(htmlId);
    widget->ensureUniqueId();

    if (node->getType() == NodeType::Text) {
        textNodes.emplace_back(node);
        widget->setTextAlign(Fw::AlignTopLeft);
        widget->setFocusable(false);
        widget->setPhantom(true);
    }

    if (node->isExpression()) {
        node->setAttr("*text", node->getText());
    }

    if (!node->getChildren().empty()) {
        for (const auto& child : node->getChildren()) {
            createWidgetFromNode(child, widget, textNodes, htmlId, moduleName, widgets);
        }
    }

    return widget;
}

void applyAttributesAndStyles(UIWidget* widget, HtmlNode* node, std::unordered_map<std::string, UIWidgetPtr>& groups, const std::string& moduleName) {
    const auto& styleValue = node->getAttr("style");
    if (!styleValue.empty()) {
        parseAttrPropList(styleValue, node->getAttrStyles());
        for (const auto& [prop, value] : node->getAttrStyles()) {
            if (isInheritable(prop)) {
                setChildrenStyles(widget->getHtmlId(), node, "styles", prop, value);
            }
        }
    }

    const auto consumedAttributes = applyPresentationalHints(widget, node);

    // text node depends on style
    if (!node->getText().empty()) {
        widget->setText(node->getText());
    }

    auto styles = std::make_shared<OTMLNode>();

    std::map<std::string, StyleValue> stylesMerge;

    for (const auto& [key, stylesMap] : node->getStyles()) {
        if (key != "styles") {
            auto meta = std::make_shared<OTMLNode>();
            meta->setTag(key);
            styles->addChild(meta);

            for (const auto& [prop, value] : stylesMap) {
                auto nodeAttr = std::make_shared<OTMLNode>();
                nodeAttr->setTag(prop);
                nodeAttr->setValue(value.value);
                meta->addChild(nodeAttr);
            }
        } else for (const auto& [prop, value] : stylesMap) {
            stylesMerge[prop] = value;
        }
    }

    for (const auto& [prop, value] : node->getAttrStyles()) {
        stylesMerge[prop] = { value , "", false };
    }

    for (const auto& [prop, value] : stylesMerge) {
        auto nodeAttr = std::make_shared<OTMLNode>();
        nodeAttr->setTag(prop);
        nodeAttr->setValue(value.value);
        styles->addChild(nodeAttr);
    }

    g_ui.resolveStyleAliases(styles);
    widget->mergeStyle(styles);

    if (node->getTag() == "input" && node->getAttr("type") == "radio")
        createRadioGroup(node, groups);

    for (const auto& [key, v] : node->getAttributesMap()) {
        auto attr = key;
        auto value = v;
        translateAttribute(widget->getStyleName(), node->getTag(), attr, value);

        if (attr.starts_with("on") || attr.starts_with("*for")) {
            // lua call
        } else if (consumedAttributes.contains(key)) {
            // applied as presentational hint
        } else if (attr == "anchor") {
            // ignore
        } else if (attr == "style" || attr == "id") {
            // executed before
        } else if (attr == "layout") {
            auto otml = std::make_shared<OTMLNode>();
            auto layout = std::make_shared<OTMLNode>();

            std::map<std::string, std::string> styles;
            parseAttrPropList(value, styles);
            for (const auto& [tag, value] : styles) {
                auto nodeAttr = std::make_shared<OTMLNode>();
                nodeAttr->setTag(tag);
                nodeAttr->setValue(value);
                layout->addChild(nodeAttr);
            }

            layout->setTag("layout");
            otml->addChild(layout);
            widget->mergeStyle(otml);
        } else if (attr == "class") {
            for (const auto& className : stdext::split(value, " ")) {
                if (const auto& style = g_ui.getStyle(className))
                    widget->mergeStyle(style);
            }
        } else {
            widget->callLuaField("__applyOrBindHtmlAttribute", attr, value, isInheritable(attr), moduleName, node->toString());
        }
    }

    std::unordered_map<std::string, std::string> inheritedStyles;
    inheritedStyles.reserve(stylesMerge.size());
    for (const auto& [prop, value] : stylesMerge)
        if (isInheritable(prop) && !value.inheritedFromId.empty())
            inheritedStyles[prop] = value.inheritedFromId;

    widget->callLuaField("__onHtmlProcessFinished", inheritedStyles);

    node->setStyleResolved(true);
}

UIWidgetPtr HtmlManager::readNode(DataRoot& root, const UIWidgetPtr& parent, const std::string& moduleName, const std::string& htmlPath, bool checkRuleExist, uint32_t htmlId) {
    auto path = "/modules/" + moduleName + "/";

    std::string script;
    std::string scriptStr;

    std::vector<HtmlNodePtr> textNodes;
    std::vector<UIWidgetPtr> widgets;
    textNodes.reserve(32);
    widgets.reserve(32);

    const bool isDynamic = root.dynamicNode != nullptr;
    const bool insertWithOrder = parent->m_insertChildIndex > -1;

    UIWidgetPtr widget;
    for (const auto& el : (isDynamic ? root.dynamicNode : root.node)->getChildren()) {
        if (el->getTag() == "style") {
            root.sheets.emplace_back(css::parse(el->textContent()));
        } else if (el->getTag() == "link") {
            if (el->hasAttr("href")) {
                root.sheets.emplace_back(css::parse(g_resources.readFileContents(path + el->getAttr("href"))));
            }
        } else if (el->getTag() == "script") {
            script = el->getText();
            scriptStr = el->toString();
        } else if (el->getTag() == "html") {
            for (const auto& n : el->getChildren()) {
                if (isDynamic) {
                    n->getInheritableStyles() = parent->getHtmlNode()->getInheritableStyles();
                    // Inherited values must reach the whole inserted subtree, not only its root.
                    const auto inheritable = n->getInheritableStyles();
                    for (const auto& [styleName, styleMap] : inheritable) {
                        for (const auto& [style, value] : styleMap) {
                            auto& nodeStyles = n->getStyles()[styleName];
                            const auto it = nodeStyles.find(style);
                            if (it == nodeStyles.end() || canInheritOver(it->second)) {
                                nodeStyles[style] = { value , parent->getHtmlId() };
                                setChildrenStyles(parent->getHtmlId(), n.get(), styleName, style, value);
                            }
                        }
                    }
                }
                widget = createWidgetFromNode(n, parent, textNodes, htmlId, moduleName, widgets);
            }
        }
    }

    if (!widget)
        return nullptr;

    if (widget && !script.empty())
        widget->callLuaField("__scriptHtml", moduleName, script, scriptStr);

    const auto mainNode = root.node.get();

    if (isDynamic) {
        if (insertWithOrder) {
            parent->getHtmlNode()->insert(widget->getHtmlNode(), parent->m_insertChildIndex - 1);
        } else {
            parent->getHtmlNode()->append(widget->getHtmlNode());
        }
    }

    for (const auto& sheet : GLOBAL_STYLES)
        applyStyleSheet(mainNode, htmlPath, sheet, false);

    for (const auto& sheet : root.sheets)
        applyStyleSheet(mainNode, htmlPath, sheet, checkRuleExist);

    for (const auto& widget : widgets) {
        if (widget->isDestroyed()) {
            // It is destroyed because the parent is inherit-text
            continue;
        }

        const auto node = widget->getHtmlNode().get();
        const auto w = widget.get();
        applyAttributesAndStyles(w, node, root.groups, moduleName);
        w->scheduleHtmlTask(PropApplyAnchorAlignment);
        w->callLuaField("onCreateByHTML", node->getTag(), node->getAttributesMap(), moduleName, node->toString());
    }

    if (isDynamic) {
        widget->refreshHtml(insertWithOrder);
    }

    return widget;
}

uint32_t HtmlManager::load(const std::string& moduleName, const std::string& htmlPath, UIWidgetPtr parent) {
    auto path = "/modules/" + moduleName + "/";
    auto htmlContent = g_resources.readFileContents(path + htmlPath);

    auto root = DataRoot{ parseHtml(htmlContent), nullptr, moduleName, {}, {} };

    if (root.node->getChildren().empty())
        return 0;

    if (!parent)
        parent = g_ui.getRootWidget();

    static uint32_t ID = 0;
    auto& rootEmplaced = m_nodes.emplace(++ID, std::move(root)).first->second;
    readNode(rootEmplaced, parent, moduleName, htmlPath, false, ID);
    return ID;
}

UIWidgetPtr HtmlManager::createWidgetFromHTML(std::string html, const UIWidgetPtr& parent, uint32_t htmlId) {
    auto it = m_nodes.find(htmlId);
    if (it == m_nodes.end()) {
        return nullptr;
    }

    stdext::trimSpacesAndNewlines(html);
    if (!html.starts_with("<html>"))
        html = "<html>" + html + "</html>";

    auto rootCopy = it->second;
    rootCopy.dynamicNode = parseHtml(html);
    return readNode(rootCopy, parent, it->second.moduleName, "", false, htmlId);
}

void HtmlManager::destroy(uint32_t id) {
    auto it = m_nodes.find(id);
    if (it == m_nodes.end())
        return;

    std::vector<UIWidget*> widgets;

    if (const auto& html = it->second.node->querySelector("html")) {
        widgets.reserve(html->getChildren().size());
        for (const auto& node : html->getChildren()) {
            if (const auto widget = node->getWidget().get())
                widgets.emplace_back(widget);
        }
    }

    for (auto widget : widgets)
        widget->destroy();

    for (const auto& [name, group] : it->second.groups) {
        group->destroy();
    }

    m_nodes.erase(it);
}

void HtmlManager::addGlobalStyle(const std::string& stylePath) {
    GLOBAL_STYLES.emplace_back(css::parse(g_resources.readFileContents(stylePath)));
}

const DataRoot* HtmlManager::getRoot(uint32_t id) {
    auto it = m_nodes.find(id);
    if (it != m_nodes.end()) {
        return &it->second;
    }

    return nullptr;
}

UIWidgetPtr HtmlManager::getRootWidget(uint32_t id) {
    if (const auto root = getRoot(id)) {
        if (const auto& firstNode = root->node->querySelector("html > :first")) {
            return firstNode->getWidget();
        }
    }

    return nullptr;
}
