#!/usr/bin/env python3
"""
Converts 'message' fields in compendium.json from a single HTML string
into a JSON array of lines. Run once to format, then commit.

Usage:  python format_messages.py
To undo: python format_messages.py --pack   (array -> single string)
"""

import json
import re
import sys

JSON_FILE = "compendium.json"

# Tags that should live on their own line with indentation tracking
BLOCK_TAGS = {
    'table', 'tbody', 'thead', 'tfoot', 'tr', 'td', 'th',
    'p', 'div', 'ul', 'ol', 'li',
    'center', 'br', 'hr',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
}

def _prettify(html: str) -> str:
    """Very simple HTML pretty-printer based on regex token splitting."""
    # Normalise existing whitespace (keep content readable)
    html = re.sub(r'\n', ' ', html)
    html = re.sub(r'[ \t]{2,}', ' ', html)

    # Split into tokens: tags and text nodes
    tokens = re.split(r'(<[^>]+>)', html)

    lines = []
    indent = 0
    INDENT_STR = '  '

    for token in tokens:
        token = token.strip()
        if not token:
            continue

        tag_match = re.match(r'^<(/?)([a-zA-Z0-9]+)', token)
        if tag_match:
            closing = tag_match.group(1) == '/'
            tag_name = tag_match.group(2).lower()
            self_closing = token.endswith('/>') or tag_name in ('br', 'hr', 'img', 'input', 'link', 'meta')

            if tag_name in BLOCK_TAGS:
                if closing:
                    indent = max(0, indent - 1)
                lines.append(INDENT_STR * indent + token)
                if not closing and not self_closing:
                    indent += 1
            else:
                # inline tags: append to current or start new
                if lines:
                    lines[-1] += token
                else:
                    lines.append(INDENT_STR * indent + token)
        else:
            # text node
            if lines and not re.match(r'^' + re.escape(INDENT_STR * indent) + r'\s*$', lines[-1]):
                lines[-1] += token
            else:
                lines.append(INDENT_STR * indent + token)

    return '\n'.join(lines)


def unpack(data: dict) -> dict:
    """Convert message strings -> arrays of lines."""
    for entry in data.get('gamenews', []):
        msg = entry.get('message')
        if isinstance(msg, str):
            pretty = _prettify(msg)
            entry['message'] = pretty.splitlines()
    return data


def pack(data: dict) -> dict:
    """Convert arrays of lines -> single string (reverse operation)."""
    for entry in data.get('gamenews', []):
        msg = entry.get('message')
        if isinstance(msg, list):
            entry['message'] = '\n'.join(msg)
    return data


def main():
    mode = 'unpack'
    if '--pack' in sys.argv:
        mode = 'pack'

    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if mode == 'unpack':
        data = unpack(data)
        print(f"Converted {sum(1 for e in data['gamenews'] if isinstance(e.get('message'), list))} "
              f"message fields to arrays.")
    else:
        data = pack(data)
        print(f"Converted {sum(1 for e in data['gamenews'] if isinstance(e.get('message'), str))} "
              f"message fields back to strings.")

    with open(JSON_FILE, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write('\n')

    print(f"Wrote {JSON_FILE}")


if __name__ == '__main__':
    main()
