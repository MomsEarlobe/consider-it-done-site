/* =============================================================
   CONSIDER IT DONE — script.js

   Shared by index.html and every work/*.html gallery page, so
   every lookup below is null-guarded: a missing element must
   never throw and take the rest of the page's JS down with it.
   ============================================================= */

'use strict';

// ── Add js-loaded so CSS animations activate safely ──────────
// This MUST be first — it gates the opacity:0 animation styles.
document.body.classList.add('js-loaded');

const prefersReducedMotion =
  window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;


// ── Add data-animate attributes to key elements ──────────────
function stagger(selector, cycle) {
  document.querySelectorAll(selector).forEach((el, i) => {
    el.setAttribute('data-animate', '');
    el.setAttribute('data-animate-delay', String(cycle ? (i % cycle) + 1 : i + 1));
  });
}

stagger('.service-card', 3);
stagger('.why-item', 2);
stagger('.contact-info-item');
stagger('.gallery-item', 3);

['.section-headline', '.section-label', '.pm-body', '.pm-signature', '.contact-sub',
 '.contact-form-wrap', '.contact-guarantee', '.odd-jobs'].forEach(sel => {
  document.querySelectorAll(sel).forEach(el => {
    if (!el.hasAttribute('data-animate')) el.setAttribute('data-animate', '');
  });
});


// ── Scroll-driven Entry Animations ───────────────────────────
const animatedEls = document.querySelectorAll('[data-animate]');

if (prefersReducedMotion) {
  animatedEls.forEach(el => el.classList.add('visible'));
} else if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.08, rootMargin: '0px 0px -40px 0px' });

  animatedEls.forEach(el => {
    // If already in viewport on load (e.g. hero elements), mark visible immediately
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight && rect.bottom > 0) {
      el.classList.add('visible');
    } else {
      observer.observe(el);
    }
  });
} else {
  // Fallback: show everything immediately
  animatedEls.forEach(el => el.classList.add('visible'));
}


// ── Hamburger / Mobile Nav ────────────────────────────────────
const hamburger = document.getElementById('hamburger-btn');
const mobileNav = document.getElementById('mobile-nav');

if (hamburger && mobileNav) {
  const mobileLinks = mobileNav.querySelectorAll('.mobile-nav-link, .mobile-nav-cta');

  const openMenu = () => {
    mobileNav.classList.add('open');
    hamburger.setAttribute('aria-expanded', 'true');
    mobileNav.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  };

  const closeMenu = () => {
    mobileNav.classList.remove('open');
    hamburger.setAttribute('aria-expanded', 'false');
    mobileNav.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  };

  hamburger.addEventListener('click', () => {
    mobileNav.classList.contains('open') ? closeMenu() : openMenu();
  });

  mobileLinks.forEach(link => link.addEventListener('click', closeMenu));

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && mobileNav.classList.contains('open')) {
      closeMenu();
      hamburger.focus();
    }
  });
}


// ── Sticky Header Shadow on Scroll ───────────────────────────
const siteHeader = document.getElementById('site-header');

if (siteHeader) {
  window.addEventListener('scroll', () => {
    siteHeader.classList.toggle('scrolled', window.scrollY > 20);
  }, { passive: true });
}


// ── Smooth Scroll for same-page anchor links ─────────────────
// Only intercepts links whose target actually exists on THIS page,
// so cross-page links like "../index.html#services" are left alone.
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const targetId = this.getAttribute('href').slice(1);
    if (!targetId) return;

    const target = document.getElementById(targetId);
    if (!target) return;

    e.preventDefault();
    const headerHeight = siteHeader ? siteHeader.offsetHeight : 0;
    const targetTop = target.getBoundingClientRect().top + window.scrollY - headerHeight;
    window.scrollTo({
      top: targetTop,
      behavior: prefersReducedMotion ? 'auto' : 'smooth'
    });
  });
});


