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
#include "queryselector.h"

struct Selector;
struct AttrTest
{
    enum class Op { Present, Equals, Includes, Prefix, Suffix, Substr, DashMatch };
    std::string key;
    std::string val;
    Op op = Op::Present;
};

struct SimpleSelector
{
    std::string tag;
    std::string id;
    std::vector<std::string> classes;
    std::vector<AttrTest> attrs;
    std::vector<std::string> pseudos;
};

static const Selector& getOrParseSelector(const std::string&);
static bool matchFrom(const HtmlNodePtr&, const Selector&, size_t);

thread_local const HtmlNode* g_qs_scope = nullptr;

static inline bool isDescendantOf(const HtmlNodePtr& node, const HtmlNode* scope) {
    auto p = node;
    while (p) {
        if (p.get() == scope) return true;
        p = p->getParent();
    }
    return false;
}

static inline bool wantsNodeAll(const SimpleSelector& s) {
    for (const auto& p : s.pseudos)
        if (p == "node-all" || p == "all-node" || p == "nodes")
            return true;
    return false;
}

static inline bool isSpace(unsigned char c) { return std::isspace(c); }
static inline bool isAlphaNum_(unsigned char c) { return std::isalnum(c) || c == '-' || c == '_'; }
static inline bool isElement(const HtmlNodePtr& n) { return n && n->getType() == NodeType::Element; }

struct PtrHash { size_t operator()(const HtmlNode* p) const noexcept { return std::hash<const void*>{}(p); } };
struct PtrEq { bool operator()(const HtmlNode* a, const HtmlNode* b) const noexcept { return a == b; } };

struct SelectorStep
{
    enum class Combinator { Descendant, Child, Adjacent, Sibling };
    SimpleSelector simple;
    Combinator combinatorToPrev = Combinator::Descendant;
};

struct Selector
{
    std::vector<SelectorStep> steps;

    static std::vector<std::string> splitSelectorList(const std::string& s) {
        std::vector<std::string> parts; std::string cur; int paren = 0, bracket = 0;
        for (char ch : s) {
            if (ch == '(') ++paren; else if (ch == ')') --paren;
            else if (ch == '[') ++bracket; else if (ch == ']') --bracket;
            if (ch == ',' && paren == 0 && bracket == 0) { if (!cur.empty()) { parts.push_back(cur); cur.clear(); } } else cur.push_back(ch);
        }
        if (!cur.empty()) parts.push_back(cur);
        return parts;
    }

    static std::vector<std::string> tokenize(const std::string& s) {
        std::vector<std::string> tokens; std::string cur; int paren = 0, bracket = 0;
        auto flush = [&] { if (!cur.empty()) { tokens.push_back(cur); cur.clear(); } };
        for (size_t i = 0; i < s.size(); ++i) {
            char ch = s[i];
            if (ch == '(') ++paren; else if (ch == ')') --paren;
            else if (ch == '[') ++bracket; else if (ch == ']') --bracket;
            if (paren == 0 && bracket == 0 && (ch == '>' || ch == '+' || ch == '~')) { flush(); tokens.emplace_back(1, ch); } else if (paren == 0 && bracket == 0 && isSpace((unsigned char)ch)) { flush(); } else cur.push_back(ch);
        }
        flush(); return tokens;
    }

