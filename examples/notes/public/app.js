// State
const state = {
  user: null,
  notes: [],
  selectedId: null,
  draft: null,
  saved: true,
  saveTimer: null,
  searchQ: '',
  tagFilter: ''
};

const $ = function(id) { return document.getElementById(id); };
const userName = $('userName');
const logoutBtn = $('logoutBtn');
const searchInput = $('searchInput');
const tagFilterInput = $('tagFilter');
const newNoteBtn = $('newNoteBtn');
const notesList = $('notesList');
const status = $('status');
const editorActions = $('editorActions');
const editorBody = $('editorBody');
const saveBtn = $('saveBtn');
const deleteBtn = $('deleteBtn');
const toast = $('toast');

function showToast(msg, isError) {
  toast.textContent = msg;
  toast.className = 'toast visible' + (isError ? ' error' : '');
  setTimeout(function() { toast.className = 'toast' + (isError ? ' error' : ''); }, 2200);
}

function fmtDate(stempel) {
  const d = new Date(stempel * 1000);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + ' min ago';
  if (diff < 86400) return Math.floor(diff / 3600) + ' h ago';
  return d.toLocaleDateString();
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function api(method, path, body) {
  const opts = { method: method, headers: {} };
  if (body !== undefined) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(path, opts);
  if (res.status === 401) {
    window.location.href = '/login';
    throw new Error('not logged in');
  }
  if (res.status === 204) return null;
  const data = await res.json();
  if (!res.ok) {
    let msg = 'Error';
    if (data.bledy && data.bledy[0]) msg = data.bledy[0].wiadomosc;
    else if (data.error) msg = data.error;
    throw new Error(msg);
  }
  return data;
}

async function loadUser() {
  try {
    state.user = await api('GET', '/auth/me');
    userName.textContent = state.user.nazwa;
  } catch (e) {
    // already redirected
  }
}

async function logout() {
  try {
    await api('POST', '/auth/logout');
    window.location.href = '/login';
  } catch (e) {
    showToast('Logout error', true);
  }
}

async function loadNotes() {
  try {
    const params = new URLSearchParams();
    if (state.searchQ) params.set('q', state.searchQ);
    if (state.tagFilter) params.set('tag', state.tagFilter);
    const qs = params.toString();
    const data = await api('GET', '/api/notatki' + (qs ? '?' + qs : ''));
    state.notes = data.notatki;
    renderList();
  } catch (e) {
    showToast(e.message, true);
  }
}

function renderList() {
  if (state.notes.length === 0) {
    notesList.innerHTML = '<div class="notes-empty">No notes</div>';
    return;
  }

  let html = '';
  for (let i = 0; i < state.notes.length; i++) {
    const n = state.notes[i];
    const isActive = n.id === state.selectedId ? ' active' : '';
    const preview = n.tresc ? n.tresc.slice(0, 80) : '(empty)';
    const tytul = escapeHtml(n.tytul) || '(no title)';
    const tagi = n.tagi || [];
    let tagsHtml = '';
    const tagLimit = Math.min(tagi.length, 3);
    for (let j = 0; j < tagLimit; j++) {
      tagsHtml += '<span class="tag-chip">' + escapeHtml(tagi[j]) + '</span>';
    }
    const trescPrev = escapeHtml(preview);
    const data = fmtDate(n.zmodyfikowana);

    html += '<div class="note-item' + isActive + '" data-id="' + n.id + '">';
    html += '<div class="note-item-title">' + tytul + '</div>';
    html += '<div class="note-item-preview">' + trescPrev + '</div>';
    html += '<div class="note-item-meta">';
    html += '<div class="note-item-tags">' + tagsHtml + '</div>';
    html += '<span>' + data + '</span>';
    html += '</div></div>';
  }
  notesList.innerHTML = html;

  const items = notesList.querySelectorAll('.note-item');
  for (let i = 0; i < items.length; i++) {
    const el = items[i];
    el.addEventListener('click', function() { selectNote(el.dataset.id); });
  }
}

async function selectNote(id) {
  if (!state.saved) {
    if (!confirm('You have unsaved changes. Discard?')) return;
  }

  state.selectedId = id;
  let note = null;
  for (let i = 0; i < state.notes.length; i++) {
    if (state.notes[i].id === id) { note = state.notes[i]; break; }
  }
  if (!note) return;

  const tagiCopy = [];
  const orig = note.tagi || [];
  for (let i = 0; i < orig.length; i++) tagiCopy.push(orig[i]);

  state.draft = {
    tytul: note.tytul,
    tresc: note.tresc,
    tagi: tagiCopy
  };
  state.saved = true;
  renderEditor();
  renderList();
}

function newNote() {
  if (!state.saved) {
    if (!confirm('You have unsaved changes. Discard?')) return;
  }
  state.selectedId = '__new__';
  state.draft = { tytul: '', tresc: '', tagi: [] };
  state.saved = false;
  renderEditor();
  setTimeout(function() { $('editorTitle').focus(); }, 0);
  renderList();
}

function renderEditor() {
  if (!state.draft) {
    editorBody.innerHTML = '<div class="editor-empty">Select a note or create a new one</div>';
    editorActions.style.display = 'none';
    status.textContent = 'No note selected';
    status.className = 'editor-status';
    return;
  }

  editorActions.style.display = 'flex';

  const tytulVal = escapeHtml(state.draft.tytul);
  const tagiArr = state.draft.tagi || [];
  const tagiStr = escapeHtml(tagiArr.join(', '));
  const trescVal = escapeHtml(state.draft.tresc);

  let html = '';
  html += '<input type="text" class="editor-title" id="editorTitle" placeholder="Title..." value="' + tytulVal + '">';
  html += '<div class="editor-tags-row">';
  html += '<span class="editor-tags-label">Tags:</span>';
  html += '<input type="text" class="editor-tags-input" id="editorTags" placeholder="comma separated" value="' + tagiStr + '">';
  html += '</div>';
  html += '<textarea class="editor-content" id="editorContent" placeholder="Write something...">' + trescVal + '</textarea>';

  editorBody.innerHTML = html;

  const titleEl = $('editorTitle');
  const tagsEl = $('editorTags');
  const contentEl = $('editorContent');

  titleEl.addEventListener('input', function() {
    state.draft.tytul = titleEl.value;
    markDirty();
  });
  tagsEl.addEventListener('input', function() {
    const parts = tagsEl.value.split(',');
    const cleaned = [];
    for (let i = 0; i < parts.length; i++) {
      const t = parts[i].trim();
      if (t.length > 0) cleaned.push(t);
    }
    state.draft.tagi = cleaned;
    markDirty();
  });
  contentEl.addEventListener('input', function() {
    state.draft.tresc = contentEl.value;
    markDirty();
  });

  const els = [titleEl, tagsEl, contentEl];
  for (let i = 0; i < els.length; i++) {
    els[i].addEventListener('keydown', function(e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        saveNote();
      }
    });
  }

  updateStatus();
}

