/* ============================================
   QR Sidekick — Admin View
   ============================================ */

function renderAdmin(container, params) {
  var sub = params[0] || '';
  var id = params[1] || '';
  var action = params[2] || '';

  if (sub === 'stations' && id === 'add') {
    renderStationForm(container, null);
  } else if (sub === 'stations' && id) {
    renderStationForm(container, id);
  } else if (sub === 'stations') {
    renderStationList(container);
  } else if (sub === 'equipment' && id === 'add') {
    renderEquipmentForm(container, null);
  } else if (sub === 'equipment' && id && action === 'qr') {
    renderQrView(container, id);
  } else if (sub === 'equipment' && id) {
    renderEquipmentForm(container, id);
  } else if (sub === 'equipment') {
    renderEquipmentList(container);
  } else if (sub === 'network') {
    renderNetworkInfo(container);
  } else {
    renderAdminDashboard(container);
  }
}

/* ---- Admin Dashboard ---- */

function renderAdminDashboard(container) {
  container.innerHTML =
    '<div class="container">' +
      '<div class="section-header">' +
        '<span class="section-label">Admin</span>' +
      '</div>' +
      '<div class="card" id="admin-stations-card" style="cursor:pointer">' +
        '<h3>Stations</h3>' +
        '<p style="margin:0">Manage Niagara station connections</p>' +
      '</div>' +
      '<div class="card" id="admin-equipment-card" style="cursor:pointer">' +
        '<h3>Equipment &amp; QR Codes</h3>' +
        '<p style="margin:0">Manage equipment configurations and QR codes</p>' +
      '</div>' +
      '<div class="card" id="admin-network-card" style="cursor:pointer">' +
        '<h3>Network</h3>' +
        '<p style="margin:0">Server addresses, HTTPS cert, QR host</p>' +
      '</div>' +
    '</div>';

  document.getElementById('admin-stations-card').addEventListener('click', function() {
    navigate('#/admin/stations');
  });
  document.getElementById('admin-equipment-card').addEventListener('click', function() {
    navigate('#/admin/equipment');
  });
  document.getElementById('admin-network-card').addEventListener('click', function() {
    navigate('#/admin/network');
  });
}

/* ---- Network Info ---- */

