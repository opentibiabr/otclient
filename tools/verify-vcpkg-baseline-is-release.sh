#!/usr/bin/env bash
set -euo pipefail

python_bin=python3
if ! command -v "${python_bin}" >/dev/null 2>&1; then
	python_bin=python
fi

baseline_sha=$("${python_bin}" -c 'import json; print(json.load(open("vcpkg.json"))["builtin-baseline"])')

if [[ -z "${baseline_sha}" ]]; then
	echo "builtin-baseline is empty in vcpkg.json" >&2
	exit 1
fi

tmp_dir=".tmp/vcpkg-tags"
rm -rf "${tmp_dir}"
mkdir -p "${tmp_dir}"

git -C "${tmp_dir}" init -q
if ! git -C "${tmp_dir}" remote add origin https://github.com/microsoft/vcpkg.git; then
	echo "Failed to add vcpkg remote." >&2
	exit 1
fi

git -C "${tmp_dir}" fetch --tags origin
git -C "${tmp_dir}" fetch origin "${baseline_sha}"

tags=$(git -C "${tmp_dir}" tag --contains "${baseline_sha}")
if [[ -z "${tags}" ]]; then
	echo "builtin-baseline ${baseline_sha} is not contained in any microsoft/vcpkg release tag." >&2
	exit 1
fi

echo "builtin-baseline ${baseline_sha} is contained in release tag(s):"
echo "${tags}"
