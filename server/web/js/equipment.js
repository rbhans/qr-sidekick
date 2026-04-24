/* ============================================
   QR Sidekick — Equipment Live Data View
   ============================================ */

let equipmentRefreshInterval = null;

function clearEquipmentRefresh() {
  if (equipmentRefreshInterval) {
    clearInterval(equipmentRefreshInterval);
    equipmentRefreshInterval = null;
  }
}

function getStatusColor(status) {
  if (!status) return null;
  var s = status.toLowerCase();
  if (s.includes('alarm')) return 'var(--niagara-alarm)';
  if (s.includes('fault')) return 'var(--niagara-fault)';
  if (s.includes('down')) return 'var(--niagara-down)';
  if (s.includes('stale')) return 'var(--niagara-stale)';
  if (s.includes('overridden')) return 'var(--niagara-overridden)';
  if (s.includes('disabled')) return 'var(--niagara-disabled)';
  return null;
}

function getStatusBadgeClass(status) {
  if (!status) return '';
  var s = status.toLowerCase();
  if (s.includes('alarm')) return 'badge-alarm';
  if (s.includes('fault')) return 'badge-fault';
  if (s.includes('down')) return 'badge-down';
  if (s.includes('stale')) return 'badge-stale';
  if (s.includes('overridden')) return 'badge-overridden';
  if (s.includes('disabled')) return 'badge-disabled';
  return '';
}

function escapeHtmlEquip(text) {
  var el = document.createElement('span');
  el.textContent = text || '';
  return el.innerHTML;
}

function formatTimestamp(ts) {
  if (!ts) return '';
  var d = new Date(ts);
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) +
    ' ' + d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
}

function renderEquipment(container, qrId) {
  clearEquipmentRefresh();

  if (!qrId) {
    container.innerHTML =
      '<div class="container">' +
        '<div class="empty-state"><p>No equipment ID provided.</p>' +
        '<a href="#/scanner" class="btn btn-outline mt-3">Back to Scanner</a></div>' +
      '</div>';
    return;
  }

  // Show loading state
  container.innerHTML =
    '<div class="container">' +
      '<div class="loading"><div class="spinner"></div><span>Loading equipment...</span></div>' +
    '</div>';

  loadEquipment(container, qrId);

  // Auto-refresh every 30 seconds
  equipmentRefreshInterval = setInterval(function() {
    loadEquipment(container, qrId);
  }, 30000);
}

function loadEquipment(container, qrId) {
  Promise.all([
    API.get('/api/equipment/' + qrId),
    API.get('/api/equipment/' + qrId + '/notes').catch(function() { return []; })
  ]).then(function(results) {
    var data = results[0];
    var notes = results[1];
    renderEquipmentData(container, qrId, data, notes);

    // Save to recent scans
    if (typeof saveRecentScan === 'function') {
      saveRecentScan(qrId, data.name || data.equipment_name || 'Unknown');
    }
  }).catch(function(err) {
    var status = err.message;
    container.innerHTML =
      '<div class="container">' +
        '<a href="#/scanner" class="btn btn-sm mb-3">&larr; Scanner</a>' +
        '<div class="empty-state">' +
          '<h2>' + (status === '404' ? 'Equipment Not Found' : 'Error Loading Equipment') + '</h2>' +
          '<p class="mt-2">' +
            (status === '404'
              ? 'This QR code is not linked to any equipment.'
              : 'Could not load equipment data. Check your connection.') +
          '</p>' +
          '<button class="btn btn-outline mt-3" onclick="loadEquipment(document.getElementById(\'app\'), \'' + qrId + '\')">Retry</button>' +
        '</div>' +
      '</div>';
  });
}