function renderNetworkInfo(container) {
  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div class="section-header">' +
        '<span class="section-label">Network</span>' +
      '</div>' +
      '<div id="network-info-area"><div class="loading"><div class="spinner"></div></div></div>' +
    '</div>';

  API.get('/api/network').then(function(info) {
    var area = document.getElementById('network-info-area');
    if (!area) return;

    var ips = info.localIPs || [];
    var httpPort = info.httpPort || 8080;
    var httpsPort = info.httpsPort || 0;
    var mdns = info.mdnsHost || '';
    var certAvail = !!info.certAvailable;

    var addressRows = [];
    if (mdns) {
      addressRows.push({ label: 'mDNS (recommended)', url: 'http://' + mdns + ':' + httpPort });
    }
    ips.forEach(function(ip) {
      addressRows.push({ label: 'LAN IP', url: 'http://' + ip + ':' + httpPort });
    });
    if (httpsPort && mdns) {
      addressRows.push({ label: 'HTTPS (mDNS)', url: 'https://' + mdns + ':' + httpsPort });
    }
    if (httpsPort) {
      ips.forEach(function(ip) {
        addressRows.push({ label: 'HTTPS (IP)', url: 'https://' + ip + ':' + httpsPort });
      });
    }

    var addressHtml = addressRows.map(function(r) {
      return '<div class="point-row">' +
        '<span class="point-name">' + escapeHtml(r.label) + '</span>' +
        '<span class="point-value mono" style="font-size:0.8125rem">' + escapeHtml(r.url) + '</span>' +
      '</div>';
    }).join('');

    area.innerHTML =
      '<div class="card-flat">' +
        '<h3>Server Addresses</h3>' +
        '<p class="text-tertiary" style="font-size:0.8125rem;margin-bottom:8px">' +
          'Techs scan QR codes that point at one of these. mDNS avoids broken QRs if the server IP changes.' +
        '</p>' +
        addressHtml +
      '</div>' +

      '<div class="card-flat mt-3">' +
        '<h3>QR Code Hostname</h3>' +
        '<p class="text-tertiary" style="font-size:0.8125rem">' +
          'Hostname baked into new printed QR codes. Change to <code>' + escapeHtml(mdns || ips[0] || 'host') + ':' + httpPort + '</code> before printing so the QR survives IP changes.' +
        '</p>' +
        '<div class="form-group">' +
          '<label for="qr-host">Host:port</label>' +
          '<input type="text" id="qr-host" class="mono" value="' + escapeAttr((mdns || ips[0] || 'localhost') + ':' + httpPort) + '">' +
          '<div class="form-hint">Saved in this browser. Applied when regenerating QR images.</div>' +
        '</div>' +
        '<button id="qr-host-save" class="btn btn-primary btn-sm">Save</button>' +
      '</div>' +

      '<div class="card-flat mt-3">' +
        '<h3>HTTPS Certificate</h3>' +
        (certAvail
          ? '<p class="text-tertiary" style="font-size:0.8125rem">' +
              'Self-signed cert for <code>' + escapeHtml(mdns) + '</code> and local IPs. ' +
              'Install on phones to silence HTTPS warnings: download, open on device, trust as root CA in system settings.' +
            '</p>' +
            '<a href="/cert.pem" class="btn btn-outline btn-block" download>Download cert.pem</a>'
          : '<p class="text-tertiary" style="font-size:0.8125rem">HTTPS disabled. Start with <code>-https-port 8443</code> to enable.</p>') +
      '</div>' +

      '<div class="card-flat mt-3">' +
        '<h3>Network Checklist</h3>' +
        '<ul style="margin:0;padding-left:20px;font-size:0.875rem;line-height:1.6">' +
          '<li>Phones must be on the <strong>same WiFi</strong> as this server.</li>' +
          '<li>Disable <strong>AP isolation</strong> / <strong>client isolation</strong> on guest networks.</li>' +
          '<li>Set a <strong>DHCP reservation</strong> for this machine so the IP does not change.</li>' +
          '<li>Windows clients need <strong>Bonjour</strong> installed to resolve <code>.local</code>.</li>' +
        '</ul>' +
      '</div>';

    document.getElementById('qr-host-save').addEventListener('click', function() {
      var val = document.getElementById('qr-host').value.trim();
      if (!val) { showToast('Host cannot be empty', 'error'); return; }
      localStorage.setItem('qr-host-override', val);
      showToast('QR host saved', 'success');
    });

    var saved = localStorage.getItem('qr-host-override');
    if (saved) document.getElementById('qr-host').value = saved;
  }).catch(function() {
    var area = document.getElementById('network-info-area');
    if (area) area.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load network info.</p></div>';
  });
}

/* ---- Station List ---- */

function renderStationList(container) {
  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div class="section-header">' +
        '<span class="section-label">Stations</span>' +
        '<a href="#/admin/stations/add" class="btn btn-sm btn-primary">+ Add</a>' +
      '</div>' +
      '<div id="station-list"><div class="loading"><div class="spinner"></div><span>Loading stations...</span></div></div>' +
    '</div>';

  API.get('/api/stations').then(function(stations) {
    var listEl = document.getElementById('station-list');
    if (!listEl) return;

    if (!stations || stations.length === 0) {
      listEl.innerHTML = '<div class="empty-state"><p>No stations configured yet.</p></div>';
      return;
    }

    listEl.innerHTML = stations.map(function(s) {
      return '<div class="card station-card" data-id="' + escapeAttr(s.id) + '">' +
        '<div class="flex flex-center" style="justify-content:space-between;gap:8px">' +
          '<div style="flex:1;cursor:pointer" class="station-open">' +
            '<h3>' + escapeHtml(s.name) + '</h3>' +
            '<small class="mono">' + escapeHtml(s.host) + ':' + escapeHtml(String(s.port)) + '</small>' +
          '</div>' +
          '<button type="button" class="btn btn-sm btn-danger station-delete" title="Delete station">Delete</button>' +
        '</div>' +
      '</div>';
    }).join('');

    listEl.querySelectorAll('.station-open').forEach(function(el) {
      el.addEventListener('click', function() {
        var id = el.closest('.station-card').getAttribute('data-id');
        navigate('#/admin/stations/' + id);
      });
    });

    listEl.querySelectorAll('.station-delete').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        var card = btn.closest('.station-card');
        var id = card.getAttribute('data-id');
        var name = card.querySelector('h3').textContent;
        if (!confirm('Delete "' + name + '"? All equipment and QR codes linked to this station will also be deleted.')) return;
        btn.disabled = true;
        btn.textContent = 'Deleting...';
        API.del('/api/stations/' + id).then(function() {
          card.remove();
          showToast('Station deleted', 'success');
          if (!listEl.querySelector('.station-card')) {
            listEl.innerHTML = '<div class="empty-state"><p>No stations configured yet.</p></div>';
          }
        }).catch(function(err) {
          showToast('Error: ' + err.message, 'error');
          btn.disabled = false;
          btn.textContent = 'Delete';
        });
      });
    });
  }).catch(function(err) {
    var listEl = document.getElementById('station-list');
    if (listEl) listEl.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load stations.</p></div>';
  });
}

