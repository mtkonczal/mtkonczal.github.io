# Portfolio & Latest Things — data setup

How the two list sections on the redesigned page are structured, so you can
recreate them in your own (Quarto) site. The core idea: **everything is one
flat list of entry records with the same shape**, and the UI (tabs, search,
"latest" shortlist) is just different *views* of that data. Author once, render
many ways.

---

## 1. The entry record

Every item — whether it shows up in Latest Things or in a Portfolio tab — is the
same kind of object with five fields:

| Field    | Type   | What it is                                              | Example                                            |
|----------|--------|---------------------------------------------------------|----------------------------------------------------|
| `date`   | string | Human-readable date. Free text, not parsed.             | `"Jun 10, 2026"`, `"Oct 2025"`, `"2021"`           |
| `title`  | string | The thing's title (or a pull-quote for a press hit).    | `"The Affordability Framework"`                    |
| `outlet` | string | Publisher / venue. Append collaborators after a `·`.    | `"W.W. Norton · with Joseph Stiglitz"`             |
| `kind`   | string | Short label that becomes the badge.                     | `"Report"`, `"Quote"`, `"Podcast"`, `"Book Review"`|
| `url`    | string | Where it links. Use `#book` for an on-page anchor.      | `"https://economicsecurityproject.org/..."`        |

That's the whole contract. Both sections render this record as a row:

```
date            title                              kind-badge
                outlet
```

Keeping `date` as plain text (not a real date) is deliberate — it lets you write
`"2021"`, `"Oct 2025"`, or `"Jun 10, 2026"` interchangeably without a date
parser. The list shows in the order you author it; newest first.

---

## 2. Portfolio = one object keyed by category

The Portfolio is a single object whose keys are the four tab names. Each value is
an array of entry records:

```js
const portfolio = {
  Writing:  [ /* entry, entry, … */ ],
  Research: [ /* … */ ],
  Media:    [ /* … */ ],
  Press:    [ /* … */ ],
};
```

The tab bar is generated from a fixed list of category names plus a `counts`
map. **The badge count is independent of how many entries you've actually
authored** — that's why the tab can say "Press 339" while you only list five
representative hits. Counts are editorial; the rows are a curated sample.

```js
const counts = { Writing: 65, Research: 25, Media: 61, Press: 339 };
const categories = ["Writing", "Research", "Media", "Press"];
```

### Tab switching, search, and the count line

Three pieces of state drive the view:

- `tab` — which category is active (default `"Research"`).
- `q` — the search box text. Cleared whenever you switch tabs.

The visible rows are computed each render:

```js
let items = portfolio[tab];
const query = q.toLowerCase().trim();
if (query) {
  items = items.filter(it =>
    (it.title + " " + it.outlet + " " + it.kind)
      .toLowerCase()
      .includes(query)
  );
}
// "SHOWING {items.length} OF {counts[tab]} IN {tab}"
```

So search filters **within the active tab only**, matching against title +
outlet + kind. The little status line reads `SHOWING 4 OF 25 IN RESEARCH`.

---

## 3. Latest Things = a separate hand-picked shortlist