    static SimpleSelector parseCompound(const std::string& tok) {
        SimpleSelector s; size_t i = 0;
        auto readIdent = [&](std::string& out) { size_t st = i; while (i < tok.size() && isAlphaNum_((unsigned char)tok[i])) ++i; out = tok.substr(st, i - st); };
        if (i < tok.size()) {
            if (tok[i] == '*') { ++i; } else if (std::isalpha((unsigned char)tok[i])) { readIdent(s.tag); ascii_tolower_inplace(s.tag); }
        }
        while (i < tok.size()) {
            char c = tok[i];
            if (c == '.') { ++i; std::string cls; readIdent(cls); if (!cls.empty()) s.classes.push_back(cls); } else if (c == '#') { ++i; std::string id; readIdent(id); s.id = id; } else if (c == '[') {
                ++i; while (i < tok.size() && isSpace((unsigned char)tok[i])) ++i;
                size_t ks = i; while (i < tok.size() && !isSpace((unsigned char)tok[i]) && tok[i] != ']' && tok[i] != '=' && tok[i] != '~' && tok[i] != '^' && tok[i] != '$' && tok[i] != '*' && tok[i] != '|') ++i;
                std::string key = tok.substr(ks, i - ks); ascii_tolower_inplace(key);
                while (i < tok.size() && isSpace((unsigned char)tok[i])) ++i;
                AttrTest::Op op = AttrTest::Op::Present; std::string val;
                if (i < tok.size() && (tok[i] == '=' || tok[i] == '~' || tok[i] == '^' || tok[i] == '$' || tok[i] == '*' || tok[i] == '|')) {
                    std::string opStr; if (i + 1 < tok.size() && tok[i + 1] == '=') { opStr = tok.substr(i, 2); i += 2; } else if (tok[i] == '=') { opStr = "="; ++i; }
                    if (opStr == "=")  op = AttrTest::Op::Equals;
                    if (opStr == "~=") op = AttrTest::Op::Includes;
                    if (opStr == "^=") op = AttrTest::Op::Prefix;
                    if (opStr == "$=") op = AttrTest::Op::Suffix;
                    if (opStr == "*=") op = AttrTest::Op::Substr;
                    if (opStr == "|=") op = AttrTest::Op::DashMatch;
                    while (i < tok.size() && isSpace((unsigned char)tok[i])) ++i;
                    if (i < tok.size() && (tok[i] == '\"' || tok[i] == '\'')) {
                        char q = tok[i++]; size_t vs = i; while (i < tok.size() && tok[i] != q) ++i;
                        val = tok.substr(vs, i - vs); if (i < tok.size()) ++i;
                    } else {
                        size_t vs = i; while (i < tok.size() && tok[i] != ']') ++i;
                        val = tok.substr(vs, i - vs); while (!val.empty() && isSpace((unsigned char)val.back())) val.pop_back();
                    }
                }
                while (i < tok.size() && tok[i] != ']') ++i; if (i < tok.size()) ++i;
                s.attrs.push_back({ key,val,op });
            } else if (c == ':') {
                ++i; size_t ps = i; while (i < tok.size() && tok[i] != ':') ++i; s.pseudos.push_back(tok.substr(ps, i - ps));
            } else ++i;
        }
        return s;
    }

    static Selector parse(const std::string& selectorStr) {
        auto tokens = tokenize(selectorStr);
        struct LStep { SimpleSelector ss; char comb = ' '; };
        std::vector<LStep> left; char lastComb = ' ';
        for (const auto& t : tokens) {
            if (t == ">" || t == "+" || t == "~") { lastComb = t[0]; continue; }
            LStep ls; ls.ss = parseCompound(t); ls.comb = lastComb; lastComb = ' '; left.push_back(std::move(ls));
        }
        Selector sel;
        for (int i = (int)left.size() - 1; i >= 0; --i) {
            SelectorStep step; step.simple = std::move(left[i].ss);
            char c = left[i].comb;
            switch (c) {
                case '>': step.combinatorToPrev = SelectorStep::Combinator::Child; break;
                case '+': step.combinatorToPrev = SelectorStep::Combinator::Adjacent; break;
                case '~': step.combinatorToPrev = SelectorStep::Combinator::Sibling; break;
                default:  step.combinatorToPrev = SelectorStep::Combinator::Descendant; break;
            }
            sel.steps.push_back(std::move(step));
        }
        return sel;
    }

    static bool matchesNth(int idx1Based, const std::string& expr) {
        std::string s; for (char c : expr) if (!isSpace((unsigned char)c)) s.push_back(c);
        ascii_tolower_inplace(s);
        if (s == "odd") return (idx1Based % 2) == 1;
        if (s == "even") return (idx1Based % 2) == 0;
        int a = 0, b = 0; auto npos = s.find('n');
        if (npos == std::string::npos) {
            try { b = std::stoi(s); } catch (...) { return false; }
            return idx1Based == b;
        }
        std::string aStr = s.substr(0, npos), bStr = s.substr(npos + 1);
        if (aStr.empty() || aStr == "+") a = 1; else if (aStr == "-") a = -1; else { try { a = std::stoi(aStr); } catch (...) { return false; } }
        if (!bStr.empty()) { try { b = std::stoi(bStr); } catch (...) { return false; } }
        if (a == 0) return idx1Based == b;
        int diff = idx1Based - b;
        if (diff % a != 0) return false;
        return diff / a >= 0;
    }

