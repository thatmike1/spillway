"""Serve a built web prototype locally. Does not open a browser or use the GPU."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=1348)
    args = parser.parse_args()
    web_directory = Path(__file__).resolve().parent.parent / "builds/web"
    if not (web_directory / "index.html").is_file():
        parser.error("Web build missing. Run tools/export-web.ps1 first.")
    handler = partial(GameHandler, directory=str(web_directory))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Foldrunner: http://127.0.0.1:{args.port}/index.html", flush=True)
    print("Open that link when ready to use the GPU. Ctrl+C stops the server.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
