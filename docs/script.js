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

/* --- Changelog from CHANGELOG.md (synced into docs/) --- */

const CHANGELOG_SOURCES = [
  "./CHANGELOG.md",
  "https://raw.githubusercontent.com/fso13/copy_paste_plus/main/CHANGELOG.md",
];

function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function inlineMarkdown(text) {
  let html = escapeHtml(text);
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
  return html;
}

function parseChangelog(markdown) {
  const lines = markdown.split(/\r?\n/);
  const releases = [];
  let current = null;
  let group = null;

  const flushGroup = () => {
    if (current && group && group.items.length) {
      current.groups.push(group);
    }
    group = null;
  };

  const flushRelease = () => {
    flushGroup();
    if (current && (current.groups.length || current.title !== "Unreleased")) {
      // Skip empty Unreleased
      if (!(current.title === "Unreleased" && current.groups.length === 0)) {
        releases.push(current);
      }
    }
    current = null;
  };

  for (const line of lines) {
    if (/^\[.+\]:\s*https?:\/\//.test(line.trim())) continue;
    if (line.startsWith("# ")) continue;

    const releaseMatch = line.match(/^## \[([^\]]+)\](?:\s+[—\-]\s+(.+))?$/);
    if (releaseMatch) {
      flushRelease();
      current = {
        title: releaseMatch[1],
        date: (releaseMatch[2] || "").trim(),
        groups: [],
      };
      continue;
    }

    const groupMatch = line.match(/^###\s+(.+)$/);
    if (groupMatch && current) {
      flushGroup();
      group = { title: groupMatch[1].trim(), items: [] };
      continue;
    }

    const itemMatch = line.match(/^[-*]\s+(.+)$/);
    if (itemMatch && current) {
      if (!group) group = { title: "Изменения", items: [] };
      group.items.push(itemMatch[1].trim());
    }
  }

  flushRelease();
  return releases;
}

function renderChangelog(releases) {
  const root = document.getElementById("changelog-root");
  if (!root) return;

  if (!releases.length) {
    root.innerHTML = '<p class="changelog-status">Пока нет записей.</p>';
    return;
  }

  root.innerHTML = releases
    .map((release) => {
      const date = release.date
        ? `<span class="changelog-date">${escapeHtml(release.date)}</span>`
        : "";
      const groups = release.groups
        .map((g) => {
          const items = g.items.map((item) => `<li>${inlineMarkdown(item)}</li>`).join("");
          return `<div class="changelog-group"><h4>${escapeHtml(g.title)}</h4><ul>${items}</ul></div>`;
        })
        .join("");
      return `<article class="changelog-release"><h3>${escapeHtml(release.title)}${date}</h3>${groups}</article>`;
    })
    .join("");
}

async function loadChangelog() {
  const root = document.getElementById("changelog-root");
  if (!root) return;

  for (const url of CHANGELOG_SOURCES) {
    try {
      const response = await fetch(url, { cache: "no-cache" });
      if (!response.ok) continue;
      const markdown = await response.text();
      renderChangelog(parseChangelog(markdown));
      return;
    } catch (_) {
      // try next source
    }
  }

  root.innerHTML =
    '<p class="changelog-status">Не удалось загрузить changelog. См. <a href="https://github.com/fso13/copy_paste_plus/blob/main/CHANGELOG.md">CHANGELOG.md</a>.</p>';
}

loadChangelog();