/* ---- Station Form (add/edit) ---- */

function renderStationForm(container, stationId) {
  var isEdit = !!stationId;

  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin/stations" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div class="section-header">' +
        '<span class="section-label">' + (isEdit ? 'Edit Station' : 'Add Station') + '</span>' +
      '</div>' +
      '<div id="station-form-area"><div class="loading"><div class="spinner"></div></div></div>' +
    '</div>';

  var stationPromise = isEdit ? API.get('/api/stations/' + stationId) : Promise.resolve(null);

  stationPromise.then(function(station) {
    var area = document.getElementById('station-form-area');
    if (!area) return;

    area.innerHTML =
      '<form id="station-form">' +
        '<div class="form-group">' +
          '<label for="sf-name">Name</label>' +
          '<input type="text" id="sf-name" value="' + escapeAttr(station ? station.name : '') + '" required>' +
        '</div>' +
        '<div class="form-row">' +
          '<div class="form-group">' +
            '<label for="sf-host">Host</label>' +
            '<input type="text" id="sf-host" placeholder="192.168.1.100" value="' + escapeAttr(station ? station.host : '') + '" required>' +
          '</div>' +
          '<div class="form-group">' +
            '<label for="sf-port">Port</label>' +
            '<input type="number" id="sf-port" value="' + (station ? station.port : 443) + '" required>' +
          '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>Protocol</label>' +
          '<div class="flex gap-3 mt-1">' +
            '<label style="display:inline-flex;align-items:center;gap:6px;cursor:pointer">' +
              '<input type="radio" name="sf-protocol" value="https"' + (!station || station.protocol === 'https' ? ' checked' : '') + '>' +
              '<span>HTTPS</span>' +
            '</label>' +
            '<label style="display:inline-flex;align-items:center;gap:6px;cursor:pointer">' +
              '<input type="radio" name="sf-protocol" value="http"' + (station && station.protocol === 'http' ? ' checked' : '') + '>' +
              '<span>HTTP</span>' +
            '</label>' +
          '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="sf-username">Username</label>' +
          '<input type="text" id="sf-username" autocomplete="off">' +
          (isEdit ? '<div class="form-hint">Leave blank to keep existing credentials.</div>' : '') +
        '</div>' +
        '<div class="form-group">' +
          '<label for="sf-password">Password</label>' +
          '<input type="password" id="sf-password" autocomplete="off">' +
          (isEdit ? '<div class="form-hint">Leave blank to keep existing credentials.</div>' : '') +
        '</div>' +
        '<div class="flex gap-2 mt-3">' +
          '<button type="submit" class="btn btn-primary">Save</button>' +
          (isEdit ? '<button type="button" id="sf-test" class="btn btn-outline">Test Connection</button>' : '') +
        '</div>' +
        (isEdit
          ? '<div class="mt-4"><button type="button" id="sf-delete" class="btn btn-danger btn-block">Delete Station</button></div>'
          : '') +
      '</form>';

    document.getElementById('station-form').addEventListener('submit', function(e) {
      e.preventDefault();
      var body = buildStationBody();
      var btn = e.target.querySelector('[type="submit"]');
      btn.disabled = true;
      btn.textContent = 'Saving...';

      var promise = isEdit
        ? API.put('/api/stations/' + stationId, body)
        : API.post('/api/stations', body);

      promise.then(function() {
        showToast('Station saved', 'success');
        navigate('#/admin/stations');
      }).catch(function(err) {
        showToast('Error: ' + err.message, 'error');
        btn.disabled = false;
        btn.textContent = 'Save';
      });
    });

    if (isEdit) {
      document.getElementById('sf-test').addEventListener('click', function() {
        var btn = this;
        btn.disabled = true;
        btn.textContent = 'Testing...';
        API.post('/api/stations/' + stationId + '/test', {}).then(function(res) {
          if (res.ok) {
            showToast('Connection successful', 'success');
          } else {
            showToast('Test failed: ' + (res.error || 'unknown error'), 'error');
          }
        }).catch(function(err) {
          showToast('Test failed: ' + err.message, 'error');
        }).then(function() {
          btn.disabled = false;
          btn.textContent = 'Test Connection';
        });
      });

      document.getElementById('sf-delete').addEventListener('click', function() {
        if (!confirm('Delete this station? All linked equipment and QR codes will also be deleted.')) return;
        var btn = this;
        btn.disabled = true;
        API.del('/api/stations/' + stationId).then(function() {
          showToast('Station deleted', 'success');
          navigate('#/admin/stations');
        }).catch(function(err) {
          showToast('Error: ' + err.message, 'error');
          btn.disabled = false;
        });
      });
    }
  }).catch(function(err) {
    var area = document.getElementById('station-form-area');
    if (area) area.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load data.</p></div>';
  });
}