    static bool attrMatch(const std::string& v, const AttrTest& a) {
        switch (a.op) {
            case AttrTest::Op::Present:  return !v.empty();
            case AttrTest::Op::Equals:   return v == a.val;
            case AttrTest::Op::Includes: {
                size_t i = 0; while (i < v.size()) {
                    while (i < v.size() && isSpace((unsigned char)v[i])) ++i;
                    size_t s = i; while (i < v.size() && !isSpace((unsigned char)v[i])) ++i;
                    if (s < i && v.substr(s, i - s) == a.val) return true;
                } return false;
            }
            case AttrTest::Op::Prefix:   return v.rfind(a.val, 0) == 0;
            case AttrTest::Op::Suffix:   return v.size() >= a.val.size() && v.compare(v.size() - a.val.size(), a.val.size(), a.val) == 0;
            case AttrTest::Op::Substr:   return v.find(a.val) != std::string::npos;
            case AttrTest::Op::DashMatch:return v == a.val || (v.size() > a.val.size() && v.rfind(a.val + "-", 0) == 0);
        }
        return false;
    }

    bool matchesSimple(const HtmlNodePtr& node, const SimpleSelector& s) const {
        if (!node) return false;

        const bool isElem = node->getType() == NodeType::Element;
        const bool isText = node->getType() == NodeType::Text;
        const bool allowText = wantsNodeAll(s);

        if (!isElem) {
            if (isText && allowText) {
                if (!s.tag.empty() && s.tag != "*") return false;
                if (!s.id.empty()) return false;
                if (!s.classes.empty()) return false;
                if (!s.attrs.empty()) return false;
                return true;
            }
            return false;
        }

        if (!s.tag.empty() && s.tag != "*" && node->getTag() != s.tag) return false;
        if (!s.id.empty() && node->getAttr("id") != s.id) return false;
        for (const auto& cls : s.classes) {
            bool ok = false; for (const auto& t : node->getClassList()) { if (t == cls) { ok = true; break; } }
            if (!ok) return false;
        }
        for (const auto& a : s.attrs) {
            if (a.op == AttrTest::Op::Present) { if (!node->hasAttr(a.key)) return false; } else if (!attrMatch(node->getAttr(a.key), a)) return false;
        }

        if (!s.pseudos.empty()) {
            auto testPseudo = [&](const std::string& pseudo)->bool {
                if (pseudo == "node-all" || pseudo == "all-node" || pseudo == "nodes") return true;
                if (pseudo == "hover") { return node->isHovered; } if (pseudo == "focus") { return node->isFocused; } if (pseudo == "active") { return node->isActive; } if (pseudo == "focus-visible") { return node->isFocused; } if (pseudo == "focus-within") { if (node->isFocused) return true;     std::vector<HtmlNodePtr> st; for (auto& c : node->getChildren()) if (isElement(c)) st.push_back(c);     while (!st.empty()) { auto cur = st.back(); st.pop_back(); if (cur->isFocused) return true; for (auto& c : cur->getChildren()) if (isElement(c)) st.push_back(c); }     return false; } if (pseudo == "disabled") { std::string aria = node->getAttr("aria-disabled"); return node->hasAttr("disabled") || aria == "true" || aria == "1"; } if (pseudo == "enabled") { std::string aria = node->getAttr("aria-disabled"); bool dis = node->hasAttr("disabled") || aria == "true" || aria == "1"; return !dis; } if (pseudo == "checked") { std::string aria = node->getAttr("aria-checked"); if (aria == "true" || aria == "1") return true; return node->hasAttr("checked"); }
                if (pseudo == "root") { return !node->getParent(); }
                if (pseudo == "scope") { return g_qs_scope && node.get() == g_qs_scope; }
                if (pseudo == "first-child") {
                    if (auto p = node->getParent()) {
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element) return c.get() == node.get();
                    } return false;
                }
                if (pseudo == "last-child") {
                    if (auto p = node->getParent()) {
                        for (auto it = p->getChildren().rbegin(); it != p->getChildren().rend(); ++it) if ((*it)->getType() == NodeType::Element) return (*it).get() == node.get();
                    } return false;
                }
                if (pseudo == "only-child") {
                    if (auto p = node->getParent()) {
                        int cnt = 0; for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element) ++cnt;
                        return cnt == 1;
                    } return false;
                }
                if (pseudo == "only-of-type") {
                    if (auto p = node->getParent()) {
                        int cnt = 0; for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element && c->getTag() == node->getTag()) ++cnt;
                        return cnt == 1;
                    } return false;
                }
                if (pseudo == "empty") {
                    for (const auto& c : node->getChildren()) {
                        if (c->getType() == NodeType::Element) return false;
                        if (c->getType() == NodeType::Text && !c->getRawText().empty()) return false;
                    }
                    return true;
                }
                if (pseudo.rfind("nth-child(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(10, pseudo.size() - 11);
                    int idx = node->indexAmongElements() + 1;
                    return matchesNth(idx, inside);
                }
                if (pseudo.rfind("nth-last-child(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(15, pseudo.size() - 16);
                    int idx = 0, total = 0;
                    if (auto p = node->getParent()) {
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element) ++total;
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element) {
                            ++idx;
                            if (c.get() == node.get()) break;
                        }
                    }
                    int lastIdx = (total - idx) + 1;
                    return matchesNth(lastIdx, inside);
                }
                if (pseudo == "first-of-type") {
                    if (auto p = node->getParent()) {
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element && c->getTag() == node->getTag()) return c.get() == node.get();
                    } return false;
                }
                if (pseudo == "last-of-type") {
                    if (auto p = node->getParent()) {
                        for (auto it = p->getChildren().rbegin(); it != p->getChildren().rend(); ++it) if ((*it)->getType() == NodeType::Element && (*it)->getTag() == node->getTag()) return (*it).get() == node.get();
                    } return false;
                }
                if (pseudo.rfind("nth-of-type(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(12, pseudo.size() - 13);
                    int idx = node->indexAmongType() + 1;
                    return matchesNth(idx, inside);
                }
                if (pseudo.rfind("nth-last-of-type(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(17, pseudo.size() - 18);
                    int idx = 0, total = 0;
                    if (auto p = node->getParent()) {
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element && c->getTag() == node->getTag()) ++total;
                        for (const auto& c : p->getChildren()) if (c->getType() == NodeType::Element && c->getTag() == node->getTag()) {
                            ++idx;
                            if (c.get() == node.get()) break;
                        }
                    }
                    int lastIdx = (total - idx) + 1;
                    return matchesNth(lastIdx, inside);
                }
                if (pseudo.rfind("not(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(4, pseudo.size() - 5);
                    for (const auto& part : splitSelectorList(inside)) {
                        const Selector& neg = getOrParseSelector(part);
                        if (!neg.steps.empty() && matchesSimple(node, neg.steps[0].simple)) return false;
                    }
                    return true;
                }
                if (pseudo.rfind("is(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(3, pseudo.size() - 4);
                    for (const auto& part : splitSelectorList(inside)) {
                        const Selector& tmp = getOrParseSelector(part);
                        if (!tmp.steps.empty() && matchesSimple(node, tmp.steps[0].simple)) return true;
                    } return false;
                }
                if (pseudo.rfind("where(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(6, pseudo.size() - 7);
                    for (const auto& part : splitSelectorList(inside)) {
                        const Selector& tmp = getOrParseSelector(part);
                        if (!tmp.steps.empty() && matchesSimple(node, tmp.steps[0].simple)) return true;
                    } return false;
                }
                if (pseudo.rfind("has(", 0) == 0 && pseudo.back() == ')') {
                    std::string inside = pseudo.substr(4, pseudo.size() - 5);
                    const Selector& inner = getOrParseSelector(inside);
                    if (inner.steps.empty()) return false;
                    std::vector<HtmlNodePtr> stack;
                    for (auto& c : node->getChildren()) if (isElement(c)) stack.push_back(c);
                    while (!stack.empty()) {
                        auto cur = stack.back(); stack.pop_back();
                        if (matchFrom(cur, inner, 0)) return true;
                        for (auto& c : cur->getChildren()) if (isElement(c)) stack.push_back(c);
                    }
                    return false;
                }
                return true;
            };
            for (const auto& pseudo : s.pseudos) { if (!testPseudo(pseudo)) return false; }
        }
        return true;
    }
};

