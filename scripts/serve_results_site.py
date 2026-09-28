import argparse
import json
import os
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ALLOWED_EXTENSIONS = {
    ".cs", ".razor", ".cshtml", ".csproj", ".sln", ".slnx", ".json",
    ".jsonl", ".md", ".txt", ".log", ".xml", ".props", ".targets",
    ".css", ".js", ".html", ".yml", ".yaml", ".config", ".http",
    ".ps1", ".trx",
}
ALLOWED_NAMES = {".editorconfig", ".gitignore"}


class ResultsHandler(SimpleHTTPRequestHandler):
    runs_root: Path

    def _json_response(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if urlparse(self.path).path == "/api/capabilities":
            self._json_response(200, {"openFile": True})
            return
        super().do_GET()

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/open-file":
            self._json_response(404, {"message": "Okänd lokal åtgärd."})
            return

        origin = self.headers.get("Origin")
        if origin and urlparse(origin).hostname not in {"127.0.0.1", "localhost", "::1"}:
            self._json_response(403, {"message": "Endast den lokala resultatwebben får öppna filer."})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 16_384:
                raise ValueError("Ogiltig anropsstorlek.")
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            run_id = str(payload.get("runId", ""))
            relative_path = str(payload.get("path", ""))
            run_root = (self.runs_root / run_id).resolve(strict=True)
            if run_root.parent != self.runs_root:
                raise ValueError("Ogiltigt run-ID.")
            target = (run_root / relative_path).resolve(strict=True)
            target.relative_to(run_root)
            if not target.is_file():
                raise ValueError("Filen finns inte.")
            if target.suffix.lower() not in ALLOWED_EXTENSIONS and target.name.lower() not in ALLOWED_NAMES:
                raise ValueError("Filtypen får inte öppnas från resultatwebben.")

            if sys.platform == "win32":
                os.startfile(str(target))
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(target)])
            else:
                subprocess.Popen(["xdg-open", str(target)])
            self._json_response(200, {"opened": True})
        except (OSError, ValueError, json.JSONDecodeError) as error:
            self._json_response(400, {"message": str(error)})


def main() -> None:
    parser = argparse.ArgumentParser(description="Lokal server för RoomBooking-resultat.")
    parser.add_argument("--site", required=True, type=Path)
    parser.add_argument("--runs", required=True, type=Path)
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()

    site_root = args.site.resolve(strict=True)
    ResultsHandler.runs_root = args.runs.resolve(strict=True)
    handler = lambda *handler_args, **handler_kwargs: ResultsHandler(
        *handler_args, directory=str(site_root), **handler_kwargs
    )
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Öppna http://127.0.0.1:{args.port} och avsluta servern med Ctrl+C.", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
