# Consider It Done — consideritdone.help

Static site (no build step, no dependencies). Deployed via GitHub Pages from
this repo; `CNAME` points at `www.consideritdone.help`.

```
index.html          home page
work/*.html          generated gallery pages — do not hand-edit
style.css            single stylesheet
script.js            shared by every page (null-guarded throughout)
assets/              logos, favicons, background, work photos
tools/               local helper scripts (macOS)
```

## Brand

Sampled from `assets/CID_Logo_FullColor_Transparent.svg` — the official
vector logo:

| Token | Value | Use |
|---|---|---|
| `--accent` | `#5B722E` | olive green — 5.40:1 on white |
| `--accent-deep` | `#4A5E25` | hover (**darker**, not lighter) |
| `--accent-on-dark` | `#A8C46B` | **hero only** — the dark scrim |
| `--cream` | `#C8B281` | brand tan |
| `--ink` | `#13161B` | body text |

Two things that are easy to get wrong:

- **Buttons use white text.** Black on `#5B722E` is 3.50:1 and fails WCAG AA.
- **Hover goes darker, not lighter.** A lighter olive drops to 3.35:1 on white.
  This inverts the usual dark-theme instinct.

The accent is single-source: `--accent-rgb` supplies every alpha variant via
`rgba(var(--accent-rgb), …)`, so changing the green is a one-line edit.

## The logo lockup

The only full lockups shipped by the brand are PNGs with a **solid black
background baked in** (no alpha) — unusable on a light page. The transparent
SVGs are **icon-only**, with no wordmark.

So the lockup is assembled in HTML: the icon SVG plus live text in Oswald
(`.brand`). It is sharper, lighter, recolorable per context, and readable to
screen readers. `CID_Logo_FullColor_OnDark.svg` is the same icon with its
near-black shapes switched to white, for the dark hero.

## One-time setup: the background photo

The site background and the social share image come from **"New Site
Background"** in Google Drive (`06 - Assets, Marketing, and Brand`). It is a
3 MB PNG — far too heavy to ship, and the wrong container for a photograph.

```bash
./tools/make-background.sh "/path/to/New Site Background.png"
```

Produces `assets/bg-kitchen.jpg` and `assets/og-share.jpg`.

Until you run it, the site falls back to an on-brand gradient — it looks
intentional, not broken, so this is not urgent, but shares will not have an
image until `og-share.jpg` exists.

> The CSS references a **single `.jpg` on purpose.** `image-set()` selects by
> format *support*, not availability — Chromium would choose a `.webp` and
> render nothing at all if that file were missing, silently blanking the
> entire background.

## Adding work photos

Photos live in Google Drive under
`06 - Assets, Marketing, and Brand/Photography (Before & After)/`,
organised as `Before|After / Client / Job Type`.

```bash
./tools/import-photos.sh           # Drive -> assets/work/<category>/
python3 tools/curate-photos.py     # apply tools/photo-index.tsv
python3 tools/build-galleries.py   # regenerate work/*.html
```

**Three steps, in that order.** Import is mechanical — it copies whatever is
in the mapped Drive folders. Curate is editorial — it decides what actually
ships, which category it lands in, and what the caption says.

Categories: `lawn-landscaping` `remodeling` `decks-stonework` `hauling`

### import-photos.sh

Holds an explicit **allowlist** mapping Drive job folders to categories.
Anything not listed is ignored — including every `DON'T USE` folder, which is
never named and so cannot be published by accident. New job = one line in
`MAPPINGS`.

Folders resolve with `find -path`, not shell globbing: nearly every folder
name contains a space, and an unquoted glob would split `Gwen Sorbel` into two
words and match nothing. One folder is named `Sink/Tub Drain`, whose slash
cannot survive to the local disk — that entry uses a `Sink*Drain` wildcard.

> **Rotation.** Phones record "which way was up" in the EXIF Orientation tag
> rather than rotating the pixels. `sips` does not always apply it and
> `exiftool -all=` then deletes the tag, so photos publish on their side —
> this silently affected 20 of the first 55 imported. The scripts now read the
> tag off the *converted* file and rotate the pixels before stripping. If sips
> already baked it in the tag reads 1 and nothing happens, so it cannot
> double-rotate.

### curate-photos.py + photo-index.tsv

`photo-index.tsv` is the editorial layer, written after actually looking at
every photo. Each row is `source`, `action` (keep/cover/drop), `category`,
`new_name`, and a note explaining the call.

- Filenames become captions, with any trailing index stripped:
  `landscaping-03.jpg` → "Landscaping".
- `cover` marks the category tile on the home page.
- `drop` moves a photo to `assets/work/_unused/` — **nothing is ever deleted**.
- A photo can be re-categorised here without touching the Drive mapping.

Re-running import then curate always lands in the same place, so the editorial
decisions survive a re-import.

> **Why the metadata stripping matters.** iPhone photos embed GPS coordinates,
> and these are photos of *customers' homes*. Publishing them unstripped would
> put the precise street location of clients' properties on a public website.
> Both import scripts refuse to run without `exiftool`
> (`brew install exiftool`) and verify each file afterwards, discarding any
> that still carries GPS.

A category with no photos renders an honest "Photos coming soon" panel with a
call button rather than an empty page.

## Editing

- **Gallery pages are generated.** Edit `tools/build-galleries.py`, not
  `work/*.html`.
- Service categories are defined in four places that must agree: the cards
  and work tiles in `index.html`, `CATEGORIES` in `build-galleries.py`,
  `MAPPINGS` in `import-photos.sh`, and the `category` column in
  `photo-index.tsv`. The contact form's `<select>` should cover them too, or
  leads arrive tagged with services that no longer exist.
- `script.js` is shared by every page, so **every element lookup is
  null-guarded**. Keep it that way — an unguarded `getElementById` throws on
  pages lacking that element and kills all JS on them.

## Galleries

Horizontal scroll-snap, working with **zero JavaScript**. JS only adds arrows,
a drag-to-pan affordance, and disabled states.

The mouse wheel is deliberately **not** remapped to horizontal scrolling — it
traps people trying to scroll past the section. Arrows plus native snap give
the same feel without stealing the page scroll.

During a drag, `scroll-behavior` is switched to `auto`; leaving it `smooth`
makes each `scrollLeft` assignment animate and interrupt the previous one, so
the track barely moves.

## Known gaps

- `GA_MEASUREMENT_ID` in `index.html` is still a placeholder — analytics are
  not recording.
- Gallery pages are not in a sitemap; there is no `sitemap.xml` or `robots.txt`.
