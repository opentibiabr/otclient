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

 /**
  * @brief Policies for breaking words when wrapping text.
  *
  * - Normal: Prefer breaking at spaces and natural hyphens; avoid breaking inside words.
  * - BreakAll: Allow breaking between any grapheme clusters when needed (URL/CJK-like behavior).
  * - KeepAll: Avoid breaking inside words/ideographs; only explicit break opportunities are used.
  */
enum class WordBreakMode { Normal, BreakAll, KeepAll };

/**
 * @brief Policies for forcing a wrap when a single token doesn't fit the line.
 *
 * - Normal: Do not force intra-word wrapping; the token may overflow if it doesn't fit.
 * - BreakWord: Allow wrapping a long token if needed (prefer safe breakpoints first).
 * - Anywhere: Permit wrapping at any position when needed (ignores typical restrictions).
 */
enum class OverflowWrapMode { Normal, BreakWord, Anywhere };

/**
 * @brief Hyphen rendering policy at wrap points.
 *
 * - None: Never render an automatic hyphen; only visible real hyphens remain.
 * - Manual: Render a hyphen only at manual soft hyphen positions (U+00AD, &shy;).
 * - Auto: May render a hyphen when breaking inside an alphabetic word as a fallback
 *         (dictionary-based hyphenation is not implemented; this behaves conservatively).
 */
enum class HyphenationMode { None, Manual, Auto };

/**
 * @brief Fine-grained configuration for text wrapping, mirroring common HTML/CSS semantics.
 *
 * This structure controls where lines are allowed to break and whether a hyphen should appear
 * when a break occurs. It is designed to cover the majority of real-world cases without the
 * overhead of language dictionaries or external libraries. All Unicode code points listed below
 * are recognized in the input byte stream (UTF-8 expected).
 *
 * Behavior overview:
 * - Spaces collapse and provide natural break opportunities (similar to white-space: normal).
 * - No-break space (U+00A0) never breaks.
 * - Soft hyphen (U+00AD) is an *invisible* suggestion; if a line breaks there, a visible '-'
 *   is emitted when @ref hyphenationMode permits (Manual/Auto).
 * - Zero-width space (U+200B) provides a break opportunity *without* a visible hyphen.
 * - Word Joiner (U+2060) prevents a break around it.
 * - Real hyphens '-' are treated as natural break opportunities; no extra '-' is added.
 * - When a token overflows and no prior break opportunity exists, the decision to cut inside
 *   a word is controlled by @ref wordBreakMode and @ref overflowWrapMode.
 */
struct WrapOptions
{
    /**
     * @brief Word breaking mode. See @ref WordBreakMode.
     * Default: Normal (prefer spaces and existing hyphens, avoid intra-word breaks).
     */
    WordBreakMode wordBreakMode = WordBreakMode::Normal;

    /**
     * @brief Overflow wrap mode for tokens that exceed the available width. See @ref OverflowWrapMode.
     * Default: BreakWord (allow cutting long tokens when necessary).
     */
    OverflowWrapMode overflowWrapMode = OverflowWrapMode::BreakWord;

    /**
     * @brief Hyphenation policy at wrap points. See @ref HyphenationMode.
     * Default: Manual (show '-' only when breaking at U+00AD).
     */
    HyphenationMode hyphenationMode = HyphenationMode::Manual;

    /**
     * @brief Respect no-break space (U+00A0). If true, U+00A0 never becomes a break point.
     * Default: true.
     */
    bool allowNoBreakSpace = true;

    /**
     * @brief Respect manual soft hyphen (U+00AD). If true, U+00AD becomes a soft break
     *        where a visible '-' can appear if the line breaks there, depending on @ref hyphenationMode.
     * Default: true.
     */
    bool allowSoftHyphen = true;

    /**
     * @brief Respect zero-width break opportunities (U+200B and HTML <wbr>).
     *        If true, these positions are considered valid break points without adding a visible hyphen.
     * Default: true.
     */
    bool allowZeroWidthBreak = true;

    /**
     * @brief Respect Word Joiner (U+2060). If true, do not break at its position.
     * Default: true.
     */
    bool allowWordJoiner = true;

    /**
     * @brief Keep CJK ideographs together (approximation of line-break: keep-all).
     *        When true, the wrapper avoids breaking between contiguous CJK code points
     *        unless forced by @ref overflowWrapMode == Anywhere.
     * Default: false.
     */
    bool keepCJKWordsTogether = false;

    /**
     * @brief Optional IETF language tag (e.g., "en", "pt-BR"). Reserved for future
     *        dictionary-based hyphenation behavior (hyphenationMode == Auto).
     *        Currently not used beyond potential heuristics.
     */
    std::string language;
};
