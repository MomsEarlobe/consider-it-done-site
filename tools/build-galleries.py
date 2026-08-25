#!/usr/bin/env python3
"""
Regenerate the work/*.html gallery pages.

Each category page is static HTML (deep-linkable, crawlable, works
without JS). This script just keeps the seven pages consistent and
picks up whatever photos currently sit in assets/work/<slug>/.

Usage:
    python3 tools/build-galleries.py

Photos: drop web-ready .jpg/.webp files into assets/work/<slug>/.
Name a file cover.jpg to use it as the tile image on the homepage
"Our Work" band; it is excluded from the gallery strip itself.
Captions come from the filename: "front-steps-rebuild.jpg" ->
"Front steps rebuild".
"""

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK_DIR = ROOT / "work"
ASSETS = ROOT / "assets" / "work"

PHONE_DISPLAY = "(605) 368-1606"
PHONE_HREF = "6053681606"

CATEGORIES = [
    ("lawn-landscaping", "01", "Lawn, Landscaping &amp; Tree Care",
     "Landscaping, lawn care, tree and branch cutting, and seasonal outdoor work "
     "that keeps a property looking after itself."),
    ("remodeling",       "02", "Interior Repairs &amp; Remodeling",
     "Kitchen and bathroom remodels, flooring, plumbing and door repair — the "
     "inside work that makes a house feel new again."),
    ("decks-stonework",  "03", "Decks, Steps &amp; Stonework",
     "Deck and stair building, brick laying and re-laying, and exterior steps built "
     "to last through a South Dakota winter."),
    ("hauling",          "04", "Hauling &amp; Cleanouts",
     "Junk removal, dump runs, estate cleanouts, debris hauling, and full property "
     "cleanouts."),
]

IMAGE_EXTS = {".jpg", ".jpeg", ".webp", ".png"}


def caption_from(stem: str) -> str:
    stem = re.sub(r"[-_]\d+$", "", stem)      # "landscaping-03" -> "landscaping"
    text = re.sub(r"[-_]+", " ", stem).strip()
    text = re.sub(r"\s+", " ", text)
    return html.escape(text[:1].upper() + text[1:]) if text else "Completed work"


def photos_for(slug: str):
    folder = ASSETS / slug
    if not folder.is_dir():
        return []
    files = [
        p for p in sorted(folder.iterdir())
        if p.suffix.lower() in IMAGE_EXTS and p.stem.lower() != "cover"
    ]
    # Prefer .webp when a matching .jpg exists, so we never list both
    by_stem = {}
    for p in files:
        by_stem.setdefault(p.stem, []).append(p)
    chosen = []
    for stem, variants in by_stem.items():
        webp = next((v for v in variants if v.suffix.lower() == ".webp"), None)
        chosen.append(webp or variants[0])
    return sorted(chosen, key=lambda p: p.name)