function renderEquipmentData(container, qrId, data, notes) {
  var equipName = data.equipmentName || data.name || 'Unknown Equipment';
  var stationName = data.stationName || '';
  var online = data.online !== false;
  var location = data.location || '';
  var path = data.equipmentPath || data.path || '';
  var points = data.points || [];
  var lastUpdated = data.queriedAt || data.lastUpdated || null;

  var html =
    '<div class="container">' +
      // Back button
      '<a href="#/scanner" class="btn btn-sm mb-3">&larr; Scanner</a>' +

      // Header card
      '<div class="card-flat">' +
        '<div class="flex flex-between flex-center">' +
          '<h1>' + escapeHtmlEquip(equipName) + '</h1>' +
          '<span class="badge ' + (online ? 'badge-online' : 'badge-offline') + '">' +
            (online ? 'Online' : 'Offline') +
          '</span>' +
        '</div>' +
        (stationName ? '<p class="text-secondary">' + escapeHtmlEquip(stationName) + '</p>' : '') +
        (location ? '<p class="text-tertiary" style="font-size:0.8125rem">' + escapeHtmlEquip(location) + '</p>' : '') +
        (path ? '<p class="mono text-tertiary mt-1">' + escapeHtmlEquip(path) + '</p>' : '') +
      '</div>' +

      // Notes section
      '<div class="section-header mt-3">' +
        '<span class="section-label">Notes</span>' +
        '<button class="btn btn-sm" id="toggle-note-form">+ Add</button>' +
      '</div>' +
      '<div id="note-form" class="hidden mb-3">' +
        '<div class="form-group">' +
          '<textarea id="note-input" placeholder="Add a note..." rows="3"></textarea>' +
        '</div>' +
        '<button class="btn btn-primary btn-sm" id="submit-note">Save Note</button>' +
      '</div>' +
      '<div id="notes-list">' +
        renderNotes(notes) +
      '</div>' +

      // Points section
      '<div class="section-header mt-3">' +
        '<span class="section-label">Points</span>' +
        '<span class="section-right">' + points.length + '</span>' +
      '</div>' +
      (points.length > 0
        ? '<div class="card-flat">' + renderPoints(points) + '</div>'
        : '<div class="empty-state"><p>No points available.</p></div>') +

      // Footer
      (lastUpdated
        ? '<p class="text-tertiary mt-3" style="font-size:0.75rem;text-align:center">Last updated: ' + formatTimestamp(lastUpdated) + '</p>'
        : '') +
      '<p class="mono text-tertiary mt-2" style="text-align:center;font-size:10px">' + escapeHtmlEquip(qrId) + '</p>' +
      '<div style="text-align:center" class="mt-2 mb-3">' +
        '<button class="btn btn-outline btn-sm" id="refresh-btn">Refresh</button>' +
      '</div>' +
    '</div>';

  container.innerHTML = html;

  // Wire up event handlers
  var toggleBtn = document.getElementById('toggle-note-form');
  var noteForm = document.getElementById('note-form');
  var submitBtn = document.getElementById('submit-note');
  var refreshBtn = document.getElementById('refresh-btn');

  if (toggleBtn && noteForm) {
    toggleBtn.addEventListener('click', function() {
      noteForm.classList.toggle('hidden');
      if (!noteForm.classList.contains('hidden')) {
        var input = document.getElementById('note-input');
        if (input) input.focus();
      }
    });
  }

  if (submitBtn) {
    submitBtn.addEventListener('click', function() {
      var input = document.getElementById('note-input');
      var content = input ? input.value.trim() : '';
      if (!content) {
        showToast('Note cannot be empty', 'error');
        return;
      }
      submitBtn.disabled = true;
      API.post('/api/equipment/' + qrId + '/notes', { content: content })
        .then(function() {
          showToast('Note added', 'success');
          if (input) input.value = '';
          noteForm.classList.add('hidden');
          // Refresh notes
          return API.get('/api/equipment/' + qrId + '/notes').catch(function() { return []; });
        })
        .then(function(updatedNotes) {
          var notesList = document.getElementById('notes-list');
          if (notesList && updatedNotes) {
            notesList.innerHTML = renderNotes(updatedNotes);
          }
        })
        .catch(function(err) {
          showToast('Failed to add note: ' + err.message, 'error');
        })
        .finally(function() {
          submitBtn.disabled = false;
        });
    });
  }

  if (refreshBtn) {
    refreshBtn.addEventListener('click', function() {
      refreshBtn.disabled = true;
      loadEquipment(container, qrId);
    });
  }
}

function renderNotes(notes) {
  if (!notes || notes.length === 0) {
    return '<div class="empty-state" style="padding:16px"><p>No notes yet.</p></div>';
  }
  return notes.map(function(note) {
    return '<div class="note-card">' +
      '<div class="note-date">' + formatTimestamp(note.created_at || note.createdAt || note.timestamp) + '</div>' +
      '<div class="note-content">' + escapeHtmlEquip(note.content || note.text || '') + '</div>' +
    '</div>';
  }).join('');
}

function renderPoints(points) {
  return points.map(function(pt) {
    var name = pt.name || pt.displayName || '';
    var value = pt.value != null ? String(pt.value) : '--';
    var unit = pt.unit || '';
    var displayValue = value + (unit ? ' ' + unit : '');
    var status = pt.status || pt.facets_status || null;
    var color = getStatusColor(status);
    var styleAttr = color ? ' style="color:' + color + '"' : '';

    return '<div class="point-row">' +
      '<span class="point-name">' + escapeHtmlEquip(name) + '</span>' +
      '<span class="point-value"' + styleAttr + '>' + escapeHtmlEquip(displayValue) + '</span>' +
    '</div>';
  }).join('');
}
