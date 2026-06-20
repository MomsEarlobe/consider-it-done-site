/* =============================================================
   CONSIDER IT DONE — script.js
   ============================================================= */

'use strict';

// ── Add js-loaded so CSS animations activate safely ──────────
// This MUST be first — it gates the opacity:0 animation styles.
document.body.classList.add('js-loaded');


// ── Add data-animate attributes to key elements ──────────────
// Stagger service cards
document.querySelectorAll('.service-card').forEach((card, i) => {
  card.setAttribute('data-animate', '');
  card.setAttribute('data-animate-delay', String(i + 1));
});

// Stagger pm pillars
document.querySelectorAll('.pm-pillar').forEach((pillar, i) => {
  pillar.setAttribute('data-animate', '');
  pillar.setAttribute('data-animate-delay', String(i + 1));
});

// Stagger why items
document.querySelectorAll('.why-item').forEach((item, i) => {
  item.setAttribute('data-animate', '');
  item.setAttribute('data-animate-delay', String((i % 2) + 1));
});

// Section headings and labels
['.section-headline', '.section-label', '.pm-body', '.contact-sub',
 '.contact-form-wrap', '.contact-guarantee'].forEach(sel => {
  document.querySelectorAll(sel).forEach(el => {
    if (!el.hasAttribute('data-animate')) el.setAttribute('data-animate', '');
  });
});

// Contact info items staggered
document.querySelectorAll('.contact-info-item').forEach((item, i) => {
  item.setAttribute('data-animate', '');
  item.setAttribute('data-animate-delay', String(i + 1));
});


// ── Scroll-driven Entry Animations ───────────────────────────
const animatedEls = document.querySelectorAll('[data-animate]');

if ('IntersectionObserver' in window) {
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
const mobileLinks = mobileNav.querySelectorAll('.mobile-nav-link, .mobile-nav-cta');

function openMenu() {
  mobileNav.classList.add('open');
  hamburger.setAttribute('aria-expanded', 'true');
  mobileNav.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}

function closeMenu() {
  mobileNav.classList.remove('open');
  hamburger.setAttribute('aria-expanded', 'false');
  mobileNav.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

hamburger.addEventListener('click', () => {
  const isOpen = mobileNav.classList.contains('open');
  isOpen ? closeMenu() : openMenu();
});

mobileLinks.forEach(link => link.addEventListener('click', closeMenu));

document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && mobileNav.classList.contains('open')) {
    closeMenu();
    hamburger.focus();
  }
});


// ── Sticky Header Shadow on Scroll ───────────────────────────
const siteHeader = document.getElementById('site-header');

window.addEventListener('scroll', () => {
  siteHeader.classList.toggle('scrolled', window.scrollY > 20);
}, { passive: true });


// ── Smooth Scroll for anchor links ───────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const targetId = this.getAttribute('href').slice(1);
    if (!targetId) return;
    const target = document.getElementById(targetId);
    if (!target) return;

    e.preventDefault();
    const headerHeight = siteHeader.offsetHeight;
    const targetTop = target.getBoundingClientRect().top + window.scrollY - headerHeight;
    window.scrollTo({ top: targetTop, behavior: 'smooth' });
  });
});


// ── Contact Form Submission (Formspree) ──────────────────────
const form       = document.getElementById('contact-form');
const successMsg = document.getElementById('form-success');
const errorMsg   = document.getElementById('form-error');
const submitBtn  = document.getElementById('form-submit');

if (form) {
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