function buildStationBody() {
  var body = {
    name: document.getElementById('sf-name').value.trim(),
    host: document.getElementById('sf-host').value.trim(),
    port: parseInt(document.getElementById('sf-port').value, 10) || 443,
    protocol: document.querySelector('input[name="sf-protocol"]:checked').value,
    connectorType: 'niagara'
  };
  var username = document.getElementById('sf-username').value.trim();
  var password = document.getElementById('sf-password').value;
  if (username) body.username = username;
  if (password) body.password = password;
  return body;
}

/* ---- Equipment List ---- */

function renderEquipmentList(container) {
  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div class="section-header">' +
        '<span class="section-label">Equipment</span>' +
        '<a href="#/admin/equipment/add" class="btn btn-sm btn-primary">+ Add</a>' +
      '</div>' +
      '<div id="equipment-list"><div class="loading"><div class="spinner"></div><span>Loading equipment...</span></div></div>' +
    '</div>';

  Promise.all([
    API.get('/api/admin/equipment'),
    API.get('/api/stations')
  ]).then(function(results) {
    var equipment = results[0] || [];
    var stations = results[1] || [];
    var listEl = document.getElementById('equipment-list');
    if (!listEl) return;

    var stationMap = {};
    stations.forEach(function(s) { stationMap[s.id] = s.name; });

    if (!equipment.length) {
      listEl.innerHTML = '<div class="empty-state"><p>No equipment configured yet.</p></div>';
      return;
    }

    listEl.innerHTML = equipment.map(function(eq) {
      var name = eq.equipmentName || eq.name || 'Unnamed';
      return '<div class="card" style="cursor:pointer" data-qrid="' + escapeAttr(eq.qrId) + '">' +
        '<div class="flex flex-between flex-center">' +
          '<div style="flex:1;min-width:0">' +
            '<h3>' + escapeHtml(name) + '</h3>' +
            '<small class="mono" style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' +
              escapeHtml(eq.equipmentPath || '') +
            '</small>' +
            (stationMap[eq.stationId]
              ? '<small class="text-tertiary">' + escapeHtml(stationMap[eq.stationId]) + '</small>'
              : '') +
          '</div>' +
          '<div class="flex gap-1">' +
            '<a href="#/equipment/' + escapeAttr(eq.qrId) + '" class="btn btn-sm btn-outline eq-view-btn" title="View live data">View</a>' +
            '<button class="btn btn-sm btn-outline eq-qr-btn" data-qrid="' + escapeAttr(eq.qrId) + '">QR</button>' +
          '</div>' +
        '</div>' +
      '</div>';
    }).join('');

    listEl.querySelectorAll('.card').forEach(function(card) {
      card.addEventListener('click', function(e) {
        if (e.target.closest('.eq-qr-btn') || e.target.closest('.eq-view-btn')) return;
        navigate('#/admin/equipment/' + card.getAttribute('data-qrid'));
      });
    });

    listEl.querySelectorAll('.eq-qr-btn').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        navigate('#/admin/equipment/' + btn.getAttribute('data-qrid') + '/qr');
      });
    });
  }).catch(function() {
    var listEl = document.getElementById('equipment-list');
    if (listEl) listEl.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load equipment.</p></div>';
  });
}

