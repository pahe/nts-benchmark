"use strict";

const state = {
  runs: [],
  selectedPath: null,
  openFileAvailable: false,
  viewers: {
    a: { source: "", displayedSource: "", path: "", sizeBytes: null, formatted: true, exists: false, loadToken: 0 },
    b: { source: "", displayedSource: "", path: "", sizeBytes: null, formatted: true, exists: false, loadToken: 0 }
  }
};
const elements = {
  status: document.querySelector("#app-status"),
  generatedAt: document.querySelector("#generated-at"),
  selects: { a: document.querySelector("#run-a-select"), b: document.querySelector("#run-b-select") }
};

const statusLabels = {
  implementation_completed: "Implementation klar",
  implementation_failed: "Implementation misslyckad",
  implementation_interrupted: "Implementation avbruten",
  implementation_running: "Implementation pågår",
  implementation_pending: "Väntar"
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, character => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#039;"
  })[character]);
}

function highlight(source, path) {
  const extension = path.split(".").pop().toLowerCase();
  if (["json", "jsonl"].includes(extension)) {
    return escapeHtml(source)
      .replace(/(&quot;(?:\\.|[^&])*?&quot;)(\s*:)/g, '<span class="token-property">$1</span>$2')
      .replace(/\b(true|false|null)\b/g, '<span class="token-keyword">$1</span>')
      .replace(/\b(-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)\b/gi, '<span class="token-number">$1</span>');
  }

  if (!["cs", "razor", "cshtml", "csproj", "props", "targets", "sln", "slnx"].includes(extension)) {
    return escapeHtml(source);
  }

  const tokens = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|(@?"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(^\s*#\w+[^\n]*|@(?:page|using|inject|model|code|functions)\b)|(\b(?:abstract|as|async|await|base|bool|break|byte|case|catch|char|checked|class|const|continue|decimal|default|delegate|do|double|else|enum|event|explicit|extern|false|finally|fixed|float|for|foreach|from|get|global|goto|group|if|implicit|in|init|int|interface|internal|into|is|join|let|lock|long|namespace|new|null|object|operator|orderby|out|override|params|partial|private|protected|public|readonly|record|ref|required|return|sbyte|sealed|select|set|short|sizeof|stackalloc|static|string|struct|switch|this|throw|true|try|typeof|uint|ulong|unchecked|unsafe|ushort|using|value|var|virtual|void|volatile|when|where|while|with|yield)\b)|(\b\d+(?:\.\d+)?[fFdDmMlLuU]?\b)/gm;
  let output = "";
  let cursor = 0;
  let match;

  while ((match = tokens.exec(source)) !== null) {
    output += escapeHtml(source.slice(cursor, match.index));
    const className = match[1] ? "token-comment" : match[2] ? "token-string" : match[3] ? "token-directive" : match[4] ? "token-keyword" : "token-number";
    output += `<span class="${className}">${escapeHtml(match[0])}</span>`;
    cursor = tokens.lastIndex;
  }
  return output + escapeHtml(source.slice(cursor));
}

function formatCode(source, path) {
  return source.replace(/\r\n?/g, "\n").split("\n").map((line, index) =>
    `<span class="code-line" data-line-number="${index + 1}" data-marker="">${highlight(line, path) || " "}</span>`
  ).join("");
}

function buildAlignedLineDiff(leftSource, rightSource) {
  const left = leftSource.replace(/\r\n?/g, "\n").split("\n");
  const right = rightSource.replace(/\r\n?/g, "\n").split("\n");
  const operations = [];

  if (left.length * right.length <= 2_000_000) {
    const lcs = Array.from({ length: left.length + 1 }, () => new Uint32Array(right.length + 1));
    for (let leftIndex = left.length - 1; leftIndex >= 0; leftIndex--) {
      for (let rightIndex = right.length - 1; rightIndex >= 0; rightIndex--) {
        lcs[leftIndex][rightIndex] = left[leftIndex] === right[rightIndex]
          ? lcs[leftIndex + 1][rightIndex + 1] + 1
          : Math.max(lcs[leftIndex + 1][rightIndex], lcs[leftIndex][rightIndex + 1]);
      }
    }

    let leftIndex = 0;
    let rightIndex = 0;
    while (leftIndex < left.length && rightIndex < right.length) {
      if (left[leftIndex] === right[rightIndex]) {
        operations.push({ type: "equal", left: left[leftIndex++], right: right[rightIndex++] });
      } else if (lcs[leftIndex + 1][rightIndex] >= lcs[leftIndex][rightIndex + 1]) {
        operations.push({ type: "delete", left: left[leftIndex++] });
      } else {
        operations.push({ type: "insert", right: right[rightIndex++] });
      }
    }
    while (leftIndex < left.length) operations.push({ type: "delete", left: left[leftIndex++] });
    while (rightIndex < right.length) operations.push({ type: "insert", right: right[rightIndex++] });
  } else {
    const length = Math.max(left.length, right.length);
    for (let index = 0; index < length; index++) {
      if (left[index] === right[index]) operations.push({ type: "equal", left: left[index], right: right[index] });
      else {
        if (index < left.length) operations.push({ type: "delete", left: left[index] });
        if (index < right.length) operations.push({ type: "insert", right: right[index] });
      }
    }
  }

  const rows = [];
  let operationIndex = 0;
  let leftNumber = 1;
  let rightNumber = 1;
  while (operationIndex < operations.length) {
    const operation = operations[operationIndex];
    if (operation.type === "equal") {
      rows.push({
        left: operation.left, right: operation.right,
        leftNumber: leftNumber++, rightNumber: rightNumber++, type: "equal"
      });
      operationIndex++;
      continue;
    }

    const deleted = [];
    const inserted = [];
    while (operationIndex < operations.length && operations[operationIndex].type !== "equal") {
      const changedOperation = operations[operationIndex++];
      if (changedOperation.type === "delete") deleted.push(changedOperation.left);
      else inserted.push(changedOperation.right);
    }
    const blockLength = Math.max(deleted.length, inserted.length);
    for (let blockIndex = 0; blockIndex < blockLength; blockIndex++) {
      const hasLeft = blockIndex < deleted.length;
      const hasRight = blockIndex < inserted.length;
      rows.push({
        left: hasLeft ? deleted[blockIndex] : null,
        right: hasRight ? inserted[blockIndex] : null,
        leftNumber: hasLeft ? leftNumber++ : null,
        rightNumber: hasRight ? rightNumber++ : null,
        type: hasLeft && hasRight ? "changed" : hasLeft ? "removed" : "added"
      });
    }
  }
  return rows;
}

function diffLineHtml(line, path, lineNumber, className, marker, label) {
  const content = line === null ? " " : highlight(line, path) || " ";
  const number = lineNumber === null ? "" : lineNumber;
  return `<span class="code-line ${className}" data-line-number="${number}" data-marker="${marker}" title="${escapeHtml(label)}">${content}</span>`;
}

function synchronizeDiffRowHeights() {
  const leftLines = document.querySelectorAll("#code-a .code-line");
  const rightLines = document.querySelectorAll("#code-b .code-line");
  if (leftLines.length !== rightLines.length) return;
  for (let index = 0; index < leftLines.length; index++) {
    leftLines[index].style.minHeight = "";
    rightLines[index].style.minHeight = "";
  }
  for (let index = 0; index < leftLines.length; index++) {
    const height = Math.max(leftLines[index].getBoundingClientRect().height, rightLines[index].getBoundingClientRect().height);
    leftLines[index].style.minHeight = `${height}px`;
    rightLines[index].style.minHeight = `${height}px`;
  }
}

function renderActiveDiff() {
  const left = state.viewers.a;
  const right = state.viewers.b;
  if (!left.exists || !right.exists || left.path !== state.selectedPath || right.path !== state.selectedPath) return;

  const rows = buildAlignedLineDiff(left.displayedSource, right.displayedSource);
  let changed = 0;
  let removed = 0;
  let added = 0;
  const leftHtml = [];
  const rightHtml = [];
  for (const row of rows) {
    if (row.type === "changed") changed++;
    if (row.type === "removed") removed++;
    if (row.type === "added") added++;
    const leftClass = row.type === "changed" ? "diff-changed" : row.type === "removed" ? "diff-removed" : row.type === "added" ? "diff-placeholder" : "";
    const rightClass = row.type === "changed" ? "diff-changed" : row.type === "added" ? "diff-added" : row.type === "removed" ? "diff-placeholder" : "";
    const leftMarker = row.type === "changed" ? "~" : row.type === "removed" ? "−" : "";
    const rightMarker = row.type === "changed" ? "~" : row.type === "added" ? "+" : "";
    const leftLabel = row.type === "changed" ? "Ändrad rad" : row.type === "removed" ? "Borttagen i höger körning" : row.type === "added" ? "Tom rad för justering" : "Oförändrad rad";
    const rightLabel = row.type === "changed" ? "Ändrad rad" : row.type === "added" ? "Tillagd i höger körning" : row.type === "removed" ? "Tom rad för justering" : "Oförändrad rad";
    leftHtml.push(diffLineHtml(row.left, left.path, row.leftNumber, leftClass, leftMarker, leftLabel));
    rightHtml.push(diffLineHtml(row.right, right.path, row.rightNumber, rightClass, rightMarker, rightLabel));
  }
  document.querySelector("#code-a").innerHTML = leftHtml.join("");
  document.querySelector("#code-b").innerHTML = rightHtml.join("");
  const leftMode = isCSharp(left.path) && left.formatted ? "visningsformaterad" : "original";
  const rightMode = isCSharp(right.path) && right.formatted ? "visningsformaterad" : "original";
  document.querySelector("#file-a-meta").textContent = `${formatNumber(left.sizeBytes)} byte · ${leftMode} · ${changed} ändrade · ${removed} borttagna`;
  document.querySelector("#file-b-meta").textContent = `${formatNumber(right.sizeBytes)} byte · ${rightMode} · ${changed} ändrade · ${added} tillagda`;
  requestAnimationFrame(synchronizeDiffRowHeights);
}

function isCSharp(path) {
  return /\.cs$/i.test(path);
}

function formatCSharpForDisplay(source) {
  const text = source.replace(/\r\n?/g, "\n");
  const lines = [];
  let current = "";
  let indent = 0;
  let parentheses = 0;

  const write = value => { current += value; };
  const trimEnd = () => { current = current.replace(/[ \t]+$/g, ""); };
  const space = () => {
    if (current && !/[ \t]$/.test(current)) current += " ";
  };
  const newline = () => {
    trimEnd();
    if (current.trim()) lines.push(`${"    ".repeat(Math.max(0, indent))}${current.trimStart()}`);
    current = "";
  };

  for (let index = 0; index < text.length; index++) {
    const character = text[index];
    const next = text[index + 1] || "";

    if (character === "/" && next === "/") {
      space();
      const end = text.indexOf("\n", index);
      write(text.slice(index, end === -1 ? text.length : end));
      newline();
      if (end === -1) break;
      index = end;
      continue;
    }

    if (character === "/" && next === "*") {
      space();
      const end = text.indexOf("*/", index + 2);
      const commentEnd = end === -1 ? text.length : end + 2;
      const commentLines = text.slice(index, commentEnd).split("\n");
      write(commentLines[0]);
      for (const commentLine of commentLines.slice(1)) {
        newline();
        write(commentLine.trimStart());
      }
      index = commentEnd - 1;
      continue;
    }

    if (character === '"' || character === "'") {
      const quote = character;
      const verbatim = quote === '"' && index > 0 && text[index - 1] === "@";
      const triple = quote === '"' && text.slice(index, index + 3) === '\"\"\"';
      const delimiter = triple ? '\"\"\"' : quote;
      write(delimiter);
      index += delimiter.length - 1;
      while (++index < text.length) {
        if (triple && text.slice(index, index + 3) === delimiter) {
          write(delimiter);
          index += 2;
          break;
        }
        const value = text[index];
        write(value);
        if (!triple && value === quote) {
          if (verbatim && text[index + 1] === quote) {
            write(text[++index]);
            continue;
          }
          if (!verbatim) {
            let slashes = 0;
            for (let cursor = index - 1; cursor >= 0 && text[cursor] === "\\"; cursor--) slashes++;
            if (slashes % 2 === 1) continue;
          }
          break;
        }
      }
      continue;
    }

    if (/\s/.test(character)) {
      if (character === "\n") newline();
      else space();
      continue;
    }

    if (character === "(") {
      if (/\b(if|for|foreach|while|switch|catch|using|lock|fixed)$/.test(current.trimEnd())) space();
      parentheses++;
      write(character);
      continue;
    }
    if (character === ")") {
      parentheses = Math.max(0, parentheses - 1);
      trimEnd();
      write(character);
      continue;
    }
    if (character === "{") {
      space();
      write("{");
      newline();
      indent++;
      continue;
    }
    if (character === "}") {
      newline();
      indent = Math.max(0, indent - 1);
      write("}");
      const following = text.slice(index + 1).match(/^\s*(else|catch|finally)\b/);
      if (following) space();
      else if (next !== ";" && next !== ",") newline();
      continue;
    }
    if (character === ";") {
      trimEnd();
      write(";");
      if (parentheses === 0) newline();
      else space();
      continue;
    }
    if (character === ",") {
      trimEnd();
      write(",");
      space();
      continue;
    }
    if (character === "=" && next !== "=" && next !== ">" && !/[=!<>+\-*/%&|?]/.test(text[index - 1] || "")) {
      space();
      write("=");
      space();
      continue;
    }
    if ((character === "=" && next === ">") || (character === "&" && next === "&") || (character === "|" && next === "|") || (character === "?" && next === "?")) {
      space();
      write(character + next);
      space();
      index++;
      continue;
    }
    write(character);
  }
  newline();
  return lines.join("\n");
}

function renderViewer(side) {
  const viewerState = state.viewers[side];
  const code = document.querySelector(`#code-${side}`);
  const meta = document.querySelector(`#file-${side}-meta`);
  const formatButton = document.querySelector(`.format-toggle[data-side="${side}"]`);
  const canFormat = isCSharp(viewerState.path);
  formatButton.disabled = !canFormat;
  formatButton.setAttribute("aria-pressed", String(canFormat && viewerState.formatted));
  formatButton.textContent = canFormat ? `Formaterad vy: ${viewerState.formatted ? "på" : "av"}` : "Formaterad vy: ej tillgänglig";
  const formatted = canFormat && viewerState.formatted;
  const displayedSource = formatted ? formatCSharpForDisplay(viewerState.source) : viewerState.source;
  viewerState.displayedSource = displayedSource;
  meta.textContent = `${formatNumber(viewerState.sizeBytes)} byte${formatted ? " · visningsformaterad" : " · original"}`;
  code.innerHTML = formatCode(displayedSource, viewerState.path);
  renderActiveDiff();
}

function updateExternalEditorButton(side, fileExists) {
  const button = document.querySelector(`.external-editor[data-side="${side}"]`);
  button.disabled = !state.openFileAvailable || !fileExists;
  button.title = state.openFileAvailable
    ? fileExists ? "Öppna originalfilen i operativsystemets standardeditor" : "Filen saknas i denna körning"
    : "Tillgängligt när sidan körs med den lokala resultatservern";
}

async function detectLocalCapabilities() {
  try {
    const response = await fetch("api/capabilities", { cache: "no-store" });
    if (!response.ok) return;
    const capabilities = await response.json();
    state.openFileAvailable = capabilities.openFile === true;
  } catch {
    state.openFileAvailable = false;
  }
}

async function openInExternalEditor(side) {
  const run = selectedRun(side);
  const path = state.viewers[side].path;
  const button = document.querySelector(`.external-editor[data-side="${side}"]`);
  if (!state.openFileAvailable || !run || !path) return;

  button.disabled = true;
  elements.status.textContent = `Öppnar ${path} …`;
  try {
    const response = await fetch("api/open-file", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ runId: run.id, path })
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: `${response.status} ${response.statusText}` }));
      throw new Error(error.message || "Filen kunde inte öppnas.");
    }
    elements.status.textContent = `Öppnade ${path} i standardeditorn.`;
  } catch (error) {
    elements.status.textContent = `Filen kunde inte öppnas externt: ${error.message}`;
  } finally {
    updateExternalEditorButton(side, true);
  }
}

