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

#include "htmlnode.h"
#include "htmlparser.h"
#include <stack>

static inline bool is_space(unsigned char c) { return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f'; }
static inline bool is_name_char(unsigned char c) { return std::isalnum(c) || c == '-' || c == ':' || c == '_'; }
static inline bool is_attr_name_char(unsigned char c) {
    return std::isalnum(c) || c == '-' || c == ':' || c == '_' ||
        c == '*' || c == '@' || c == '.' || c == '[' || c == ']' ||
        c == '(' || c == ')' || c == '#';
}

static const std::unordered_set<std::string> kVoid = {
    "area","base","br","col","embed","hr","img","input","link","meta","source","track","wbr"
};

// Inline phrasing / replaced elements: when one of these is adjacent to text without
// whitespace, inject a space at the boundary so "check the<a>link</a>here" and
// "Press<img .../>or click" both get a separating space automatically.
static const std::unordered_set<std::string> kInlinePhrasing = {
    "a","abbr","b","bdi","bdo","cite","code","data","del","dfn",
    "em","i","ins","kbd","mark","q","rp","rt","ruby","s",
    "samp","small","span","strong","sub","sup","time","u","var",
    // void inline replaced elements
    "img","audio","video","canvas","embed","object"
};

static const std::unordered_set<std::string> kPCloseOn = {
    "address","article","aside","blockquote","div","dl","fieldset","footer","form",
    "h1","h2","h3","h4","h5","h6","header","hgroup","hr","main","nav","ol","p",
    "pre","section","table","ul","figure","figcaption","menu"
};

static void skip_ws(const std::string& s, size_t& i) {
    while (i < s.size() && is_space((unsigned char)s[i])) ++i;
}

static std::string read_until(const std::string& s, size_t& i, char end) {
    size_t start = i;
    while (i < s.size() && s[i] != end) ++i;
    return s.substr(start, i - start);
}

static std::string html_entity_decode(const std::string& s) {
    std::string out; out.reserve(s.size());
    for (size_t i = 0; i < s.size();) {
        if (s[i] != '&') { out.push_back(s[i++]); continue; }
        size_t semi = s.find(';', i + 1);
        if (semi == std::string::npos) { out.push_back(s[i++]); continue; }
        std::string ent = s.substr(i + 1, semi - (i + 1));
        std::string rep;
        if (ent == "amp") rep = "&";
        else if (ent == "lt") rep = "<";
        else if (ent == "gt") rep = ">";
        else if (ent == "quot") rep = "\"";
        else if (ent == "apos") rep = "'";
        else if (!ent.empty() && ent[0] == '#') {
            long code = 0;
            if (ent.size() >= 2 && (ent[1] == 'x' || ent[1] == 'X')) {
                try { code = std::stol(ent.substr(2), nullptr, 16); } catch (...) { code = 0; }
            } else {
                try { code = std::stol(ent.substr(1), nullptr, 10); } catch (...) { code = 0; }
            }
            if (code > 0 && code <= 0x10FFFF) {
                unsigned int c = (unsigned int)code;
                if (c <= 0x7F) rep.push_back(char(c));
                else if (c <= 0x7FF) { rep.push_back(char(0xC0 | (c >> 6))); rep.push_back(char(0x80 | (c & 0x3F))); } else if (c <= 0xFFFF) { rep.push_back(char(0xE0 | (c >> 12))); rep.push_back(char(0x80 | ((c >> 6) & 0x3F))); rep.push_back(char(0x80 | (c & 0x3F))); } else { rep.push_back(char(0xF0 | (c >> 18))); rep.push_back(char(0x80 | ((c >> 12) & 0x3F))); rep.push_back(char(0x80 | ((c >> 6) & 0x3F))); rep.push_back(char(0x80 | (c & 0x3F))); }
            }
        }
        if (rep.empty()) { out.push_back(s[i++]); continue; }
        out += rep; i = semi + 1;
    }
    return out;
}

static void parseAttributes(std::unordered_map<std::string, std::string>& out,
    std::vector<std::string>& classList,
    const std::string& s, size_t& i)
{
    while (i < s.size()) {
        skip_ws(s, i);
        if (i >= s.size() || s[i] == '>' || (s[i] == '/' && i + 1 < s.size() && s[i + 1] == '>')) break;

        size_t keyStart = i;
        while (i < s.size() && is_attr_name_char((unsigned char)s[i])) ++i;
        if (i == keyStart) { ++i; continue; }
        std::string key = s.substr(keyStart, i - keyStart);
        ascii_tolower_inplace(key);

        skip_ws(s, i);
        std::string value;
        if (i < s.size() && s[i] == '=') {
            ++i; skip_ws(s, i);
            if (i < s.size() && (s[i] == '\"' || s[i] == '\'')) {
                char q = s[i++];
                value = read_until(s, i, q);
                if (i < s.size() && s[i] == q) ++i;
            } else {
                size_t vstart = i;
                while (i < s.size() && !is_space((unsigned char)s[i]) && s[i] != '>' && s[i] != '/') ++i;
                value = s.substr(vstart, i - vstart);
            }
        } else {
            value = "";
        }
        value = html_entity_decode(value);
        out[key] = value;

        if (key == "class" && !value.empty()) {
            size_t j = 0;
            while (j < value.size()) {
                while (j < value.size() && is_space((unsigned char)value[j])) ++j;
                size_t start = j;
                while (j < value.size() && !is_space((unsigned char)value[j])) ++j;
                if (start < j) classList.emplace_back(value.substr(start, j - start));
            }
        }
    }
}

static void impliedEndOnStart(const std::string& newTag, std::stack<HtmlNodePtr>& st) {
    bool popped = true;
    int guard = 0;
    while (popped && st.size() > 1 && guard++ < 32) {
        popped = false;
        if (st.top()->getType() != NodeType::Element) break;
        const std::string& open = st.top()->getTag();
        if (open == "p" && kPCloseOn.count(newTag)) { st.pop(); popped = true; continue; }
        if (open == "li" && newTag == "li") { st.pop(); popped = true; continue; }
        if ((open == "dt" && (newTag == "dt" || newTag == "dd")) ||
            (open == "dd" && (newTag == "dt" || newTag == "dd"))) {
            st.pop(); popped = true; continue;
        }
        if (open == "tr" && (newTag == "tr" || newTag == "tbody" || newTag == "thead" || newTag == "tfoot")) { st.pop(); popped = true; continue; }
        if ((open == "th" && (newTag == "th" || newTag == "td")) ||
            (open == "td" && (newTag == "td" || newTag == "th"))) {
            st.pop(); popped = true; continue;
        }
        if ((open == "option" && (newTag == "option" || newTag == "optgroup")) ||
            (open == "optgroup" && newTag == "optgroup")) {
            st.pop(); popped = true; continue;
        }
    }
}

HtmlNodePtr parseHtml(const std::string& html) {
    static const std::unordered_set<std::string> kTextOnly = {
        "script", "style", "title", "textarea", "option"
    };

    auto root = std::make_shared<HtmlNode>();
    root->type = NodeType::Element;
    root->tag = "root";

    std::stack<HtmlNodePtr> st;
    st.push(root);

    const std::string& s = html;
    size_t i = 0, N = s.size();

    auto push_node = [&](HtmlNodePtr node) {
        auto parent = st.top();

        // merge consecutive non-expression text nodes
        if (node->type == NodeType::Text && !node->isExpression() && !parent->children.empty()) {
            auto last = parent->children.back();
            if (last->type == NodeType::Text && !last->isExpression()) {
                last->text += node->text;
                return;
            }
        }

        // Inject a space into the preceding text node when an inline element
        // opens without any whitespace after the preceding text content.
        // e.g. "check the<a>link</a>" → "check the <a>link</a>"
        if (node->type == NodeType::Element && kInlinePhrasing.count(node->tag)) {
            if (!parent->children.empty()) {
                auto last = parent->children.back();
                if (last->type == NodeType::Text && !last->isExpression()
                    && !last->text.empty() && !is_space((unsigned char)last->text.back())) {
                    last->text += ' ';
                }
            }
        }

        if (!parent->children.empty()) {
            auto last = parent->children.back();
            last->next = node;
            node->prev = last;
        }

        node->parent = parent;
        parent->children.push_back(node);

        auto doc = root;
        if (node->type == NodeType::Element) {
            if (!node->tag.empty() && node->tag != "root")
                doc->tagIndex[node->tag].push_back(node);
            std::string idv = node->getAttr("id");
            if (!idv.empty()) doc->idIndex[idv] = node;
            if (!node->classList.empty())
                for (auto& cls : node->classList) doc->classIndex[cls].push_back(node);
        }
    };

    auto attach_front = [&](HtmlNodePtr parent, HtmlNodePtr node) {
        node->parent.reset();
        node->prev.reset();
        node->next.reset();

        if (!parent->children.empty()) {
            auto first = parent->children.front();
            node->next = first;
            first->prev = node;
            parent->children.insert(parent->children.begin(), node);
        } else {
            parent->children.push_back(node);
        }
        node->parent = parent;

        auto doc = root;
        if (node->type == NodeType::Element) {
            if (!node->tag.empty() && node->tag != "root")
                doc->tagIndex[node->tag].push_back(node);
            std::string idv = node->getAttr("id");
            if (!idv.empty()) doc->idIndex[idv] = node;
            if (!node->classList.empty())
                for (auto& cls : node->classList) doc->classIndex[cls].push_back(node);
        }
    };

    std::vector<HtmlNodePtr> hoistedRaw;
    hoistedRaw.reserve(10);

    auto append_or_drop_whitespace_literal = [&](const std::string& literal) {
        if (literal.empty()) return;

        bool onlyWhitespace = true;
        for (char c : literal) {
            if (!is_space((unsigned char)c)) { onlyWhitespace = false; break; }
        }

        auto parent = st.top();
        if (onlyWhitespace) {
            // If there's a previous text node, append whitespace to it;
            // otherwise, drop it (do not create a standalone whitespace node).
            if (!parent->children.empty()) {
                auto last = parent->children.back();
                if (last->type == NodeType::Text && !last->isExpression()) {
                    last->text += literal;
                    return;
                }
            }
            return; // drop standalone whitespace
        }

        // Inject a leading space when text immediately follows a closing inline element
        // with no whitespace in between.
        // e.g. "<a>link</a>here" → "<a>link</a> here"
        std::string adjustedLiteral = literal;
        if (!parent->children.empty()) {
            auto last = parent->children.back();
            if (last->type == NodeType::Element && kInlinePhrasing.count(last->tag)
                && !literal.empty() && !is_space((unsigned char)literal[0])) {
                adjustedLiteral = ' ' + literal;
            }
        }

        auto t = std::make_shared<HtmlNode>();
        t->type = NodeType::Text;
        t->text = adjustedLiteral;
        t->setExpression(false);
        push_node(t);
    };

    while (i < N) {
        if (s[i] == '<') {
            if (i + 3 < N && s.compare(i, 4, "<!--") == 0) {
                i += 4;
                size_t end = s.find("-->", i);
                auto node = std::make_shared<HtmlNode>();
                node->type = NodeType::Comment;
                node->text = (end == std::string::npos) ? s.substr(i) : s.substr(i, end - i);
                push_node(node);
                i = (end == std::string::npos) ? N : end + 3;
                continue;
            }
            if (i + 2 < N && s.compare(i, 2, "<!") == 0) {
                size_t gt = s.find('>', i + 2);
                auto node = std::make_shared<HtmlNode>();
                node->type = NodeType::Doctype;
                node->text = (gt == std::string::npos) ? s.substr(i + 2) : s.substr(i + 2, gt - (i + 2));
                push_node(node);
                i = (gt == std::string::npos) ? N : gt + 1;
                continue;
            }
            if (i + 1 < N && s[i + 1] == '/') {
                i += 2;
                size_t start = i;
                while (i < N && is_name_char((unsigned char)s[i])) ++i;
                std::string tag = s.substr(start, i - start);
                ascii_tolower_inplace(tag);
                while (i < N && s[i] != '>') ++i;
                if (i < N) ++i;
                while (st.size() > 1) {
                    auto top = st.top();
                    if (top->type == NodeType::Element && top->tag == tag) { st.pop(); break; }
                    st.pop();
                }
                continue;
            }

            ++i;
            size_t nameStart = i;
            while (i < N && is_name_char((unsigned char)s[i])) ++i;
            std::string tag = s.substr(nameStart, i - nameStart);
            ascii_tolower_inplace(tag);

            impliedEndOnStart(tag, st);

            auto node = std::make_shared<HtmlNode>();
            node->type = NodeType::Element;
            node->tag = tag;

            skip_ws(s, i);
            parseAttributes(node->attributes, node->classList, s, i);

            bool isRaw = (tag == "script" || tag == "style");
            bool selfClosing = false;
            if (i < N && s[i] == '/') { selfClosing = true; ++i; }
            if (i < N&& s[i] == '>') ++i;

            bool isVoid = kVoid.count(tag) > 0;
            if (!selfClosing && !isVoid) {
                if (isRaw) {
                    size_t closePos = std::string::npos;
                    std::string endTag = "</" + tag + ">";
                    closePos = s.find(endTag, i);

                    if (closePos == std::string::npos) {
                        node->text = s.substr(i);
                        i = N;
                    } else {
                        node->text = s.substr(i, closePos - i);
                        i = closePos + endTag.size();
                    }

                    if (st.top() != root) {
                        hoistedRaw.push_back(node);
                    } else {
                        push_node(node);
                    }
                } else {
                    push_node(node);
                    st.push(node);
                }
            } else {
                push_node(node);
            }
        } else {
            size_t start = i;
            size_t lt = s.find('<', i);
            if (lt == std::string::npos) lt = N;
            std::string txt = s.substr(start, lt - start);

            if (!txt.empty()) {
                std::string decoded = html_entity_decode(txt);

                // Fast path: if we are inside a text-only element, append verbatim
                auto parent = st.top();
                if (parent->getType() == NodeType::Element && kTextOnly.count(parent->getTag())) {
                    parent->text += decoded;
                } else {
                    // Split by expressions {{...}}; literals follow the whitespace policy.
                    size_t p = 0;
                    while (p < decoded.size()) {
                        size_t open = decoded.find("{{", p);
                        if (open == std::string::npos) {
                            append_or_drop_whitespace_literal(decoded.substr(p));
                            break;
                        }
                        if (open > p) {
                            append_or_drop_whitespace_literal(decoded.substr(p, open - p));
                        }
                        size_t close = decoded.find("}}", open + 2);
                        if (close == std::string::npos) {
                            // Treat the rest as literal (likely user error); still apply whitespace policy.
                            append_or_drop_whitespace_literal(decoded.substr(open));
                            break;
                        }

                        // expression node
                        std::string expr = decoded.substr(open + 2, close - (open + 2));
                        size_t l = 0, r = expr.size();
                        while (l < r && (unsigned char)expr[l] <= ' ') ++l;
                        while (r > l && (unsigned char)expr[r - 1] <= ' ') --r;
                        expr = expr.substr(l, r - l);

                        if (!expr.empty()) {
                            auto t = std::make_shared<HtmlNode>();
                            t->type = NodeType::Text;
                            t->text = expr;
                            t->setExpression(true);
                            push_node(t);
                        }
                        p = close + 2;
                    }
                }
            }

            i = lt;
        }
    }

    while (st.size() > 1) st.pop();

    if (!hoistedRaw.empty()) {
        for (auto it = hoistedRaw.rbegin(); it != hoistedRaw.rend(); ++it) {
            attach_front(root, *it);
        }
    }

    return root;
}