/* ---- Equipment Form (add/edit) ---- */

function renderEquipmentForm(container, qrId) {
  var isEdit = !!qrId;

  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin/equipment" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div class="section-header">' +
        '<span class="section-label">' + (isEdit ? 'Edit Equipment' : 'Add Equipment') + '</span>' +
      '</div>' +
      '<div id="eq-form-area"><div class="loading"><div class="spinner"></div></div></div>' +
    '</div>';

  var stationsPromise = API.get('/api/stations');
  var eqPromise = isEdit ? API.get('/api/admin/equipment/' + qrId) : Promise.resolve(null);

  Promise.all([stationsPromise, eqPromise]).then(function(results) {
    var stations = results[0] || [];
    var eq = results[1];
    var area = document.getElementById('eq-form-area');
    if (!area) return;

    var stationOptions = stations.map(function(s) {
      var selected = eq && eq.stationId === s.id ? ' selected' : '';
      return '<option value="' + escapeAttr(s.id) + '"' + selected + '>' + escapeHtml(s.name) + '</option>';
    }).join('');

    var pointPaths = '';
    if (eq && eq.pointPaths && Array.isArray(eq.pointPaths)) {
      pointPaths = eq.pointPaths.join('\n');
    }

    area.innerHTML =
      '<form id="eq-form">' +
        '<div class="form-group">' +
          '<label for="eq-station">Station</label>' +
          '<select id="eq-station"' + (isEdit ? ' disabled' : '') + '>' +
            '<option value="">Select a station...</option>' +
            stationOptions +
          '</select>' +
        '</div>' +
        '<div class="form-group">' +
          '<button type="button" id="eq-browse" class="btn btn-outline btn-block">Browse Equipment</button>' +
          '<div id="eq-browse-selection" class="mt-1" style="display:none">' +
            '<small class="text-accent mono">Equipment selected from tree</small>' +
          '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="eq-name">Equipment Name</label>' +
          '<input type="text" id="eq-name" value="' + escapeAttr(eq ? eq.name : '') + '" required>' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="eq-path">Equipment Path</label>' +
          '<input type="text" id="eq-path" class="mono" value="' + escapeAttr(eq ? eq.equipmentPath || '' : '') + '">' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="eq-bql">BQL Query</label>' +
          '<textarea id="eq-bql" class="mono">' + escapeHtml(eq ? eq.bqlQuery || '' : '') + '</textarea>' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="eq-points">Point Paths <small>(one per line)</small></label>' +
          '<textarea id="eq-points" class="mono">' + escapeHtml(pointPaths) + '</textarea>' +
        '</div>' +
        '<div class="form-group">' +
          '<label for="eq-location">Location <small>(optional)</small></label>' +
          '<input type="text" id="eq-location" value="' + escapeAttr(eq ? eq.location || '' : '') + '">' +
        '</div>' +
        '<div class="flex gap-2 mt-3">' +
          '<button type="submit" class="btn btn-primary">Save</button>' +
          (isEdit ? '<a href="#/admin/equipment/' + escapeAttr(qrId) + '/qr" class="btn btn-outline">View QR</a>' : '') +
        '</div>' +
        (isEdit
          ? '<div class="mt-4"><button type="button" id="eq-delete" class="btn btn-danger btn-block">Delete Equipment</button></div>'
          : '') +
      '</form>';

    // Browse equipment button
    document.getElementById('eq-browse').addEventListener('click', function() {
      var stationId = document.getElementById('eq-station').value;
      if (!stationId) {
        showToast('Select a station first', 'error');
        return;
      }
      openTreeBrowser(stationId, function(selection) {
        document.getElementById('eq-name').value = selection.name;
        document.getElementById('eq-path').value = selection.path;
        var selEl = document.getElementById('eq-browse-selection');
        selEl.style.display = '';
        selEl.innerHTML = '<small class="text-accent mono">Selected: ' + escapeHtml(selection.name) +
          (selection.pointCount ? ' (' + selection.pointCount + ' points)' : '') + '</small>';
      });
    });

    // Submit
    document.getElementById('eq-form').addEventListener('submit', function(e) {
      e.preventDefault();
      var body = buildEquipmentBody();
      if (!isEdit && !body.stationId) {
        showToast('Select a station', 'error');
        return;
      }
      var btn = e.target.querySelector('[type="submit"]');
      btn.disabled = true;
      btn.textContent = 'Saving...';

      var promise = isEdit
        ? API.put('/api/admin/equipment/' + qrId, body)
        : API.post('/api/admin/equipment', body);

      promise.then(function(res) {
        showToast('Equipment saved', 'success');
        if (!isEdit && res && res.qrId) {
          navigate('#/admin/equipment/' + res.qrId + '/qr');
        } else {
          navigate('#/admin/equipment');
        }
      }).catch(function(err) {
        showToast('Error: ' + err.message, 'error');
        btn.disabled = false;
        btn.textContent = 'Save';
      });
    });

    // Delete
    if (isEdit) {
      document.getElementById('eq-delete').addEventListener('click', function() {
        if (!confirm('Delete this equipment and its QR code?')) return;
        var btn = this;
        btn.disabled = true;
        API.del('/api/admin/equipment/' + qrId).then(function() {
          showToast('Equipment deleted', 'success');
          navigate('#/admin/equipment');
        }).catch(function(err) {
          showToast('Error: ' + err.message, 'error');
          btn.disabled = false;
        });
      });
    }
  }).catch(function() {
    var area = document.getElementById('eq-form-area');
    if (area) area.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load data.</p></div>';
  });
}