static const Selector& getOrParseSelector(const std::string& s) {
    static std::unordered_map<std::string, Selector> cache;
    auto it = cache.find(s);
    if (it != cache.end()) return it->second;
    Selector parsed = Selector::parse(s);
    auto [pos, ok] = cache.emplace(s, std::move(parsed));
    return pos->second;
}

static bool matchFrom(const HtmlNodePtr& node, const Selector& sel, size_t idx);

static inline bool isUniversal(const std::string& tag) { return tag.empty() || tag == "*"; }

static void seedCandidates(HtmlNodePtr root, const Selector& sel, std::vector<HtmlNodePtr>& out) {
    if (sel.steps.empty()) return;
    const auto& right = sel.steps[0].simple;
    auto doc = root->documentRoot();

    if (wantsNodeAll(right)) {
        std::vector<HtmlNodePtr> st{ root };
        while (!st.empty()) {
            auto cur = st.back(); st.pop_back();
            if (!g_qs_scope || isDescendantOf(cur, g_qs_scope)) {
                auto t = cur->getType();
                if (t == NodeType::Element || t == NodeType::Text)
                    out.push_back(cur);
            }
            for (auto& c : cur->getChildren()) st.push_back(c);
        }
        return;
    }

    if (!right.id.empty()) {
        if (auto sp = doc->getById(right.id)) {
            if (isElement(sp) && (!g_qs_scope || isDescendantOf(sp, g_qs_scope)))
                out.push_back(sp);
        }
        return;
    }

    if (!right.classes.empty()) {
        for (auto& sp : doc->getByClass(right.classes[0])) {
            if (isElement(sp) && (!g_qs_scope || isDescendantOf(sp, g_qs_scope)))
                out.push_back(sp);
        }
        if (!out.empty()) {
            if (!isUniversal(right.tag)) {
                std::vector<HtmlNodePtr> filtered;
                for (auto& n : out)
                    if (n->getTag() == right.tag) filtered.push_back(n);
                out.swap(filtered);
            }
            return;
        }
    }

    if (!isUniversal(right.tag)) {
        for (auto& sp : doc->getByTag(right.tag)) {
            if (isElement(sp) && (!g_qs_scope || isDescendantOf(sp, g_qs_scope)))
                out.push_back(sp);
        }
        if (!out.empty()) return;
    }

    std::vector<HtmlNodePtr> st{ root };
    while (!st.empty()) {
        auto cur = st.back(); st.pop_back();
        if (isElement(cur)) out.push_back(cur);
        for (auto& c : cur->getChildren()) st.push_back(c);
    }
}