Latest Things is **not** computed from the portfolio — it's its own small array
(≈6 entries) you curate by hand. Same record shape, so the same row component
renders it. The only visual difference: Latest rows show the `kind` as a filled
accent badge (it's a highlight reel), while Portfolio rows show `kind` as quiet
muted text (it's a dense index).

```js
const latest = [
  { date: "Jun 10, 2026", title: "Building Affordability: …",
    outlet: "Economic Security Project", kind: "Research",
    url: "https://economicsecurityproject.org/resource/building-affordability/" },
  // … 5 more, newest first
];
```

Rule of thumb: an item can live in *both* — it appears in Latest because it's
recent, and in a Portfolio tab because it belongs to the permanent record. You
duplicate the record in both lists; they're independent.

---

## 4. Porting this into Quarto

Quarto doesn't run the React state above, but the data model maps cleanly onto
static approaches. Two good options:

### Option A — a YAML/JSON data file + a listing

Put each category in its own folder of posts (or one `.yml` file) using the same
five fields, then use a [Quarto listing](https://quarto.org/docs/websites/website-listings.html):

```yaml
# _listings or a custom .yml
- date: "Jun 10, 2026"
  title: "Building Affordability: The Policy Agenda for America's Housing Crisis"
  outlet: "Economic Security Project"
  kind: "Research"
  url: "https://economicsecurityproject.org/resource/building-affordability/"
```

Quarto listings give you category filtering and a built-in search field for
free, which covers the tabs + search behavior. Set `categories` from the `kind`
field and you get the tab-style filtering without writing JS.

### Option B — keep it as one JS array + light rendering

If you'd rather keep full control of the look, drop a single `entries.js` (the
arrays above) into the page and render rows with a small script. The tab counts,
the "showing X of N" line, and the within-tab search are ~30 lines of vanilla JS
— no framework needed.

### Field-mapping cheat sheet

| This setup | Quarto listing equivalent |
|------------|---------------------------|
| `kind`     | `categories: [Research]`  |
| `date`     | `date:` (use a real date if you want Quarto to sort) |
| `outlet`   | a custom field, shown via `fields:` / a template |
| `url`      | `path:` (external link)   |
| `title`    | `title:`                  |

One gotcha: if you hand `date` to Quarto for sorting, switch to a real date
format (`2026-06-10`) instead of the free-text strings used here, and format the
display in the listing template.

---

## 5. Visual spec (exact values)

This is the part that makes it *look* like what you saw. All values are the real
ones from the page. Colors are referenced as CSS variables — the actual hex per
theme is in the token table at the bottom. The default ("editorial") theme is
what the screenshots show.

### Shared layout

- **Page container:** `max-width: 1120px; margin: 0 auto; padding: 84px 44px;`
  for each section. Sections are separated by `border-top: 1px solid var(--line)`.
- Every other section gets `background: var(--surface)` to create the
  alternating banding (Portfolio and Now are surface; Hero, Latest, Book are bg).

### Section header (used by both)

```
eyebrow label   →  font: var(--font-mono); 12px; letter-spacing: 0.18em;
                   text-transform: uppercase; color: var(--accent);
                   margin-bottom: 14px;
                   text reads "01 — LATEST THINGS", "02 — PORTFOLIO", etc.

heading (h2)    →  font: var(--font-display); font-weight: var(--display-weight);
                   font-size: 48px; line-height: 1.05; letter-spacing: -0.015em;
                   margin: 0 0 12px;

intro paragraph →  font: var(--font-body); font-size: 17px; line-height: 1.6;
                   color: var(--muted); max-width: 60ch; margin: 0 0 36px;
```

### The list row — the heart of it

Both Latest and Portfolio rows are a **3-column CSS grid**. The negative margin +
matching padding is the trick that lets the hover background bleed slightly wider
than the text, so it feels like a target without shifting the layout.

```css
/* row container (an <a>) */
display: grid;
grid-template-columns: 130px 1fr auto;   /* Latest; Portfolio uses 110px */
gap: 28px;
align-items: baseline;
padding: 22px 16px;                       /* Portfolio uses 20px 16px */
margin: 0 -16px;                          /* cancels the 16px side padding */
border-radius: 4px;
border-bottom: 1px solid var(--line);
transition: background .18s;

/* hover */
background: var(--accent-soft);           /* soft tint of the accent */
```

Column contents:

```
col 1  date    →  font: var(--font-mono); font-size: 12.5px;
                  color: var(--muted); letter-spacing: 0.02em;

col 2  title   →  font: var(--font-display);
                  font-weight: var(--display-weight);
                  font-size: 23px;        /* Portfolio: 22px */
                  line-height: 1.25; display: block;
       outlet  →  (second line) font-size: 14px; color: var(--muted);

col 3  kind    →  see badge styles below
```

### The `kind` badge — the one place Latest and Portfolio differ

**Latest** shows it as a filled pill (highlight reel):

```css
font: var(--font-mono); font-size: 10.5px; letter-spacing: 0.07em;
text-transform: uppercase;
background: var(--accent-soft); color: var(--accent);
padding: 5px 11px; border-radius: 999px; white-space: nowrap;
```

**Portfolio** shows it as quiet text (dense index — no pill):

```css
font: var(--font-mono); font-size: 10.5px; letter-spacing: 0.07em;
text-transform: uppercase; color: var(--muted); white-space: nowrap;
```

### Portfolio tabs

```css
/* tab button, idle */
padding: 12px 2px; margin-right: 30px;
background: none; border: none;
border-bottom: 2px solid transparent;
cursor: pointer;
font: var(--font-mono); font-size: 12.5px; letter-spacing: 0.05em;
color: var(--muted);
display: inline-flex; align-items: baseline; gap: 7px;
transition: color .2s;

/* tab button, active */
color: var(--ink);
border-bottom: 2px solid var(--accent);

/* the count next to the label (e.g. "65") */
font-size: 11px; color: var(--accent);
```

The whole tab bar sits on a `border-bottom: 1px solid var(--line)` so the active
tab's 2px accent underline overlaps it.

### Search box

```css
/* pill container */
display: flex; align-items: center; gap: 8px;
border: 1px solid var(--line); border-radius: 999px;
padding: 7px 16px; background: var(--bg);
/* a "⌕" glyph at 13px var(--muted) sits before the input */

/* the input itself */
border: none; outline: none; background: transparent;
color: var(--ink); font-size: 13px; width: 170px;
```

### The "showing X of N" status line

```css
font: var(--font-mono); font-size: 11px; color: var(--muted);
padding: 14px 2px;
/* text: "SHOWING 4 OF 25 IN RESEARCH" — all uppercase */
```

### Design tokens — the three themes

Every color/font above is a variable. Swap this block to reskin the whole thing.
"editorial" is the default shown in the mockup.

| Token               | editorial (default)                | minimal                       | bold (dark)                  |
|---------------------|------------------------------------|-------------------------------|------------------------------|
| `--bg`              | `#f6f2e9`                          | `#ffffff`                     | `#0d0e11`                    |
| `--surface`         | `#fffdf7`                          | `#f7f7f8`                     | `#16181d`                    |
| `--ink`             | `#1d1a15`                          | `#15161a`                     | `#f1efe9`                    |
| `--muted`           | `#73695a`                          | `#83868f`                     | `#9b9aa3`                    |
| `--accent`          | `#9d3a1a`                          | `#2b44ff`                     | `#c6f24e`                    |
| `--accent-soft`     | `#ece0cd`                          | `#e9ecff`                     | `#22271a`                    |
| `--line`            | `#ddd4c2`                          | `#ececef`                     | `#262a32`                    |
| `--display-weight`  | `400`                              | `600`                         | `800`                        |
| `--font-display`    | `'Instrument Serif', Georgia, serif` | `'Space Grotesk', sans-serif` | `'Archivo', sans-serif`    |
| `--font-body`       | `'Newsreader', Georgia, serif`     | `'Hanken Grotesk', sans-serif`| `'Hanken Grotesk', sans-serif`|
| `--font-mono`       | `'JetBrains Mono', monospace`      | `'JetBrains Mono', monospace` | `'JetBrains Mono', monospace`|

Fonts are loaded from Google Fonts. The weights used: Instrument Serif 400,
Newsreader 400–600, Space Grotesk 400–700, Hanken Grotesk 400–700, Archivo
500–800, JetBrains Mono 400–600.

> Note: `--display-weight` exists because the three display fonts need different
> weights to feel right at large sizes (Instrument Serif at 400, Archivo at 800).
> If you only ship one theme, you can hard-code the weight and drop the variable.

---

## TL;DR

1. One record shape: `{ date, title, outlet, kind, url }`.
2. Portfolio = object keyed by category → arrays of those records; tabs + search
   are views over it; badge counts are a separate hand-set map.
3. Latest Things = a small hand-curated array of the same records, newest first.
4. In Quarto: model it as a listing (categories from `kind`, search built in) or
   a tiny JS array if you want the exact look.