function buildEquipmentBody() {
  var pointsRaw = document.getElementById('eq-points').value.trim();
  var pointPaths = pointsRaw ? pointsRaw.split('\n').map(function(l) { return l.trim(); }).filter(Boolean) : [];

  var body = {
    equipmentName: document.getElementById('eq-name').value.trim(),
    equipmentPath: document.getElementById('eq-path').value.trim(),
    bqlQuery: document.getElementById('eq-bql').value.trim(),
    pointPaths: pointPaths,
    location: document.getElementById('eq-location').value.trim()
  };

  var stationSelect = document.getElementById('eq-station');
  if (!stationSelect.disabled && stationSelect.value) {
    body.stationId = parseInt(stationSelect.value, 10);
  }
  return body;
}

/* ---- QR Code View ---- */

function renderQrView(container, qrId) {
  container.innerHTML =
    '<div class="container">' +
      '<a href="#/admin/equipment" class="btn btn-sm mb-3">&larr; Back</a>' +
      '<div id="qr-view-area"><div class="loading"><div class="spinner"></div></div></div>' +
    '</div>';

  API.get('/api/admin/equipment/' + qrId).then(function(eq) {
    var area = document.getElementById('qr-view-area');
    if (!area) return;

    area.innerHTML =
      '<h1>' + escapeHtml(eq.name) + '</h1>' +
      (eq.location ? '<p>' + escapeHtml(eq.location) + '</p>' : '') +
      '<div style="background:#fff;border-radius:12px;padding:16px;text-align:center;margin:16px 0">' +
        '<img src="' + qrImageSrc(qrId) + '" alt="QR Code" ' +
          'style="max-width:280px;width:100%;image-rendering:pixelated">' +
      '</div>' +
      '<div class="flex gap-2">' +
        '<button id="qr-print" class="btn btn-primary btn-block">Print QR Code</button>' +
      '</div>' +
      '<div class="mt-2">' +
        '<a href="#/admin/equipment/' + escapeAttr(qrId) + '" class="btn btn-outline btn-block">Edit Equipment</a>' +
      '</div>';

    document.getElementById('qr-print').addEventListener('click', function() {
      window.print();
    });
  }).catch(function() {
    var area = document.getElementById('qr-view-area');
    if (area) area.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load equipment.</p></div>';
  });
}

/* ---- Helpers ---- */

// qrImageSrc builds the QR PNG URL, appending ?host= if admin saved an override.
function qrImageSrc(qrId) {
  var base = '/api/admin/equipment/' + encodeURIComponent(qrId) + '/qr.png';
  var host = localStorage.getItem('qr-host-override');
  if (host) base += '?host=' + encodeURIComponent(host);
  return base;
}

function escapeAttr(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// escapeHtml is defined in scanner.js; provide fallback if loaded first
if (typeof escapeHtml === 'undefined') {
  window.escapeHtml = function(text) {
    var el = document.createElement('span');
    el.textContent = text;
    return el.innerHTML;
  };
}
