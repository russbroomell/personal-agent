#!/usr/bin/env python3
"""Sidekick Memory Card: a private page to read and edit what the agent knows.

Serves core memory (memories/USER.md, memories/MEMORY.md), the topic notes
folder, and recent scheduled-job output from one Hermes profile. Standard
library only. Binds to 127.0.0.1; reach it through an SSH tunnel:

    ssh -N -L 8765:127.0.0.1:8765 agent@YOUR_SERVER

Usage:
    server.py --home ~/.hermes/profiles/sidekick [--port 8765]

A random access token is stored in <home>/memory-card.token. Open
http://127.0.0.1:8765/?token=<token> once; the browser keeps a cookie.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hmac
import html
import os
import secrets
import shutil
import sys
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

CORE_LIMITS = {"USER.md": 1375, "MEMORY.md": 2200}
MAX_BYTES = 200_000

STYLE = """
:root{--bg:#f7f5f0;--card:#fff;--ink:#1d1b16;--muted:#6b665c;--line:#e4dfd3;
--accent:#3b5bdb;--warn:#b54708;--ok:#2b8a3e}
@media (prefers-color-scheme:dark){:root{--bg:#16150f;--card:#211f19;--ink:#efe9dc;
--muted:#a39d90;--line:#36332b;--accent:#8ea7ff;--warn:#f79009;--ok:#69db7c}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);
font:16px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
main{max-width:860px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:1.6rem;margin:0 0 4px}h2{font-size:1.1rem;margin:28px 0 8px}
p.lede{color:var(--muted);margin:0 0 20px}
a{color:var(--accent)}.card{background:var(--card);border:1px solid var(--line);
border-radius:12px;padding:14px 16px;margin:8px 0}
.row{display:flex;justify-content:space-between;gap:12px;align-items:baseline;flex-wrap:wrap}
.muted{color:var(--muted);font-size:.9rem}.warn{color:var(--warn)}.ok{color:var(--ok)}
pre{white-space:pre-wrap;word-wrap:break-word;margin:8px 0 0;font:14px/1.5 ui-monospace,Menlo,monospace}
textarea{width:100%;min-height:55vh;padding:12px;border-radius:8px;border:1px solid var(--line);
background:var(--card);color:var(--ink);font:14px/1.5 ui-monospace,Menlo,monospace}
button{background:var(--accent);color:#fff;border:0;border-radius:8px;padding:10px 18px;
font-size:1rem;cursor:pointer}nav a{margin-right:14px}
"""


def page(title: str, body: str) -> bytes:
    return (
        "<!doctype html><html lang=en><head><meta charset=utf-8>"
        "<meta name=viewport content='width=device-width,initial-scale=1'>"
        f"<title>{html.escape(title)}</title><style>{STYLE}</style></head>"
        f"<body><main>{body}</main></body></html>"
    ).encode()


class Store:
    def __init__(self, home: Path):
        self.home = home
        self.mem = home / "memories"
        self.notes = self._notes_dir()

    def _notes_dir(self) -> Path:
        user = self.mem / "USER.md"
        if user.exists():
            for line in user.read_text(errors="replace").splitlines():
                if line.lower().startswith("notes folder:"):
                    p = Path(line.split(":", 1)[1].strip()).expanduser()
                    if p.is_dir():
                        return p
        return self.home / "notes"

    def files(self) -> dict[str, Path]:
        out: dict[str, Path] = {}
        for name in ("USER.md", "MEMORY.md"):
            out[f"core/{name}"] = self.mem / name
        if self.notes.is_dir():
            for p in sorted(self.notes.glob("*.md")):
                out[f"notes/{p.name}"] = p
        return out

    def resolve(self, key: str) -> Path | None:
        return self.files().get(key)

    def activity(self, limit: int = 15) -> list[tuple[str, str, str]]:
        root = self.home / "cron" / "output"
        if not root.is_dir():
            return []
        runs = sorted(root.glob("*/*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
        items = []
        for p in runs[:limit]:
            when = dt.datetime.fromtimestamp(p.stat().st_mtime).strftime("%a %b %d, %H:%M")
            text = p.read_text(errors="replace")
            items.append((when, p.parent.name, text[:1200]))
        return items


class Handler(BaseHTTPRequestHandler):
    store: Store
    token: str
    allowed_hosts: set[str] = {"127.0.0.1", "localhost", "[::1]"}

    def log_message(self, fmt, *args):  # quiet, but keep errors on stderr
        if args and str(args[1]).startswith(("4", "5")):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # --- auth -------------------------------------------------------------
    def _authed(self) -> bool:
        q = parse_qs(urlparse(self.path).query)
        given = q.get("token", [""])[0]
        if given and hmac.compare_digest(given, self.token):
            return True
        c = cookies.SimpleCookie(self.headers.get("Cookie", ""))
        val = c["mc"].value if "mc" in c else ""
        return bool(val) and hmac.compare_digest(val, self.token)

    def _send(self, code: int, body: bytes, extra: dict | None = None):
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _deny(self):
        self._send(403, page("Memory Card", "<h1>Memory Card</h1><p class=lede>Open the link with "
                             "your access token. On the server: <code>cat memory-card.token</code> "
                             "in the agent's Hermes home.</p>"))

    def _host_ok(self) -> bool:
        raw = self.headers.get("Host") or ""
        host = (urlparse("//" + raw).hostname or "").lower()
        if host == "::1":
            host = "[::1]"
        return host in self.allowed_hosts

    # --- routes -----------------------------------------------------------
    def do_GET(self):
        if not self._host_ok():
            return self._send(400, b"bad host")
        if not self._authed():
            return self._deny()
        secure = "; Secure" if self.headers.get("X-Forwarded-Proto") == "https" else ""
        extra = {"Set-Cookie": f"mc={self.token}; HttpOnly; SameSite=Strict; Path=/{secure}"}
        url = urlparse(self.path)
        if url.path == "/":
            return self._send(200, self._index(), extra)
        if url.path == "/edit":
            key = parse_qs(url.query).get("f", [""])[0]
            return self._send(200, self._edit(key), extra)
        self._send(404, page("Not found", "<p>Not found. <a href='/'>Back</a></p>"))

    def do_POST(self):
        if not self._host_ok() or not self._authed():
            return self._deny()
        # Same-origin check for form posts.
        origin = self.headers.get("Origin", "")
        if origin and (urlparse(origin).hostname or "").lower() not in self.allowed_hosts:
            return self._send(403, b"bad origin")
        length = min(int(self.headers.get("Content-Length", "0") or 0), MAX_BYTES + 10_000)
        form = parse_qs(self.rfile.read(length).decode("utf-8", "replace"), keep_blank_values=True)
        key = form.get("f", [""])[0]
        text = form.get("text", [""])[0].replace("\r\n", "\n")
        path = self.store.resolve(key)
        if path is None or len(text.encode()) > MAX_BYTES:
            return self._send(400, page("Error", "<p>Can't save that file. <a href='/'>Back</a></p>"))
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            bak = path.parent / ".memory-card-backups"
            bak.mkdir(exist_ok=True)
            stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            shutil.copy2(path, bak / f"{path.name}.{stamp}")
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(text if text.endswith("\n") or not text else text + "\n")
        os.replace(tmp, path)
        self.send_response(303)
        self.send_header("Location", f"/?saved={quote(key)}")
        self.end_headers()

    # --- views ------------------------------------------------------------
    def _file_card(self, key: str, path: Path) -> str:
        text = path.read_text(errors="replace") if path.exists() else ""
        name = path.name
        limit = CORE_LIMITS.get(name) if key.startswith("core/") else None
        meta = f"{len(text):,} characters"
        cls = "muted"
        if limit:
            meta += f" of {limit:,}"
            if len(text) > limit:
                cls = "warn"
                meta += " (over the limit: Hermes will trim it)"
        shown = f"<pre>{html.escape(text)}</pre>" if text.strip() else "<p class=muted>(empty)</p>"
        return (
            f"<div class=card><div class=row><strong>{html.escape(name)}</strong>"
            f"<span><span class='{cls}'>{meta}</span> &middot; "
            f"<a href='/edit?f={quote(key)}'>Edit</a></span></div>{shown}</div>"
        )

    def _index(self) -> bytes:
        q = parse_qs(urlparse(self.path).query)
        saved = q.get("saved", [""])[0]
        files = self.store.files()
        core = "".join(self._file_card(k, p) for k, p in files.items() if k.startswith("core/"))
        notes = "".join(self._file_card(k, p) for k, p in files.items() if k.startswith("notes/"))
        acts = self.store.activity()
        act_html = "".join(
            f"<div class=card><div class=row><strong>{html.escape(job)}</strong>"
            f"<span class=muted>{html.escape(when)}</span></div><pre>{html.escape(text)}</pre></div>"
            for when, job, text in acts
        ) or "<p class=muted>No scheduled runs yet.</p>"
        banner = (f"<div class='card ok'>Saved {html.escape(saved)}. The agent uses it from its next "
                  "message (core memory from the next new chat).</div>") if saved else ""
        body = (
            "<h1>Memory Card</h1><p class=lede>Everything your assistant remembers about you, "
            "as plain files on your own server. Edit or delete any line. Each save keeps a backup.</p>"
            f"{banner}<nav><a href='#core'>Core memory</a><a href='#notes'>Topic notes</a>"
            "<a href='#activity'>Activity</a></nav>"
            f"<h2 id=core>Core memory <span class=muted>(in every conversation)</span></h2>{core}"
            f"<h2 id=notes>Topic notes <span class=muted>(read when a subject comes up)</span></h2>"
            f"<p class=muted>Folder: {html.escape(str(self.store.notes))}</p>{notes or '<p class=muted>No notes yet.</p>'}"
            f"<h2 id=activity>Activity <span class=muted>(recent scheduled runs)</span></h2>{act_html}"
        )
        return page("Memory Card", body)

    def _edit(self, key: str) -> bytes:
        path = self.store.resolve(key)
        if path is None:
            return page("Not found", "<p>Unknown file. <a href='/'>Back</a></p>")
        text = path.read_text(errors="replace") if path.exists() else ""
        limit = CORE_LIMITS.get(path.name) if key.startswith("core/") else None
        hint = f"<p class=muted>Keep this under {limit:,} characters.</p>" if limit else ""
        body = (
            f"<p><a href='/'>&larr; Memory Card</a></p><h1>{html.escape(path.name)}</h1>{hint}"
            "<form method=post action='/save'>"
            f"<input type=hidden name=f value='{html.escape(key, quote=True)}'>"
            f"<textarea name=text>{html.escape(text)}</textarea>"
            "<p><button type=submit>Save</button></p></form>"
        )
        return page(f"Edit {path.name}", body)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--home", required=True, help="Hermes profile home, e.g. ~/.hermes/profiles/sidekick")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--print-url", action="store_true", help="Print the access URL and exit")
    ap.add_argument("--allow-host", action="append", default=[],
                    help="Extra Host name to accept, e.g. the Tailscale HTTPS name (repeatable)")
    ap.add_argument("--public-url", default="", help="Base URL to print instead of 127.0.0.1 (with --print-url)")
    args = ap.parse_args()

    home = Path(args.home).expanduser().resolve()
    if not home.is_dir():
        print(f"No such Hermes home: {home}", file=sys.stderr)
        return 1
    tok_file = home / "memory-card.token"
    if not tok_file.exists():
        tok_file.write_text(secrets.token_urlsafe(24) + "\n")
        tok_file.chmod(0o600)
    token = tok_file.read_text().strip()
    base = args.public_url.rstrip("/") or f"http://127.0.0.1:{args.port}"
    url = f"{base}/?token={token}"
    if args.print_url:
        print(url)
        return 0

    Handler.store = Store(home)
    Handler.token = token
    Handler.allowed_hosts = {"127.0.0.1", "localhost", "[::1]"} | {h.lower() for h in args.allow_host}
    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Memory Card for {home} on 127.0.0.1:{args.port}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
