document.getElementById("year").textContent = String(new Date().getFullYear());

const themeToggle = document.getElementById("theme-toggle");
const themeColorMeta = document.getElementById("theme-color-meta");

function systemTheme() {
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function getTheme() {
  return document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
}

function applyTheme(theme, { persist = true } = {}) {
  const next = theme === "light" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", next);
  if (persist) localStorage.setItem("theme", next);
  if (themeColorMeta) {
    themeColorMeta.setAttribute("content", next === "light" ? "#f4f5fa" : "#282a36");
  }
  if (themeToggle) {
    themeToggle.setAttribute(
      "aria-label",
      next === "light" ? "Включить тёмную тему" : "Включить светлую тему"
    );
    themeToggle.title = next === "light" ? "Тёмная тема" : "Светлая тема";
  }
}

const savedTheme = localStorage.getItem("theme");
applyTheme(savedTheme === "light" || savedTheme === "dark" ? savedTheme : systemTheme(), {
  persist: false,
});

if (themeToggle) {
  themeToggle.addEventListener("click", () => {
    applyTheme(getTheme() === "light" ? "dark" : "light");
  });
}

window.matchMedia("(prefers-color-scheme: light)").addEventListener("change", (event) => {
  if (!localStorage.getItem("theme")) {
    applyTheme(event.matches ? "light" : "dark", { persist: false });
  }
});

const revealItems = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.16, rootMargin: "0px 0px -8% 0px" }
  );
  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add("is-visible"));
}

const statuses = [
  "watching pasteboard…",
  "html + rtf captured ✓",
  "favorite starred ★",
  "hotkey: ⌘⇧C armed",
  "changeCount++",
  "plain-text fallback ready",
  "sudo pbcopy coffee",
];

const statusEl = document.getElementById("status-text");
let statusIndex = 0;

if (statusEl) {
  window.setInterval(() => {
    statusIndex = (statusIndex + 1) % statuses.length;
    statusEl.classList.add("is-swap");
    window.setTimeout(() => {
      statusEl.textContent = statuses[statusIndex];
      statusEl.classList.remove("is-swap");
    }, 180);
  }, 2800);
}

const toast = document.getElementById("toast");
const logo = document.querySelector(".logo");
const SECRET_CLICKS = 13;
let clicks = 0;

const toasts = [
  "🦇 clipboard from the dark side",
  "404: empty pasteboard not found",
  "git commit -m \"copied that\"",
  "Stack: Flutter, Swift, vibes",
];

function showToast(message) {
  if (!toast) return;
  toast.hidden = false;
  toast.textContent = message;
  toast.classList.add("is-visible");
  window.clearTimeout(showToast._timer);
  showToast._timer = window.setTimeout(() => {
    toast.classList.remove("is-visible");
    window.setTimeout(() => {
      toast.hidden = true;
    }, 280);
  }, 2400);
}

if (logo) {
  logo.addEventListener("click", (event) => {
    event.preventDefault();
    clicks += 1;

    if (clicks >= SECRET_CLICKS) {
      clicks = 0;
      showToast("🦇 easter egg unlocked — same as in the app");
      document.body.classList.add("is-party");
      window.setTimeout(() => document.body.classList.remove("is-party"), 900);
      return;
    }

    if (clicks === 1) {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }

    if (clicks === 1 || clicks % 4 === 0) {
      showToast(toasts[Math.floor(Math.random() * toasts.length)]);
      document.body.classList.add("is-party");
      window.setTimeout(() => document.body.classList.remove("is-party"), 900);
    }
  });
}

const name = document.querySelector(".hero-name");
if (name) {
  name.addEventListener("mouseenter", () => name.classList.add("is-glitch"));
  name.addEventListener("mouseleave", () => name.classList.remove("is-glitch"));
}