function markDirty() {
  state.saved = false;
  updateStatus();
  if (state.saveTimer) clearTimeout(state.saveTimer);
  state.saveTimer = setTimeout(function() { saveNote(); }, 2500);
}

function updateStatus() {
  if (state.saved) {
    status.textContent = 'Saved';
    status.className = 'editor-status saved';
  } else {
    status.textContent = 'Unsaved changes';
    status.className = 'editor-status dirty';
  }
}

async function saveNote() {
  if (!state.draft) return;
  if (state.saveTimer) {
    clearTimeout(state.saveTimer);
    state.saveTimer = null;
  }

  const tytul = state.draft.tytul.trim() || '(no title)';
  const payload = {
    tytul: tytul,
    tresc: state.draft.tresc,
    tagi: state.draft.tagi
  };

  try {
    let saved;
    if (state.selectedId === '__new__') {
      saved = await api('POST', '/api/notatki', payload);
    } else {
      saved = await api('PUT', '/api/notatki/' + state.selectedId, payload);
    }

    state.selectedId = saved.id;
    state.saved = true;
    updateStatus();
    await loadNotes();
  } catch (e) {
    showToast(e.message, true);
  }
}

async function deleteNote() {
  if (!state.selectedId || state.selectedId === '__new__') {
    state.selectedId = null;
    state.draft = null;
    state.saved = true;
    renderEditor();
    renderList();
    return;
  }

  if (!confirm('Delete this note?')) return;

  try {
    await api('DELETE', '/api/notatki/' + state.selectedId);
    state.selectedId = null;
    state.draft = null;
    state.saved = true;
    renderEditor();
    await loadNotes();
    showToast('Deleted');
  } catch (e) {
    showToast(e.message, true);
  }
}

let searchTimer = null;
function onSearchChange() {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(function() {
    state.searchQ = searchInput.value.trim();
    state.tagFilter = tagFilterInput.value.trim();
    loadNotes();
  }, 250);
}

logoutBtn.addEventListener('click', logout);
newNoteBtn.addEventListener('click', newNote);
saveBtn.addEventListener('click', saveNote);
deleteBtn.addEventListener('click', deleteNote);
searchInput.addEventListener('input', onSearchChange);
tagFilterInput.addEventListener('input', onSearchChange);

(async function() {
  await loadUser();
  await loadNotes();
})();