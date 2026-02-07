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
        {"src", "image-source"}
        , {"align", "image-align"}
        , {"valign", "image-valign"}
        , {"vspace", "image-offset-y"}
        , {"hspace", "image-offset-x"}
    };

    static const std::unordered_map<std::string, std::string> cssMap = {
        {"active", "active"},
        {"focus", "focus"},
        {"hover", "hover"},
        {"pressed", "pressed"},
        {"checked", "checked"},
        {"disabled", "disabled"},
        {"first-child", "first"},
        {"middle", "middle"},
        {"last-child", "last"},
        {"nth-child(even)", "alternate"},
        {"nth-child(odd)", "alternate"},
        {"on", "on"},
        {"[aria-pressed='true']", "on"},
        {"[data-on]", "on"},
        {"dragging", "dragging"},
        {"hidden", "hidden"},
        {"[hidden]", "hidden"},
        {"mobile", "mobile"},
        {"@media", "mobile"}
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
        "text-decoration",
        "vertical-align",
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

    void setChildrenStyles(std::string_view htmlId, HtmlNode* n, const std::string& style, const std::string& prop, const std::string& value) {
        if (n->getType() == NodeType::Element)
            n->getInheritableStyles()[style][prop] = value;

        for (const auto& child : n->getChildren()) {
            auto& styleMap = child->getStyles()[style];
            auto it = styleMap.find(prop);
            if (it == styleMap.end() || !it->second.important) {
                child->getStyles()[style][prop] = { value , std::string{htmlId} };
                setChildrenStyles(htmlId, child.get(), style, prop, value);
            }
        }
    }

    std::string cssToState(const std::string& css) {
        if (auto it = cssMap.find(css); it != cssMap.end())
            return it->second;
        return "";
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

    void translateAttribute(std::string_view styleName, std::string_view tagName, std::string& attr, std::string& value) {
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

        // map some table-specific attributes to equivalent widget style tags
        if (tagName == "table") {
            if (attr == "cellpadding") {
                attr = "padding";
            } else if (attr == "cellspacing") {
                attr = "border-spacing";
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
                    bool hasMeta = false;
                    for (const auto& metas : rule.selectorMeta) {
                        for (const auto& state : metas.pseudos) {
                            for (const auto& decl : rule.decls) {
                                std::string style = "$";
                                if (state.negated)
                                    style += "!";
                                style += state.name;

                                auto& styleMap = node->getStyles()[style];
                                auto it = styleMap.find(decl.property);
                                if (it == styleMap.end() || !it->second.important) {
                                    styleMap[decl.property] = { decl.value , "", decl.important };
                                    if (!is_all && isInheritable(decl.property)) {
                                        setChildrenStyles(widget->getHtmlId(), node.get(), style, decl.property, decl.value);
                                    }
                                }
                            }
                            hasMeta = true;
                        }
                    }

                    if (hasMeta)
                        continue;

                    for (const auto& decl : rule.decls) {
                        auto& styleMap = node->getStyles()["styles"];
                        auto it = styleMap.find(decl.property);
                        if (it == styleMap.end() || !it->second.important) {
                            styleMap[decl.property] = { decl.value , "", decl.important };
                            if (!is_all && isInheritable(decl.property)) {
                                setChildrenStyles(widget->getHtmlId(), node.get(), "styles", decl.property, decl.value);
                            }
                        }
                    }
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
        node->removeAttr("*for");
        parent->callLuaField("__childFor", moduleName, condition, node->outerHTML(), parent->getChildren().size());
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

    // text node depends on style
    if (!node->getText().empty()) {
        widget->setText(node->getText());
    }

    auto styles = std::make_shared<OTMLNode>();

    std::map<std::string, StyleValue> stylesMerge;

    for (const auto [key, stylesMap] : node->getStyles()) {
        if (key != "styles") {
            auto meta = std::make_shared<OTMLNode>();
            meta->setTag(key);
            styles->addChild(meta);

            for (const auto [prop, value] : stylesMap) {
                auto nodeAttr = std::make_shared<OTMLNode>();
                nodeAttr->setTag(prop);
                nodeAttr->setValue(value.value);
                meta->addChild(nodeAttr);
            }
        } else for (const auto [prop, value] : stylesMap) {
            stylesMerge[prop] = value;
        }
    }

    for (const auto& [prop, value] : node->getAttrStyles()) {
        stylesMerge[prop] = { value , "", false };
    }

    for (const auto [prop, value] : stylesMerge) {
        auto nodeAttr = std::make_shared<OTMLNode>();
        nodeAttr->setTag(prop);
        nodeAttr->setValue(value.value);
        styles->addChild(nodeAttr);
    }

    widget->mergeStyle(styles);

    if (node->getTag() == "input" && node->getAttr("type") == "radio")
        createRadioGroup(node, groups);

    for (const auto [key, v] : node->getAttributesMap()) {
        auto attr = key;
        auto value = v;
        translateAttribute(widget->getStyleName(), node->getTag(), attr, value);

        if (attr.starts_with("on") || attr.starts_with("*for")) {
            // lua call
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
                    for (const auto& [styleName, styleMap] : n->getInheritableStyles()) {
                        for (auto& [style, value] : styleMap)
                            n->getStyles()[styleName][style] = { value , parent->getHtmlId() };
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

    auto root = DataRoot{ parseHtml(htmlContent), nullptr, moduleName };

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