function formatDate(value) {
  if (!value) return "–";
  return new Intl.DateTimeFormat("sv-SE", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function formatDuration(seconds) {
  if (seconds === null || seconds === undefined) return "–";
  const minutes = Math.floor(seconds / 60);
  return minutes ? `${minutes} min ${Math.round(seconds % 60)} s` : `${Math.round(seconds)} s`;
}

function formatNumber(value) {
  return value === null || value === undefined ? "–" : new Intl.NumberFormat("sv-SE").format(value);
}

function runLabel(run) {
  const phase = run.implementation || {};
  return `${phase.model || "Okänd modell"} · ${phase.reasoningEffort || "–"} · ${formatDate(phase.startedAtUtc || run.createdAtUtc)}`;
}

function addOptions(select) {
  select.replaceChildren(...state.runs.map(run => {
    const option = document.createElement("option");
    option.value = run.id;
    option.textContent = runLabel(run);
    return option;
  }));
}

function buildTree(files) {
  const root = { directories: new Map(), files: [] };
  for (const file of files) {
    const parts = file.path.split("/");
    let node = root;
    for (const directory of parts.slice(0, -1)) {
      if (!node.directories.has(directory)) node.directories.set(directory, { directories: new Map(), files: [] });
      node = node.directories.get(directory);
    }
    node.files.push({ ...file, name: parts[parts.length - 1] });
  }
  return root;
}

function renderTreeNode(node, side, depth = 0) {
  const list = document.createElement("ul");
  for (const [name, child] of [...node.directories.entries()].sort(([a], [b]) => a.localeCompare(b, "sv"))) {
    const item = document.createElement("li");
    const details = document.createElement("details");
    details.open = depth < 2;
    const summary = document.createElement("summary");
    summary.textContent = name;
    details.append(summary, renderTreeNode(child, side, depth + 1));
    item.append(details);
    list.append(item);
  }
  for (const file of [...node.files].sort((a, b) => a.name.localeCompare(b.name, "sv"))) {
    const item = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.className = `file-button ${file.presence}`;
    const name = document.createElement("span");
    name.className = "file-name";
    name.textContent = file.name;
    button.append(name);
    if (file.presence !== "both") {
      const badge = document.createElement("span");
      badge.className = "file-presence";
      badge.textContent = file.presence === "missing" ? "Saknas" : "Endast här";
      button.append(badge);
    }
    const presenceText = file.presence === "missing" ? "saknas i denna körning" : file.presence === "only-here" ? "finns endast i denna körning" : "finns i båda körningarna";
    button.title = `${file.path} – ${presenceText}`;
    button.setAttribute("aria-label", `${file.name}, ${presenceText}`);
    button.dataset.path = file.path;
    if (file.path === state.selectedPath) button.setAttribute("aria-current", "true");
    button.addEventListener("click", () => selectPath(file.path));
    item.append(button);
    list.append(item);
  }
  return list;
}

async function loadFile(side, file, path) {
  const code = document.querySelector(`#code-${side}`);
  const heading = document.querySelector(`#file-${side}-heading`);
  const meta = document.querySelector(`#file-${side}-meta`);
  const viewer = code.closest(".file-viewer");
  const loadToken = ++state.viewers[side].loadToken;
  heading.textContent = path;
  state.viewers[side].exists = false;
  state.viewers[side].displayedSource = "";

  if (!file) {
    viewer.classList.add("file-missing");
    code.classList.remove("numbered-code");
    meta.textContent = "Saknas i körningen";
    code.textContent = "Den här filen finns bara i den andra valda körningen.";
    const formatButton = document.querySelector(`.format-toggle[data-side="${side}"]`);
    formatButton.disabled = true;
    formatButton.setAttribute("aria-pressed", "false");
    formatButton.textContent = "Formaterad vy: ej tillgänglig";
    state.viewers[side].path = path;
    updateExternalEditorButton(side, false);
    return;
  }

  viewer.classList.remove("file-missing");
  code.classList.add("numbered-code");
  code.textContent = "Läser in …";
  state.viewers[side].path = file.path;
  state.viewers[side].sizeBytes = file.sizeBytes;
  updateExternalEditorButton(side, true);

  try {
    const response = await fetch(file.url);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const source = await response.text();
    if (state.selectedPath !== file.path || state.viewers[side].loadToken !== loadToken) return;
    state.viewers[side].source = source;
    state.viewers[side].exists = true;
    renderViewer(side);
  } catch (error) {
    state.viewers[side].exists = false;
    code.textContent = `Filen kunde inte läsas: ${error.message}`;
  }
}

function selectedRun(side) {
  return state.runs.find(item => item.id === elements.selects[side].value);
}

function comparisonFiles(side) {
  const current = selectedRun(side);
  const other = selectedRun(side === "a" ? "b" : "a");
  const currentByPath = new Map((current ? current.files : []).map(file => [file.path, file]));
  const otherPaths = new Set((other ? other.files : []).map(file => file.path));
  const allPaths = new Set([...currentByPath.keys(), ...otherPaths]);

  return [...allPaths].sort((a, b) => a.localeCompare(b, "sv")).map(path => {
    const file = currentByPath.get(path);
    return {
      ...(file || { path, sizeBytes: null, url: null }),
      presence: !file ? "missing" : otherPaths.has(path) ? "both" : "only-here"
    };
  });
}

async function selectPath(path) {
  state.selectedPath = path;
  for (const side of ["a", "b"]) {
    document.querySelectorAll(`[data-side="${side}"] .file-button`).forEach(button => {
      if (button.dataset.path === path) button.setAttribute("aria-current", "true");
      else button.removeAttribute("aria-current");
    });
  }

  await Promise.all(["a", "b"].map(side => {
    const run = selectedRun(side);
    const file = run ? run.files.find(item => item.path === path) : null;
    return loadFile(side, file, path);
  }));
}

function metric(term, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "metric";
  const dt = document.createElement("dt");
  const dd = document.createElement("dd");
  dt.textContent = term;
  dd.textContent = value;
  wrapper.append(dt, dd);
  return wrapper;
}

function renderResultItems(side, run) {
  const list = document.querySelector(`#results-${side}`);
  const labels = { available: "Registrerat", partial: "Delvis registrerat", missing: "Saknas", not_applicable: "Inte tillämpligt" };
  const items = run.resultItems || [];
  const rows = items.map(item => {
    const row = document.createElement("div");
    row.className = "result-row";
    const term = document.createElement("dt");
    term.textContent = item.label;
    const description = document.createElement("dd");
    const value = document.createElement("span");
    value.className = "result-value";
    value.textContent = item.value;
    const stateBadge = document.createElement("span");
    stateBadge.className = `result-state ${item.status}`;
    stateBadge.textContent = labels[item.status] || item.status;
    description.append(value, stateBadge);
    if (item.note) {
      const note = document.createElement("span");
      note.className = "result-note";
      note.textContent = item.note;
      description.append(note);
    }
    if (item.artifactPath && run.files.some(file => file.path === item.artifactPath)) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "artifact-button";
      button.textContent = "Visa underlag";
      button.addEventListener("click", () => selectPath(item.artifactPath));
      description.append(button);
    }
    row.append(term, description);
    return row;
  });
  list.replaceChildren(...rows);
  const available = items.filter(item => item.status === "available").length;
  const partial = items.filter(item => item.status === "partial").length;
  document.querySelector(`#coverage-${side}`).textContent = `${available} kompletta, ${partial} delvisa av ${items.length}`;
}

function preferredFile(files) {
  const preferences = [
    /implementation\/workspace\/RoomBooking\.Web\/Program\.cs$/i,
    /implementation\/final-response\.md$/i,
    /README\.md$/i,
    /\.cs$/i
  ];
  return preferences.map(pattern => files.find(file => pattern.test(file.path))).find(Boolean) || files[0];
}

async function renderRun(side) {
  const run = selectedRun(side);
  if (!run) return;
  const phase = run.implementation || {};
  document.querySelector(`#model-${side}`).textContent = phase.model || "Okänd modell";
  document.querySelector(`#reasoning-${side}`).textContent = phase.reasoningEffort || "–";

  const status = document.querySelector(`#status-${side}`);
  status.textContent = statusLabels[run.status] || run.status || "Okänd";
  const statusParts = (run.status || "").split("_");
  status.className = `status-chip ${statusParts[statusParts.length - 1] || ""}`;

  const metrics = document.querySelector(`#metrics-${side}`);
  metrics.replaceChildren(
    metric("Start", formatDate(phase.startedAtUtc || run.createdAtUtc)),
    metric("Tid", formatDuration(phase.durationSeconds)),
    metric("Output tokens", formatNumber(phase.outputTokens)),
    metric("Tester", phase.testsPassed === null || phase.testsPassed === undefined ? "–" : `${phase.testsPassed}/${phase.testsTotal === null || phase.testsTotal === undefined ? "?" : phase.testsTotal}`)
  );
  renderResultItems(side, run);

  try {
    const response = await fetch(run.manifestUrl);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const manifest = await response.text();
    const manifestCode = document.querySelector(`#manifest-${side}`);
    manifestCode.classList.add("numbered-code");
    manifestCode.innerHTML = formatCode(manifest, "manifest.json");
  } catch (error) {
    document.querySelector(`#manifest-${side}`).textContent = `Manifestet kunde inte läsas: ${error.message}`;
  }

}

async function renderComparison() {
  await Promise.all([renderRun("a"), renderRun("b")]);
  for (const side of ["a", "b"]) {
    const tree = document.querySelector(`#tree-${side}`);
    tree.replaceChildren(renderTreeNode(buildTree(comparisonFiles(side)), side));
  }

  const paths = comparisonFiles("a").map(file => file.path);
  const leftPaths = new Set(selectedRun("a").files.map(file => file.path));
  const rightPaths = new Set(selectedRun("b").files.map(file => file.path));
  const onlyLeft = [...leftPaths].filter(path => !rightPaths.has(path)).length;
  const onlyRight = [...rightPaths].filter(path => !leftPaths.has(path)).length;
  const common = [...leftPaths].filter(path => rightPaths.has(path)).length;
  elements.status.textContent = `${state.runs.length} körningar är tillgängliga. ${common} gemensamma filer, ${onlyLeft} endast till vänster och ${onlyRight} endast till höger.`;
  if (!paths.includes(state.selectedPath)) {
    const allFiles = selectedRun("a").files.concat(selectedRun("b").files);
    const preferred = preferredFile(allFiles);
    state.selectedPath = preferred ? preferred.path : paths[0];
  }
  if (state.selectedPath) await selectPath(state.selectedPath);
}

async function start() {
  try {
    const response = await fetch("data/runs.json");
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const data = await response.json();
    state.runs = data.runs;
    await detectLocalCapabilities();
    elements.generatedAt.textContent = `Data skapad ${formatDate(data.generatedAtUtc)}`;
    if (!state.runs.length) {
      elements.status.textContent = "Inga körningar ännu. Starta en benchmarkkörning för att visa resultat här.";
      elements.selects.a.disabled = true;
      elements.selects.b.disabled = true;
      document.querySelector("#swap-runs").disabled = true;
      document.querySelector("#comparison").hidden = true;
      return;
    }

    addOptions(elements.selects.a);
    addOptions(elements.selects.b);
    elements.selects.a.selectedIndex = 0;
    elements.selects.b.selectedIndex = Math.min(1, state.runs.length - 1);

    elements.selects.a.addEventListener("change", renderComparison);
    elements.selects.b.addEventListener("change", renderComparison);
    document.querySelectorAll(".wrap-toggle").forEach(button => {
      button.addEventListener("click", () => {
        const panel = document.querySelector(`[data-side="${button.dataset.side}"]`);
        const enabled = !panel.classList.contains("wrap-lines");
        panel.classList.toggle("wrap-lines", enabled);
        button.setAttribute("aria-pressed", String(enabled));
        button.textContent = `Radbrytning: ${enabled ? "på" : "av"}`;
      });
    });
    document.querySelectorAll(".format-toggle").forEach(button => {
      button.addEventListener("click", () => {
        const viewerState = state.viewers[button.dataset.side];
        if (!isCSharp(viewerState.path)) return;
        const formatted = !viewerState.formatted;
        const otherSide = button.dataset.side === "a" ? "b" : "a";
        viewerState.formatted = formatted;
        if (state.viewers[otherSide].path === viewerState.path && isCSharp(state.viewers[otherSide].path)) {
          state.viewers[otherSide].formatted = formatted;
          renderViewer(otherSide);
        }
        renderViewer(button.dataset.side);
      });
    });
    document.querySelectorAll(".external-editor").forEach(button => {
      button.addEventListener("click", () => openInExternalEditor(button.dataset.side));
    });
    document.querySelector("#swap-runs").addEventListener("click", async () => {
      const left = elements.selects.a.value;
      elements.selects.a.value = elements.selects.b.value;
      elements.selects.b.value = left;
      await renderComparison();
    });
    window.addEventListener("resize", () => requestAnimationFrame(synchronizeDiffRowHeights));

    await renderComparison();
  } catch (error) {
    elements.status.textContent = `Resultaten kunde inte läsas: ${error.message} Kör sidan via en lokal webbserver.`;
  }
}

start();
