#!/usr/bin/env bun
// Anvil Report Generator — Converts Markdown to self-contained HTML
// Zero npm dependencies. Reads from stdin or file arg, writes HTML to stdout.

import { readFileSync } from "fs";

// Read markdown input
let markdown;
if (process.argv[2]) {
  markdown = readFileSync(process.argv[2], "utf-8");
} else {
  markdown = readFileSync("/dev/stdin", "utf-8");
}

// --- Markdown-to-HTML Converter ---

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function sanitizeHref(url) {
  const trimmed = url.trim();
  // Allow http, https, mailto, and relative URLs
  if (/^(https?:|mailto:|\/|#|\.)/i.test(trimmed)) return trimmed;
  // Block javascript:, data:, vbscript:, etc.
  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed)) return "#blocked";
  return trimmed;
}

function convertInline(text) {
  // Escape HTML entities first to prevent injection
  text = escapeHtml(text);
  // Code spans (content already escaped above)
  text = text.replace(/`([^`]+)`/g, "<code>$1</code>");
  // Bold
  text = text.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  // Italic
  text = text.replace(/\*(.+?)\*/g, "<em>$1</em>");
  // Links (href sanitized against javascript: etc.)
  text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) =>
    `<a href="${sanitizeHref(href)}">${label}</a>`
  );
  return text;
}

function convertMarkdown(md) {
  const lines = md.split("\n");
  const html = [];
  let i = 0;
  let title = "";
  let inExecutiveSummary = false;

  while (i < lines.length) {
    const line = lines[i];

    // Code blocks
    if (line.startsWith("```")) {
      const lang = line.slice(3).trim().replace(/[^a-zA-Z0-9_-]/g, "");
      const codeLines = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) {
        codeLines.push(escapeHtml(lines[i]));
        i++;
      }
      if (i < lines.length) i++; // skip closing ``` only if found
      const langAttr = lang ? ` class="language-${lang}"` : "";
      html.push(`<pre><code${langAttr}>${codeLines.join("\n")}</code></pre>`);
      continue;
    }

    // Headings
    const headingMatch = line.match(/^(#{1,4})\s+(.+)$/);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const text = convertInline(headingMatch[2]);

      // Close executive summary div if we hit another h2
      if (level === 2 && inExecutiveSummary) {
        html.push("</div>");
        inExecutiveSummary = false;
      }

      html.push(`<h${level}>${text}</h${level}>`);

      // Extract title from h1
      if (level === 1 && !title) {
        title = headingMatch[2];
      }

      // Open executive summary div
      if (level === 2 && headingMatch[2] === "Executive Summary") {
        html.push('<div class="executive-summary">');
        inExecutiveSummary = true;
      }

      i++;
      continue;
    }

    // Horizontal rule
    if (/^---+$/.test(line.trim())) {
      i++;
      html.push("<hr>");
      continue;
    }

    // Tables
    if (line.includes("|") && line.trim().startsWith("|")) {
      const tableLines = [];
      while (i < lines.length && lines[i].includes("|") && lines[i].trim().startsWith("|")) {
        tableLines.push(lines[i]);
        i++;
      }
      if (tableLines.length >= 2) {
        html.push("<table>");
        // Header row
        const headerCells = tableLines[0].split("|").filter((c) => c.trim() !== "");
        html.push("<thead><tr>");
        for (const cell of headerCells) {
          html.push(`<th>${convertInline(cell.trim())}</th>`);
        }
        html.push("</tr></thead>");
        // Body rows (skip separator row at index 1)
        html.push("<tbody>");
        for (let r = 2; r < tableLines.length; r++) {
          const cells = tableLines[r].split("|").filter((c) => c.trim() !== "");
          html.push("<tr>");
          for (const cell of cells) {
            html.push(`<td>${convertInline(cell.trim())}</td>`);
          }
          html.push("</tr>");
        }
        html.push("</tbody></table>");
      }
      continue;
    }

    // Blockquotes
    if (line.startsWith(">")) {
      const quoteLines = [];
      while (i < lines.length && lines[i].startsWith(">")) {
        quoteLines.push(lines[i].replace(/^>\s?/, ""));
        i++;
      }
      html.push(`<blockquote>${quoteLines.map(convertInline).join("<br>")}</blockquote>`);
      continue;
    }

    // Unordered lists
    if (/^[-*]\s/.test(line.trim())) {
      html.push("<ul>");
      while (i < lines.length && /^[-*]\s/.test(lines[i].trim())) {
        const itemText = lines[i].trim().replace(/^[-*]\s+/, "");
        html.push(`<li>${convertInline(itemText)}</li>`);
        i++;
      }
      html.push("</ul>");
      continue;
    }

    // Ordered lists
    if (/^\d+\.\s/.test(line.trim())) {
      html.push("<ol>");
      while (i < lines.length && /^\d+\.\s/.test(lines[i].trim())) {
        const itemText = lines[i].trim().replace(/^\d+\.\s+/, "");
        html.push(`<li>${convertInline(itemText)}</li>`);
        i++;
      }
      html.push("</ol>");
      continue;
    }

    // Blank line
    if (line.trim() === "") {
      i++;
      continue;
    }

    // Paragraph — collect consecutive non-blank, non-special lines
    const paraLines = [];
    while (
      i < lines.length &&
      lines[i].trim() !== "" &&
      !lines[i].startsWith("#") &&
      !lines[i].startsWith("```") &&
      !lines[i].startsWith(">") &&
      !/^[-*]\s/.test(lines[i].trim()) &&
      !/^\d+\.\s/.test(lines[i].trim()) &&
      !/^---+$/.test(lines[i].trim()) &&
      !(lines[i].includes("|") && lines[i].trim().startsWith("|"))
    ) {
      paraLines.push(lines[i]);
      i++;
    }
    if (paraLines.length > 0) {
      html.push(`<p>${convertInline(paraLines.join("\n"))}</p>`);
    }
  }

  // Close executive summary if still open at end
  if (inExecutiveSummary) {
    html.push("</div>");
  }

  return { html: html.join("\n"), title };
}