// ── Horizontal scrollers (work band + galleries) ─────────────
// Progressive enhancement over a scroller that already works
// with pure CSS scroll-snap. Adds arrows + pointer drag.
// Deliberately no wheel hijacking: remapping vertical wheel to
// horizontal traps users trying to scroll past the section.
function initScroller(track) {
  if (!track) return;

  const wrap = track.closest('.work-scroller-wrap, .gallery-wrap');
  if (!wrap) return;

  const prev = wrap.querySelector('.scroll-prev');
  const next = wrap.querySelector('.scroll-next');

  const step = () => {
    const first = track.querySelector('li, figure');
    if (!first) return track.clientWidth * 0.8;
    const gap = parseFloat(getComputedStyle(track).columnGap || '0') || 0;
    return first.getBoundingClientRect().width + gap;
  };

  const maxScroll = () => track.scrollWidth - track.clientWidth;

  function sync() {
    const scrollable = maxScroll() > 4;
    [prev, next].forEach(btn => { if (btn) btn.hidden = !scrollable; });
    if (!scrollable) return;
    // 2px tolerance: sub-pixel layout can leave scrollLeft just shy of the end
    if (prev) prev.disabled = track.scrollLeft <= 2;
    if (next) next.disabled = track.scrollLeft >= maxScroll() - 2;
  }

  if (prev) prev.addEventListener('click', () => track.scrollBy({ left: -step(), behavior: 'smooth' }));
  if (next) next.addEventListener('click', () => track.scrollBy({ left:  step(), behavior: 'smooth' }));

  track.addEventListener('scroll', sync, { passive: true });
  window.addEventListener('resize', sync, { passive: true });
  sync();

  // Pointer drag-to-pan (desktop mice; touch already pans natively)
  let dragging = false, startX = 0, startScroll = 0, moved = 0;

  track.addEventListener('pointerdown', e => {
    if (e.pointerType === 'touch') return;
    dragging = true;
    moved = 0;
    startX = e.clientX;
    startScroll = track.scrollLeft;
    track.style.scrollSnapType = 'none';
    // The track sets scroll-behavior:smooth for the arrow buttons, but during
    // a drag that makes every scrollLeft assignment animate — successive
    // assignments interrupt each other and the track barely moves. Drag needs
    // instant positioning; smooth is restored on release.
    track.style.scrollBehavior = 'auto';
  });

  track.addEventListener('pointermove', e => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    moved = Math.abs(dx);
    if (moved > 3 && !track.hasPointerCapture(e.pointerId)) {
      track.setPointerCapture(e.pointerId);
      track.classList.add('is-dragging');
    }
    track.scrollLeft = startScroll - dx;
  });

  function endDrag(e) {
    if (!dragging) return;
    dragging = false;
    track.classList.remove('is-dragging');
    track.style.scrollSnapType = '';
    track.style.scrollBehavior = '';
    if (e && e.pointerId != null && track.hasPointerCapture(e.pointerId)) {
      track.releasePointerCapture(e.pointerId);
    }
  }

  track.addEventListener('pointerup', endDrag);
  track.addEventListener('pointercancel', endDrag);

  // Suppress the click that ends a drag so dragging never navigates
  track.addEventListener('click', e => {
    if (moved > 5) { e.preventDefault(); e.stopPropagation(); }
    moved = 0;
  }, true);
}

document.querySelectorAll('.work-track, .gallery-track').forEach(initScroller);


// ── Contact Form Submission (Formspree) ──────────────────────
const form       = document.getElementById('contact-form');
const successMsg = document.getElementById('form-success');
const errorMsg   = document.getElementById('form-error');
const submitBtn  = document.getElementById('form-submit');

if (form && successMsg && errorMsg && submitBtn) {
  form.addEventListener('submit', async function (e) {
    e.preventDefault();

    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }

    const originalText = submitBtn.textContent;
    submitBtn.textContent = 'Sending…';
    submitBtn.disabled = true;
    successMsg.hidden = true;
    errorMsg.hidden   = true;

    try {
      const response = await fetch(form.action, {
        method: 'POST',
        body: new FormData(form),
        headers: { 'Accept': 'application/json' }
      });

      if (response.ok) {
        form.reset();
        successMsg.hidden = false;
        successMsg.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        if (typeof gtag === 'function') {
          gtag('event', 'form_submit', {
            event_category: 'Contact',
            event_label: 'Free Estimate Request'
          });
        }
      } else {
        throw new Error('Server error');
      }
    } catch {
      errorMsg.hidden = false;
    } finally {
      submitBtn.textContent = originalText;
      submitBtn.disabled = false;
    }
  });
}
