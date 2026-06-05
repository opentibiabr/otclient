#!/usr/bin/env python3
"""
Serve the generated WebAssembly bundle with the isolation headers that Emscripten's
pthread builds require (COOP/COEP/CORP). Example:

  python3 tools/emscripten-web-serve.py --root build-emscripten-web --port 8000
"""

from __future__ import annotations

import argparse
import errno
import http.server
import os
import re
import shutil
import socket
import socketserver
import sys
from pathlib import Path
from subprocess import CalledProcessError, check_output

DEFAULT_HEADERS = {
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Content-Type": "application/wasm",
}


class HeaderInjectorHandler(http.server.SimpleHTTPRequestHandler):
    extra_headers: dict[str, str] = {}
    default_origin: str | None = None

    def _emit_extra_headers(self) -> None:
        for key, value in self.extra_headers.items():
            if key.lower() == "content-type":
                continue  # normal flow decides actual mime type per file
            self.send_header(key, value)
        allow_origin = self._determine_origin()
        if allow_origin:
            self.send_header("Access-Control-Allow-Origin", allow_origin)
            self.send_header("Vary", "Origin, Host")

    def end_headers(self) -> None:  # type: ignore[override]
        self._emit_extra_headers()
        super().end_headers()

    def guess_type(self, path: str) -> str:
        ctype = super().guess_type(path)
        if path.endswith(".wasm"):
            return DEFAULT_HEADERS["Content-Type"]
        return ctype

    def _determine_origin(self) -> str | None:
        origin = self.headers.get("Origin")
        if origin:
            return origin
        host_header = self.headers.get("Host")
        if host_header:
            scheme = "https" if self.server.server_address[1] == 443 else "http"
            return f"{scheme}://{host_header}"
        return self.default_origin


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Serve the browser build with COOP/COEP/CORP headers."
    )
    repo_root = Path(__file__).resolve().parents[1]
    default_root = repo_root / "build-emscripten-web"
    parser.add_argument(
        "--root",
        default=str(default_root),
        help=f"Directory to serve (default: {default_root})",
    )
    parser.add_argument("--port", type=int, default=8080, help="Port to bind (default: 8080)")
    parser.add_argument("--bind", default="0.0.0.0", help="Interface/IP to bind (default: 0.0.0.0)")
    return parser.parse_args()


def identify_port_holders(port: int) -> str | None:
    holders: list[str] = []
    lsof_path = shutil.which("lsof")
    if lsof_path:
        try:
            output = check_output(
                [lsof_path, "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"], text=True
            ).strip().splitlines()
        except CalledProcessError:
            output = []
        if len(output) > 1:
            for line in output[1:]:
                parts = line.split()
                if len(parts) >= 2:
                    holders.append(f"pid {parts[1]} ({parts[0]})")
            if holders:
                return ", ".join(holders)

    ss_path = shutil.which("ss")
    if ss_path:
        try:
            output = check_output([ss_path, "-H", "-ltnp"], text=True)
        except CalledProcessError:
            output = ""
        if output:
            port_pattern = re.compile(rf':{port}\b')
            proc_pattern = re.compile(r'"([^"]+)",pid=(\d+)')
            for line in output.splitlines():
                if not port_pattern.search(line):
                    continue
                match = proc_pattern.search(line)
                if match:
                    holders.append(f"pid {match.group(2)} ({match.group(1)})")
            if holders:
                # remove duplicates while preserving order
                return ", ".join(dict.fromkeys(holders))

    fuser_path = shutil.which("fuser")
    if fuser_path:
        try:
            output = check_output([fuser_path, "-n", "tcp", str(port)], text=True).strip()
        except CalledProcessError as err:
            output = err.output.strip() if err.output else ""
        if output:
            pids = [token for token in output.split() if token.isdigit()]
            if pids:
                return ", ".join(f"pid {pid}" for pid in pids)

    return None


def discover_addresses(port: int) -> list[str]:
    addrs: set[str] = {"127.0.0.1"}

    def add_addr(candidate: str | None) -> None:
        if candidate and candidate != "0.0.0.0":
            addrs.add(candidate)

    hostname_variants = {socket.gethostname(), socket.getfqdn()}
    for name in hostname_variants:
        try:
            host_ips = socket.gethostbyname_ex(name)[2]
            for ip in host_ips:
                add_addr(ip)
        except socket.gaierror:
            continue

    try:
        for info in socket.getaddrinfo(None, 0, socket.AF_INET, socket.SOCK_STREAM):
            add_addr(info[4][0])
    except socket.gaierror:
        pass

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))  # NOSONAR: harmless probe to discover outbound interface
            add_addr(s.getsockname()[0])
    except OSError:
        pass

    try:
        output = check_output(["hostname", "-I"], text=True).strip()
        for ip in output.split():
            add_addr(ip)
    except (CalledProcessError, FileNotFoundError):
        pass

    return [
        f"http://{addr}:{port}/otclient.html"  # NOSONAR: dev-only HTTP endpoint for local testing
        for addr in sorted(addrs)
    ]


def main() -> None:
    args = parse_args()
    serve_root = Path(args.root).expanduser().resolve()
    if not serve_root.exists():
        print(f"[error] Serve root '{serve_root}' does not exist.", file=sys.stderr)
        sys.exit(1)

    host_origin = (
        f"http://{args.bind}:{args.port}"  # NOSONAR: local-only origin for debugging server
        if args.bind != "0.0.0.0"
        else None
    )

    HeaderInjectorHandler.extra_headers = {
        key: value for key, value in DEFAULT_HEADERS.items() if key != "Content-Type"
    }
    HeaderInjectorHandler.default_origin = host_origin

    os.chdir(serve_root)
    try:
        httpd = socketserver.TCPServer((args.bind, args.port), HeaderInjectorHandler)
    except OSError as exc:
        if exc.errno == errno.EADDRINUSE:
            print(f"[error] Port {args.port} is already in use.", file=sys.stderr)
            holder_info = identify_port_holders(args.port)
            if holder_info:
                print(f"[hint] Held by {holder_info}.", file=sys.stderr)
            print("[hint] Stop that process or pick another --port.", file=sys.stderr)
            sys.exit(1)
        raise

    with httpd:
        urls = discover_addresses(args.port) if args.bind == "0.0.0.0" else [
            f"http://{args.bind}:{args.port}/otclient.html"  # NOSONAR: debugging server not exposed publicly
        ]
        print(f"Serving {serve_root} with COOP/COEP headers (Ctrl+C to stop)")
        for url in urls:
            print(f"  {url}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down...")


if __name__ == "__main__":
    main()
