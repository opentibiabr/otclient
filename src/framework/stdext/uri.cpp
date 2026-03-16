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

#include "uri.h"

ParsedURI parseURI(const std::string& url) {
    // Regular expression pattern to match URL components
    static const std::regex PARSE_URL{
        R"((([httpsw]{2,5})://)?([^/ :]+)(:(\d+))?(/(.+)?))",
        std::regex_constants::ECMAScript | std::regex_constants::icase };

    ParsedURI result;
    std::smatch match;

    // Check if the URL matches the pattern and has the correct number of components
    if (std::regex_match(url, match, PARSE_URL) && match.size() == 8) {
        // Set protocol with default value "http" if not provided
        result.protocol = (match[2].str().empty()) ? "http" : match[2].str();

        // Set domain
        result.domain = match[3].str();

        // Check if protocol is "https" or "wss" to determine default port
        const bool isHttps = (result.protocol == "https" || result.protocol == "wss");
        result.port = (match[5].str().empty()) ? (isHttps) ? "443" : "80" : match[5].str();

        // Set query with default value "/"
        result.query = (match[6].str().empty()) ? "/" : match[6].str();
    }

    return result;
}