const { html: bodyHtml, title } = convertMarkdown(markdown);

const pageTitle = title || "Anvil Analysis";

const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(pageTitle)}</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    line-height: 1.7;
    color: #1a1a2e;
    background: #f8f9fa;
    padding: 2rem 1rem;
  }

  .container {
    max-width: 860px;
    margin: 0 auto;
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    padding: 3rem;
  }

  h1 {
    font-size: 1.8rem;
    color: #1a1a2e;
    margin-bottom: 1rem;
    border-bottom: 3px solid #e94560;
    padding-bottom: 0.5rem;
  }

  h2 {
    font-size: 1.4rem;
    color: #1a1a2e;
    margin-top: 2rem;
    margin-bottom: 0.75rem;
  }

  h3 {
    font-size: 1.15rem;
    color: #333;
    margin-top: 1.5rem;
    margin-bottom: 0.5rem;
  }

  h4 {
    font-size: 1rem;
    color: #555;
    margin-top: 1.25rem;
    margin-bottom: 0.5rem;
  }

  p { margin-bottom: 1rem; }

  a { color: #e94560; text-decoration: none; }
  a:hover { text-decoration: underline; }

  blockquote {
    background: #f8f9fa;
    border-left: 4px solid #e94560;
    padding: 0.75rem 1rem;
    margin: 1rem 0;
    color: #555;
    font-size: 0.95rem;
  }

  .executive-summary {
    background: #fafbff;
    border-left: 4px solid #e94560;
    border-radius: 0 6px 6px 0;
    padding: 1.5rem;
    margin: 1rem 0 2rem;
  }

  .executive-summary p:last-child { margin-bottom: 0; }

  pre {
    background: #2d2d3f;
    color: #e8e8e8;
    border-radius: 6px;
    padding: 1rem;
    overflow-x: auto;
    margin: 1rem 0;
    font-size: 0.9rem;
    line-height: 1.5;
  }

  code {
    font-family: "SF Mono", "Fira Code", "Fira Mono", Menlo, Consolas, monospace;
    font-size: 0.9em;
    background: #f0f0f5;
    padding: 0.15em 0.35em;
    border-radius: 3px;
  }

  pre code {
    background: none;
    padding: 0;
    font-size: inherit;
  }

  ul, ol {
    margin: 0.5rem 0 1rem 1.5rem;
  }

  li { margin-bottom: 0.35rem; }

  hr {
    border: none;
    border-top: 1px solid #e0e0e0;
    margin: 2rem 0;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
    font-size: 0.95rem;
  }

  th {
    background: #1a1a2e;
    color: #fff;
    text-align: left;
    padding: 0.6rem 0.8rem;
    font-weight: 600;
  }

  td {
    padding: 0.5rem 0.8rem;
    border-bottom: 1px solid #e0e0e0;
  }

  tbody tr:nth-child(even) { background: #f8f9fa; }

  strong { font-weight: 600; }

  @media print {
    body { background: #fff; padding: 0; }
    .container { box-shadow: none; padding: 0; max-width: 100%; }
    h1 { border-bottom-color: #333; }
    a { color: #333; }
    a[href]::after { content: " (" attr(href) ")"; font-size: 0.8em; color: #666; }
    blockquote { border-left-color: #333; }
    .executive-summary { border-left-color: #333; background: #f5f5f5; }
    pre { background: #f5f5f5; color: #333; border: 1px solid #ddd; }
    h2, h3 { page-break-after: avoid; }
    pre, table, blockquote { page-break-inside: avoid; }
  }
</style>
</head>
<body>
<div class="container">
${bodyHtml}
</div>
</body>
</html>`;

process.stdout.write(fullHtml);