static bool matchFrom(const HtmlNodePtr& node, const Selector& sel, size_t idx) {
    if (!node || idx >= sel.steps.size()) return false;
    const auto& step = sel.steps[idx];
    if (!sel.matchesSimple(node, step.simple)) return false;
    if (idx + 1 == sel.steps.size()) return true;
    switch (step.combinatorToPrev) {
        case SelectorStep::Combinator::Descendant: {
            auto p = node->getParent();
            while (p) { if (matchFrom(p, sel, idx + 1)) return true; p = p->getParent(); }
            return false;
        }
        case SelectorStep::Combinator::Child: {
            return matchFrom(node->getParent(), sel, idx + 1);
        }
        case SelectorStep::Combinator::Adjacent: {
            if (auto p = node->getParent()) {
                const auto& kids = p->getChildren();
                for (size_t i = 0; i < kids.size(); ++i) {
                    if (kids[i].get() == node.get()) {
                        for (int j = (int)i - 1; j >= 0; --j) {
                            if (kids[j]->getType() == NodeType::Element) return matchFrom(kids[j], sel, idx + 1);
                        }
                        break;
                    }
                }
            }
            return false;
        }
        case SelectorStep::Combinator::Sibling: {
            if (auto p = node->getParent()) {
                const auto& kids = p->getChildren();
                for (size_t i = 0; i < kids.size(); ++i) {
                    if (kids[i].get() == node.get()) {
                        for (int j = (int)i - 1; j >= 0; --j) {
                            if (kids[j]->getType() == NodeType::Element)
                                if (matchFrom(kids[j], sel, idx + 1)) return true;
                        }
                        break;
                    }
                }
            }
            return false;
        }
    }
    return false;
}

std::vector<HtmlNodePtr> querySelectorAll(HtmlNodePtr root, const std::string& selectorStr) {
    std::vector<HtmlNodePtr> results;
    std::unordered_set<const HtmlNode*, PtrHash, PtrEq> seen;
    auto lists = Selector::splitSelectorList(selectorStr);
    if (lists.empty()) return results;

    g_qs_scope = root.get();
    for (const auto& part : lists) {
        const Selector& sel = getOrParseSelector(part);
        if (sel.steps.empty()) continue;
        std::vector<HtmlNodePtr> seeds;
        seedCandidates(root, sel, seeds);
        for (auto& node : seeds) {
            if (node.get() == g_qs_scope) continue;
            if (matchFrom(node, sel, 0)) {
                if (seen.insert(node.get()).second) results.push_back(node);
            }
        }
    }
    g_qs_scope = nullptr;
    return results;
}

HtmlNodePtr querySelector(HtmlNodePtr root, const std::string& selectorStr) {
    auto lists = Selector::splitSelectorList(selectorStr);
    if (lists.empty()) return nullptr;

    g_qs_scope = root.get();
    for (const auto& part : lists) {
        const Selector& sel = getOrParseSelector(part);
        if (sel.steps.empty()) continue;
        std::vector<HtmlNodePtr> seeds;
        seedCandidates(root, sel, seeds);
        for (auto& node : seeds) {
            if (node.get() == g_qs_scope) continue;
            if (matchFrom(node, sel, 0)) {
                g_qs_scope = nullptr;
                return node;
            }
        }
    }
    g_qs_scope = nullptr;
    return nullptr;
}