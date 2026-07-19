#!/usr/bin/env python3
"""Local entry/review app for data/mywork.csv. Stdlib only.

Launch by double-clicking "Add Work.command" (or: python3 scripts/add_work_app.py).
Opens a browser tab at http://localhost:4747. Two tabs:

  Add by URL   -- paste a link, Fetch pre-fills fields from the page's
                  metadata, correct anything, Add appends to mywork.csv,
                  commits, and pushes. GitHub Actions then renders the site.
  Review queue -- candidates the weekly discovery task wrote to
                  data/pending.csv. Approve publishes; Reject adds the URL
                  to data/skiplist.csv so it is never proposed again.

Only reachable from this machine while the window is open.
"""

import csv
import datetime
import json
import re
import subprocess
import sys
import threading
import urllib.request
import webbrowser
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORK_CSV = REPO / "data" / "mywork.csv"
PENDING_CSV = REPO / "data" / "pending.csv"
SKIP_CSV = REPO / "data" / "skiplist.csv"
NOW_QMD = REPO / "_now-entries.qmd"

HEADER = ["Date", "Original Title", "Outlet", "Format",
          "Link", "Highlight", "Author", "Excerpt"]
FORMATS = ["Quote", "Article", "Podcast", "White Paper",
           "TV", "Panel", "Book Review", "Radio"]

OUTLET_MAP = {
    "nytimes.com": "New York Times",
    "washingtonpost.com": "Washington Post",
    "npr.org": "NPR",
    "propublica.org": "ProPublica",
    "thenation.com": "The Nation",
    "vox.com": "Vox",
    "bloomberg.com": "Bloomberg",
    "politico.com": "Politico",
    "axios.com": "Axios",
    "wsj.com": "Wall Street Journal",
    "reuters.com": "Reuters",
    "apnews.com": "Associated Press",
    "theatlantic.com": "The Atlantic",
    "ft.com": "Financial Times",
    "economicsecurityproject.org": "Economic Security Project",
    "rooseveltinstitute.org": "Roosevelt Institute",
}

PORT = 4747
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36")


# ---------- helpers ----------------------------------------------------------

def squish(s):
    return re.sub(r"\s+", " ", (s or "")).strip()


def norm_url(u):
    return (u or "").strip().rstrip("/")


def read_rows(path):
    if not path.exists():
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def existing_links():
    return {norm_url(r["Link"]) for r in read_rows(WORK_CSV)}


def append_work_row(row):
    with open(WORK_CSV, "a", newline="", encoding="utf-8") as f:
        csv.writer(f, lineterminator="\n").writerow(
            [row[c] for c in HEADER])