def render(slug, num, title, blurb, photos, prev_cat, next_cat):
    plain_title = html.unescape(title)

    if photos:
        items = "\n".join(
            f"""          <figure class="gallery-item">
            <img src="../assets/work/{slug}/{p.name}" alt="{caption_from(p.stem)} — Consider It Done, Sioux Falls"
                 loading="lazy" decoding="async" width="1600" height="1200" />
            <figcaption>{caption_from(p.stem)}</figcaption>
          </figure>"""
            for p in photos
        )
        gallery = f"""      <div class="gallery-wrap">
        <button class="scroll-btn scroll-prev" type="button" aria-label="Previous photo" hidden>
          <span aria-hidden="true">←</span>
        </button>

        <div class="gallery-track" id="gallery-track" tabindex="0" role="region"
             aria-label="{plain_title} photo gallery, horizontally scrollable">
{items}
        </div>

        <button class="scroll-btn scroll-next" type="button" aria-label="Next photo" hidden>
          <span aria-hidden="true">→</span>
        </button>
      </div>"""
    else:
        gallery = f"""      <div class="container">
        <div class="gallery-empty">
          <h2>Photos coming soon</h2>
          <p>We're still sorting through job photos for this category. In the meantime,
             give us a call and we'll walk you through recent work like it.</p>
          <a href="tel:{PHONE_HREF}" class="btn btn-accent">Call or Text {PHONE_DISPLAY}</a>
        </div>
      </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />

  <link rel="icon" type="image/svg+xml" href="../assets/favicon-green.svg" />
  <link rel="icon" type="image/png" sizes="32x32" href="../assets/favicon-32.png" />
  <link rel="icon" type="image/png" sizes="16x16" href="../assets/favicon-16.png" />
  <link rel="apple-touch-icon" sizes="180x180" href="../assets/apple-touch-icon.png" />

  <title>{plain_title} | Consider It Done — Sioux Falls</title>
  <meta name="description" content="{html.escape(html.unescape(blurb))} Photos of real jobs by Consider It Done in Sioux Falls, SD." />
  <meta name="robots" content="index, follow" />
  <link rel="canonical" href="https://consideritdone.help/work/{slug}.html" />

  <meta property="og:title" content="{plain_title} — Consider It Done" />
  <meta property="og:description" content="{html.escape(html.unescape(blurb))}" />
  <meta property="og:image" content="https://consideritdone.help/assets/og-share.jpg" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://consideritdone.help/work/{slug}.html" />

  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;600;700&family=Barlow+Condensed:wght@400;500;600&display=swap" rel="stylesheet" />

  <link rel="stylesheet" href="../style.css" />
</head>
<body>

  <a href="#main-content" class="skip-link">Skip to main content</a>

  <header class="site-header" id="site-header" role="banner">
    <div class="header-inner container">
      <a href="../index.html" class="logo-link brand" aria-label="Consider It Done — Home">
        <img src="../assets/CID_Logo_FullColor_Transparent.svg" alt="" aria-hidden="true" class="brand-icon" width="46" height="46" />
        <span class="brand-text">
          <span class="brand-name">Consider <span class="brand-it">It</span> Done</span>
          <span class="brand-tagline">Solutions for your Home and Business</span>
        </span>
      </a>

      <nav class="desktop-nav" aria-label="Primary navigation">
        <a href="../index.html#services" class="nav-link">Services</a>
        <a href="../index.html#work" class="nav-link">Our Work</a>
        <a href="../index.html#why-us" class="nav-link">About</a>
        <a href="../index.html#contact" class="nav-link">Contact</a>
      </nav>

      <a href="../index.html#contact" class="btn btn-accent btn-cta-header">Get a Free Estimate</a>

      <button class="hamburger" id="hamburger-btn" aria-label="Open navigation menu" aria-expanded="false" aria-controls="mobile-nav">
        <span class="ham-bar"></span>
        <span class="ham-bar"></span>
        <span class="ham-bar"></span>
      </button>
    </div>

    <nav class="mobile-nav" id="mobile-nav" aria-label="Mobile navigation" aria-hidden="true">
      <a href="../index.html#services" class="mobile-nav-link">Services</a>
      <a href="../index.html#work" class="mobile-nav-link">Our Work</a>
      <a href="../index.html#why-us" class="mobile-nav-link">About</a>
      <a href="../index.html#contact" class="mobile-nav-link">Contact</a>
      <a href="../index.html#contact" class="btn btn-accent mobile-nav-cta">Get a Free Estimate</a>
    </nav>
  </header>

  <main id="main-content">

    <section class="gallery-hero">
      <div class="container">
        <a href="../index.html#work" class="gallery-back"><span aria-hidden="true">←</span> All work</a>
        <div class="section-label">{num} — OUR WORK</div>
        <h1 class="section-headline">{title}</h1>
        <p class="gallery-intro">{blurb}</p>
      </div>
    </section>

{gallery}

    <section class="gallery-cta">
      <div class="container">
        <div class="section-divider" aria-hidden="true">
          <div class="divider-line"></div>
          <div class="divider-diamond">◆</div>
          <div class="divider-line"></div>
        </div>
        <p style="margin-top:40px">Want something like this done at your property?</p>
        <a href="../index.html#contact" class="btn btn-accent btn-lg">Get Your Free Estimate</a>
      </div>
    </section>

    <section class="gallery-cta" style="padding-top:0">
      <div class="container" style="display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap">
        <a href="{prev_cat}.html" class="gallery-back"><span aria-hidden="true">←</span> {html.unescape(CAT_TITLES[prev_cat])}</a>
        <a href="{next_cat}.html" class="gallery-back">{html.unescape(CAT_TITLES[next_cat])} <span aria-hidden="true">→</span></a>
      </div>
    </section>

  </main>

  <footer class="site-footer" role="contentinfo">
    <div class="footer-inner container">
      <div class="footer-logo-col">
        <a href="../index.html" class="brand brand--footer" aria-label="Consider It Done — Home">
          <img src="../assets/CID_Logo_FullColor_Transparent.svg" alt="" aria-hidden="true" class="brand-icon" width="40" height="40" />
          <span class="brand-text">
            <span class="brand-name">Consider <span class="brand-it">It</span> Done</span>
          </span>
        </a>
      </div>
      <div class="footer-center-col">
        <p class="footer-serving">Serving Sioux Falls, SD and surrounding areas</p>
      </div>
      <div class="footer-contact-col">
        <a href="tel:{PHONE_HREF}" class="footer-contact-link">{PHONE_DISPLAY}</a>
        <a href="mailto:hello@consideritdone.help" class="footer-contact-link">hello@consideritdone.help</a>
      </div>
    </div>
    <div class="footer-bottom">
      <div class="container">
        <p>© 2025 Consider It Done LLC · All Rights Reserved</p>
      </div>
    </div>
  </footer>

  <script src="../script.js"></script>
</body>
</html>
"""


CAT_TITLES = {slug: title for slug, _, title, _ in CATEGORIES}


def main():
    WORK_DIR.mkdir(exist_ok=True)
    total_photos = 0

    for i, (slug, num, title, blurb) in enumerate(CATEGORIES):
        prev_cat = CATEGORIES[(i - 1) % len(CATEGORIES)][0]
        next_cat = CATEGORIES[(i + 1) % len(CATEGORIES)][0]
        photos = photos_for(slug)
        total_photos += len(photos)

        (WORK_DIR / f"{slug}.html").write_text(
            render(slug, num, title, blurb, photos, prev_cat, next_cat),
            encoding="utf-8",
        )
        state = f"{len(photos)} photo(s)" if photos else "empty state"
        print(f"  work/{slug}.html  ({state})")

    print(f"\nBuilt {len(CATEGORIES)} pages, {total_photos} photos total.")
    if total_photos == 0:
        print("No photos found yet — run tools/import-photos.sh first,")
        print("then re-run this script to populate the galleries.")


if __name__ == "__main__":
    main()
