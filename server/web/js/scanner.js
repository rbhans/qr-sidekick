/* ============================================
   QRBAS — Scanner View
   ============================================ */

let currentScanner = null;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const RECENT_SCANS_KEY = 'qr_recent_scans';
const MAX_RECENT_SCANS = 20;

function getRecentScans() {
  try {
    return JSON.parse(localStorage.getItem(RECENT_SCANS_KEY)) || [];
  } catch (_) {
    return [];
  }
}

function saveRecentScan(qrId, name) {
  const scans = getRecentScans().filter(s => s.qrId !== qrId);
  scans.unshift({ qrId, name: name || qrId, timestamp: Date.now() });
  if (scans.length > MAX_RECENT_SCANS) scans.length = MAX_RECENT_SCANS;
  localStorage.setItem(RECENT_SCANS_KEY, JSON.stringify(scans));
}

function timeAgo(ts) {
  const diff = Date.now() - ts;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return mins + 'm ago';
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return hrs + 'h ago';
  const days = Math.floor(hrs / 24);
  return days + 'd ago';
}

function cleanupScanner() {
  if (currentScanner) {
    try {
      currentScanner.clear();
    } catch (_) {
      // scanner may already be cleared
    }
    currentScanner = null;
  }
}

function renderScanner(container) {
  cleanupScanner();

  const recentScans = getRecentScans();

  container.innerHTML =
    '<div class="container">' +
      '<div class="section-header">' +
        '<span class="section-label">Scanner</span>' +
      '</div>' +
      '<div class="scanner-container">' +
        '<div id="qr-reader"></div>' +
      '</div>' +
      (recentScans.length > 0
        ? '<div class="section-header mt-3">' +
            '<span class="section-label">Recent Scans</span>' +
            '<span class="section-right">' + recentScans.length + '</span>' +
          '</div>' +
          '<div id="recent-scans">' +
            recentScans.map(function(s) {
              return '<div class="card" data-qrid="' + s.qrId + '" style="cursor:pointer">' +
                '<div class="card-title">' + escapeHtml(s.name) + '</div>' +
                '<small class="mono">' + timeAgo(s.timestamp) + '</small>' +
              '</div>';
            }).join('') +
          '</div>'
        : '') +
    '</div>';

  // Attach click handlers to recent scan cards
  var cards = container.querySelectorAll('#recent-scans .card');
  cards.forEach(function(card) {
    card.addEventListener('click', function() {
      var qrId = card.getAttribute('data-qrid');
      navigate('#/equipment/' + qrId);
    });
  });

  // Initialize QR scanner
  if (typeof Html5QrcodeScanner !== 'undefined') {
    var scannerConfig = {
      fps: 10,
      qrbox: { width: 200, height: 200 },
      aspectRatio: 1.0,
      rememberLastUsedCamera: true,
      showTorchButtonIfSupported: true
    };

    currentScanner = new Html5QrcodeScanner('qr-reader', scannerConfig, false);

    currentScanner.render(function onSuccess(decodedText) {
      if (UUID_RE.test(decodedText)) {
        cleanupScanner();
        navigate('#/equipment/' + decodedText);
      } else {
        showToast('Invalid QR code format', 'error');
      }
    }, function onError() {
      // Scan errors are expected while scanning; ignore
    });
  }
}

function escapeHtml(text) {
  var el = document.createElement('span');
  el.textContent = text;
  return el.innerHTML;
}