def write_pending(rows):
    with open(PENDING_CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(HEADER)
        for r in rows:
            w.writerow([r[c] for c in HEADER])


def append_skiplist(link):
    new = not SKIP_CSV.exists()
    with open(SKIP_CSV, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        if new:
            w.writerow(["Link", "Rejected"])
        w.writerow([link, datetime.date.today().isoformat()])


# ---------- Now section (_now-entries.qmd) -----------------------------------
#
# The file is a Quarto partial: an explanatory comment block at the top, then
# entries newest-first, each shaped as
#   ::: {#now-YYYY-MM .mk-now-entry data-date="YYYY-MM"}
#   ...markdown...
#   :::
# It is spliced into index.qmd and now.qmd via {{< include >}}.

NOW_ENTRY_RE = re.compile(
    r'^::: \{#now-(\d{4}-\d{2}) \.mk-now-entry data-date="\1"\}\n'
    r'(.*?)\n:::\s*$',
    re.MULTILINE | re.DOTALL)


def read_now():
    """Returns (header_comment, [{"date": "YYYY-MM", "content": md}, ...])."""
    text = NOW_QMD.read_text(encoding="utf-8")
    first = text.find("::: {#now-")
    header = text[:first].rstrip("\n") if first > 0 else ""
    entries = [{"date": m.group(1), "content": m.group(2).strip()}
               for m in NOW_ENTRY_RE.finditer(text)]
    entries.sort(key=lambda e: e["date"], reverse=True)
    return header, entries


def write_now(header, entries):
    entries = sorted(entries, key=lambda e: e["date"], reverse=True)
    blocks = [
        f'::: {{#now-{e["date"]} .mk-now-entry data-date="{e["date"]}"}}\n\n'
        f'{e["content"].strip()}\n\n:::'
        for e in entries
    ]
    NOW_QMD.write_text(header + "\n\n" + "\n\n".join(blocks) + "\n",
                       encoding="utf-8")


def save_now_entry(date, content, orig_date=None):
    """Insert or update one entry; returns an error string or None."""
    if not re.fullmatch(r"\d{4}-\d{2}", date or ""):
        return "Date must be YYYY-MM."
    mm = int(date[5:7])
    if not 1 <= mm <= 12:
        return "Month must be 01-12."
    if not (content or "").strip():
        return "Entry is empty."
    header, entries = read_now()
    entries = [e for e in entries if e["date"] not in (orig_date, date)]
    entries.append({"date": date, "content": content})
    write_now(header, entries)
    return None


def validate(fields):
    probs = []
    if not squish(fields.get("title")):
        probs.append("Title is empty.")
    if not squish(fields.get("outlet")):
        probs.append("Outlet is empty.")
    if not (fields.get("link") or "").startswith(("http://", "https://")):
        probs.append("Link must start with http(s)://.")
    if fields.get("format") not in FORMATS:
        probs.append("Unknown format.")
    try:
        datetime.datetime.strptime(fields.get("date", ""), "%Y-%m-%d")
    except ValueError:
        probs.append("Date must be YYYY-MM-DD.")
    if norm_url(fields.get("link")) in existing_links():
        probs.append("This URL is already in mywork.csv.")
    return probs


def make_row(fields):
    return {
        "Date": fields["date"],
        "Original Title": squish(fields["title"]),
        "Outlet": squish(fields["outlet"]),
        "Format": fields["format"],
        "Link": fields["link"].strip(),
        "Highlight": "X" if fields.get("highlight") else "",
        "Author": squish(fields.get("author")) or "NA",
        "Excerpt": squish(fields.get("excerpt")) or "NA",
    }


def git_publish(message):
    """add/commit/pull --rebase/push; returns a combined log, never raises."""
    log = []
    for args in (["add", str(WORK_CSV), str(PENDING_CSV), str(SKIP_CSV),
                  str(NOW_QMD)],
                 ["commit", "-m", message],
                 ["pull", "--rebase", "origin", "main"],
                 ["push", "origin", "main"]):
        p = subprocess.run(["git", *args], cwd=REPO,
                           capture_output=True, text=True)
        out = (p.stdout + p.stderr).strip()
        log.append(f"$ git {' '.join(args[:2])}\n{out}" if out
                   else f"$ git {' '.join(args[:2])} (ok)")
        if p.returncode != 0:
            # "nothing to commit" is fine (e.g. a re-run); anything else stops
            # the sequence so pull/push don't pile more errors on top.
            if args[0] == "commit" and "nothing to commit" in out:
                continue
            log.append("!! git step failed — the row IS saved in the CSV; "
                       "fix the git issue and push manually.")
            break
    return "\n".join(log)


def archive_wayback(url):
    """Best effort, runs in a background thread."""
    try:
        req = urllib.request.Request(
            "https://web.archive.org/save/" + url, headers={"User-Agent": UA})
        urllib.request.urlopen(req, timeout=60)
        print(f"[wayback] archived {url}")
    except Exception as e:  # noqa: BLE001 - best effort by design
        print(f"[wayback] skipped {url}: {e}")


# ---------- metadata scraping -------------------------------------------------

class MetaParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.meta = {}
        self.title = ""
        self.time_datetime = ""
        self._in_title = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "meta":
            key = a.get("property") or a.get("name") or a.get("itemprop")
            if key and a.get("content") and key not in self.meta:
                self.meta[key.lower()] = a["content"].strip()
        elif tag == "title":
            self._in_title = True
        elif tag == "time" and not self.time_datetime and a.get("datetime"):
            self.time_datetime = a["datetime"]

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data


def fetch_metadata(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as resp:
        ctype = resp.headers.get("Content-Type", "")
        m = re.search(r"charset=([\w-]+)", ctype)
        charset = m.group(1) if m else "utf-8"
        html = resp.read().decode(charset, errors="replace")

    p = MetaParser()
    p.feed(html)
    meta = p.meta

    title = meta.get("og:title") or meta.get("twitter:title") or ""
    if not title and p.title:
        # strip trailing " - Site Name" style suffixes
        title = re.sub(r"\s*[-|–|—]\s*[^-|]{0,60}$", "", p.title)
    excerpt = (meta.get("og:description") or meta.get("description")
               or meta.get("twitter:description") or "")

    date_raw = (meta.get("article:published_time")
                or meta.get("parsely-pub-date") or meta.get("date")
                or meta.get("datepublished") or p.time_datetime or "")
    date = ""
    m = re.match(r"\d{4}-\d{2}-\d{2}", date_raw)
    if m:
        date = m.group(0)

    domain = re.sub(r"^www\.", "", re.sub(r"^https?://([^/]+).*", r"\1", url))
    outlet = OUTLET_MAP.get(domain) or meta.get("og:site_name") or \
        re.sub(r"\.(com|org|net|co)$", "", domain).title()

    return {
        "title": squish(title),
        "outlet": squish(outlet),
        "date": date or datetime.date.today().isoformat(),
        "excerpt": squish(excerpt),
        "duplicate": norm_url(url) in existing_links(),
    }


# ---------- web app -----------------------------------------------------------

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>mywork.csv</title>
<style>
  body { font: 15px -apple-system, sans-serif; max-width: 720px;
         margin: 0 auto; padding: 20px 14px 60px; color: #222; }
  h1 { font-size: 20px; }
  .tabs button { font-size: 15px; padding: 8px 18px; border: none;
                 background: #eee; cursor: pointer; border-radius: 6px 6px 0 0; }
  .tabs button.on { background: #2c5f8a; color: #fff; }
  .panel { border-top: 3px solid #2c5f8a; padding-top: 16px; }
  label { display: block; margin: 10px 0 3px; font-weight: 600; font-size: 13px; }
  input[type=text], input[type=date], select, textarea {
    width: 100%; padding: 7px; border: 1px solid #ccc; border-radius: 5px;
    font: inherit; box-sizing: border-box; }
  textarea { height: 70px; }
  .row { display: flex; gap: 12px; } .row > div { flex: 1; }
  button.act { margin-top: 14px; padding: 9px 20px; font: inherit;
               border: none; border-radius: 6px; cursor: pointer; }
  .primary { background: #2c5f8a; color: #fff; }
  .success { background: #2e7d32; color: #fff; }
  .danger  { background: #fff; color: #b3261e; border: 1px solid #b3261e !important; }
  .card { border: 1px solid #ddd; border-radius: 8px; padding: 14px 16px;
          margin-bottom: 16px; }
  .log { white-space: pre-wrap; font: 12px monospace; background: #f5f5f5;
         padding: 10px; border-radius: 6px; margin-top: 14px; }
  .warn { color: #b3261e; font-weight: 600; }
  .muted { color: #777; }
  a { color: #2c5f8a; }
</style></head><body>
<h1>mywork.csv</h1>
<div class="tabs">
  <button id="tab-add" class="on" onclick="show('add')">Add by URL</button>
  <button id="tab-queue" onclick="show('queue')">Review queue
    <span id="qcount"></span></button>
  <button id="tab-now" onclick="show('now')">Now page</button>
</div>

<div class="panel" id="panel-add">
  <label>URL</label>
  <div class="row">
    <div style="flex:4"><input type="text" id="url"
      placeholder="Paste a link, then Fetch"></div>
    <div><button class="act primary" style="margin-top:0;width:100%"
      onclick="doFetch()">Fetch</button></div>
  </div>
  <div id="form" style="display:none">
    <div class="row">
      <div><label>Date</label><input type="date" id="f_date"></div>
      <div><label>Format</label><select id="f_format"></select></div>
    </div>
    <label>Title</label><input type="text" id="f_title">
    <label>Outlet</label><input type="text" id="f_outlet">
    <label>Excerpt</label><textarea id="f_excerpt"></textarea>
    <div class="row">
      <div><label>Author (NA = you)</label>
        <input type="text" id="f_author" value="NA"></div>
      <div><label>&nbsp;</label>
        <label style="font-weight:400"><input type="checkbox" id="f_highlight">
        Highlight (show in Latest)</label></div>
    </div>
    <div id="dupwarn"></div>
    <button class="act success" onclick="doAdd()">Add to site</button>
  </div>
  <div id="addlog"></div>
</div>

<div class="panel" id="panel-queue" style="display:none">
  <div id="queue" class="muted">Loading…</div>
</div>

<div class="panel" id="panel-now" style="display:none">
  <p class="muted">Entries in <b>_now-entries.qmd</b> (one per month).
     Click a date to edit it, or start a new month.</p>
  <div id="nowlist"></div>
  <button class="act primary" onclick="newNow()">New entry</button>
  <div id="noweditor" style="display:none">
    <label>Month (YYYY-MM)</label>
    <input type="text" id="n_date" style="max-width:140px">
    <label>Entry (markdown: ### Working on, ### Reading, links, etc.)</label>
    <textarea id="n_content" style="height:260px; font-family: monospace;
      font-size: 13px;"></textarea>
    <button class="act success" onclick="saveNow()">Save &amp; publish</button>
  </div>
  <div id="nowlog"></div>
</div>

<script>
const FORMATS = %FORMATS%;
const sel = document.getElementById('f_format');
FORMATS.forEach(f => sel.add(new Option(f, f)));

function show(which) {
  for (const t of ['add', 'queue', 'now']) {
    document.getElementById('panel-' + t).style.display =
      t === which ? '' : 'none';
    document.getElementById('tab-' + t).classList.toggle('on', t === which);
  }
  if (which === 'queue') loadQueue();
  if (which === 'now') loadNow();
}

async function api(path, body) {
  const r = await fetch(path, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(body || {})});
  return r.json();
}

async function doFetch() {
  const url = document.getElementById('url').value.trim();
  if (!url) return;
  document.getElementById('addlog').innerHTML =
    '<div class="log">Fetching…</div>';
  const m = await api('/api/fetch', {url});
  document.getElementById('addlog').innerHTML = m.error
    ? '<div class="log warn">Could not fetch (' + m.error +
      '). Fill the fields by hand.</div>' : '';
  document.getElementById('form').style.display = '';
  document.getElementById('f_date').value = m.date ||
    new Date().toISOString().slice(0, 10);
  document.getElementById('f_title').value = m.title || '';
  document.getElementById('f_outlet').value = m.outlet || '';
  document.getElementById('f_excerpt').value = m.excerpt || '';
  document.getElementById('dupwarn').innerHTML = m.duplicate
    ? '<p class="warn">Already in mywork.csv — adding would duplicate it.</p>' : '';
}

function fields(prefix) {
  const g = id => document.getElementById(prefix + id);
  return { date: g('date').value, title: g('title').value,
           outlet: g('outlet').value, format: g('format').value,
           excerpt: g('excerpt').value, author: g('author').value,
           highlight: g('highlight').checked };
}

async function doAdd() {
  const body = fields('f_');
  body.link = document.getElementById('url').value.trim();
  const r = await api('/api/add', body);
  document.getElementById('addlog').innerHTML =
    '<div class="log' + (r.ok ? '' : ' warn') + '">' + r.message + '</div>';
  if (r.ok) {
    document.getElementById('form').style.display = 'none';
    document.getElementById('url').value = '';
  }
}

function esc(s) {
  return (s || '').replace(/[&<>"]/g,
    c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
}

async function loadQueue() {
  const r = await api('/api/state');
  const q = r.pending;
  document.getElementById('qcount').textContent =
    q.length ? '(' + q.length + ')' : '';
  const el = document.getElementById('queue');
  if (!q.length) {
    el.innerHTML = 'Queue is empty. The weekly discovery task adds ' +
                   'candidates to data/pending.csv.';
    return;
  }
  el.innerHTML = q.map((row, i) => {
    const opts = FORMATS.map(f =>
      `<option ${f === row.Format ? 'selected' : ''}>${f}</option>`).join('');
    return `<div class="card">
      <a href="${esc(row.Link)}" target="_blank"><b>${esc(
        row['Original Title'])}</b></a>
      <div class="row">
        <div><label>Date</label><input type="date" id="q${i}_date"
          value="${esc(row.Date)}"></div>
        <div><label>Format</label><select id="q${i}_format">${opts}</select></div>
      </div>
      <label>Title</label><input type="text" id="q${i}_title"
        value="${esc(row['Original Title'])}">
      <label>Outlet</label><input type="text" id="q${i}_outlet"
        value="${esc(row.Outlet)}">
      <label>Excerpt</label><textarea id="q${i}_excerpt">${esc(
        row.Excerpt === 'NA' ? '' : row.Excerpt)}</textarea>
      <div class="row">
        <div><label>Author (NA = you)</label><input type="text"
          id="q${i}_author" value="${esc(row.Author || 'NA')}"></div>
        <div><label>&nbsp;</label><label style="font-weight:400">
          <input type="checkbox" id="q${i}_highlight"> Highlight</label></div>
      </div>
      <button class="act success"
        onclick="approve(${i}, '${encodeURIComponent(row.Link)}')">
        Approve &amp; publish</button>
      <button class="act danger"
        onclick="reject('${encodeURIComponent(row.Link)}')">Reject</button>
      <div id="q${i}_log"></div>
    </div>`;
  }).join('');
}

async function approve(i, encLink) {
  const body = fields('q' + i + '_');
  body.link = decodeURIComponent(encLink);
  const r = await api('/api/approve', body);
  if (r.ok) loadQueue();
  else document.getElementById('q' + i + '_log').innerHTML =
    '<div class="log warn">' + r.message + '</div>';
}

async function reject(encLink) {
  await api('/api/reject', {link: decodeURIComponent(encLink)});
  loadQueue();
}

// ---- Now page tab ----

let nowEntries = [], nowOrig = null;

async function loadNow() {
  const r = await api('/api/now/state');
  nowEntries = r.entries;
  document.getElementById('nowlist').innerHTML = nowEntries.map((e, i) =>
    `<button class="act" style="margin:0 8px 8px 0; background:#eee"
       onclick="editNow(${i})">${esc(e.date)}</button>`).join('');
}

function editNow(i) {
  nowOrig = nowEntries[i].date;
  document.getElementById('n_date').value = nowEntries[i].date;
  document.getElementById('n_content').value = nowEntries[i].content;
  document.getElementById('noweditor').style.display = '';
  document.getElementById('nowlog').innerHTML = '';
}

function newNow() {
  nowOrig = null;
  document.getElementById('n_date').value =
    new Date().toISOString().slice(0, 7);
  document.getElementById('n_content').value =
    '### Working on\n\n\n\n### Reading\n\n';
  document.getElementById('noweditor').style.display = '';
  document.getElementById('nowlog').innerHTML = '';
}

async function saveNow() {
  const r = await api('/api/now/save', {
    date: document.getElementById('n_date').value.trim(),
    content: document.getElementById('n_content').value,
    orig_date: nowOrig });
  document.getElementById('nowlog').innerHTML =
    '<div class="log' + (r.ok ? '' : ' warn') + '">' + r.message + '</div>';
  if (r.ok) { document.getElementById('noweditor').style.display = 'none'; loadNow(); }
}

loadQueue();
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # keep the terminal quiet

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = PAGE.replace("%FORMATS%", json.dumps(FORMATS)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(n) or b"{}")
        except json.JSONDecodeError:
            return self._json({"ok": False, "message": "bad request"}, 400)
        try:
            return self._route(data)
        except Exception as e:  # noqa: BLE001 - always answer with JSON
            return self._json({"ok": False,
                               "message": f"App error: {e!r}"}, 500)

    def _route(self, data):

        if self.path == "/api/state":
            return self._json({"pending": read_rows(PENDING_CSV)})

        if self.path == "/api/now/state":
            _, entries = read_now()
            return self._json({"entries": entries})

        if self.path == "/api/now/save":
            err = save_now_entry(data.get("date"), data.get("content"),
                                 data.get("orig_date"))
            if err:
                return self._json({"ok": False, "message": err})
            log = git_publish(f"Now update: {data['date']}")
            return self._json({"ok": True, "message":
                               "Saved and pushed. Site rebuilds in ~2 min.\n"
                               + log})

        if self.path == "/api/fetch":
            try:
                return self._json(fetch_metadata(data["url"].strip()))
            except Exception as e:  # noqa: BLE001 - surface any fetch failure
                return self._json({"error": str(e), "date": "", "title": "",
                                   "outlet": "", "excerpt": "",
                                   "duplicate": False})

        if self.path in ("/api/add", "/api/approve"):
            probs = validate(data)
            if probs:
                return self._json({"ok": False, "message": " ".join(probs)})
            row = make_row(data)
            append_work_row(row)
            if self.path == "/api/approve":
                keep = [r for r in read_rows(PENDING_CSV)
                        if norm_url(r["Link"]) != norm_url(data["link"])]
                write_pending(keep)
            threading.Thread(target=archive_wayback,
                             args=(row["Link"],), daemon=True).start()
            log = git_publish(f"Add: {row['Original Title']}")
            return self._json({"ok": True, "message":
                               "Added and pushed. Site rebuilds in ~2 min.\n"
                               + log})

        if self.path == "/api/reject":
            link = data["link"]
            append_skiplist(link)
            keep = [r for r in read_rows(PENDING_CSV)
                    if norm_url(r["Link"]) != norm_url(link)]
            write_pending(keep)
            git_publish("Reject discovery candidate")
            return self._json({"ok": True})

        self.send_error(404)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://localhost:{PORT}"
    print(f"mywork.csv app running at {url}  (Ctrl-C to stop)")
    threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        sys.exit(0)


if __name__ == "__main__":
    main()
