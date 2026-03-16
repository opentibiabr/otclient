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

#include "../pch.h"

namespace stdext
{
    template <class K, class V,
        class Hash = phmap::priv::hash_default_hash<K>,
        class Eq = phmap::priv::hash_default_eq<K>,
        class Alloc = phmap::priv::Allocator<phmap::priv::Pair<const K, V>>>
    using map = phmap::flat_hash_map<K, V, Hash, Eq, Alloc>;

    template <class T,
        class Hash = phmap::priv::hash_default_hash<T>,
        class Eq = phmap::priv::hash_default_eq<T>,
        class Alloc = phmap::priv::Allocator<T>>
        using set = phmap::flat_hash_set<T, Hash, Eq, Alloc>;

    template<typename T>
    concept OnlyEnum = std::is_enum_v<T>;

    template<OnlyEnum Key>
    class dynamic_storage
    {
    public:
        template<typename T>
        void set(const Key& key, const T& value) { m_data[key] = value; }

        bool remove(const Key& k) { return m_data.erase(k) > 0; }

        template<typename T> T get(const Key& k, const T defaultValue = T()) const
        {
            auto it = m_data.find(k);
            if (it == m_data.end()) {
                return defaultValue;
            }

            try {
                return std::any_cast<T>(it->second);
            } catch (const std::exception&) {
                return defaultValue;
            }
        }

        bool has(const Key& k) const { return m_data.contains(k); }

        size_t size() const { return m_data.count(); }

        void clear() { m_data.clear(); }

    private:
        map<Key, std::any> m_data;
    };
}
