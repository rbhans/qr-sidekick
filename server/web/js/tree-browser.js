/* ============================================
   QR Sidekick — Station Tree Browser Modal
   ============================================ */

function openTreeBrowser(stationId, onSelect) {
  // Create modal backdrop
  var backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop';
  backdrop.style.alignItems = 'stretch';

  var modal = document.createElement('div');
  modal.className = 'modal';
  modal.style.maxWidth = '500px';
  modal.style.maxHeight = '100%';
  modal.style.margin = 'auto';
  modal.style.display = 'flex';
  modal.style.flexDirection = 'column';

  modal.innerHTML =
    '<div class="flex flex-between flex-center mb-3">' +
      '<span class="section-label" style="font-family:\'JetBrains Mono\',monospace;font-size:11px;text-transform:uppercase;letter-spacing:1.2px;color:var(--text-tertiary)">Browse Equipment</span>' +
      '<button id="tree-close" class="btn btn-sm">&times; Close</button>' +
    '</div>' +
    '<div id="tree-content" style="flex:1;overflow-y:auto">' +
      '<div class="loading"><div class="spinner"></div><span>Loading tree...</span></div>' +
    '</div>';

  backdrop.appendChild(modal);
  document.body.appendChild(backdrop);

  function closeModal() {
    backdrop.remove();
  }

  // Close on backdrop click (outside modal)
  backdrop.addEventListener('click', function(e) {
    if (e.target === backdrop) closeModal();
  });

  // Close button
  modal.querySelector('#tree-close').addEventListener('click', closeModal);

  // Escape key
  function onKeyDown(e) {
    if (e.key === 'Escape') {
      closeModal();
      document.removeEventListener('keydown', onKeyDown);
    }
  }
  document.addEventListener('keydown', onKeyDown);

  // Fetch tree — server returns the root TreeNode; iterate its children.
  API.get('/api/stations/' + stationId + '/tree').then(function(root) {
    var content = document.getElementById('tree-content');
    if (!content) return;

    var children = (root && root.children) || [];
    if (!children.length) {
      content.innerHTML = '<div class="empty-state"><p>No equipment found under /Drivers on this station.</p></div>';
      return;
    }

    content.innerHTML = '';
    renderTreeNodes(content, children, 0, true, onSelect, closeModal);
  }).catch(function(err) {
    var content = document.getElementById('tree-content');
    if (content) {
      content.innerHTML = '<div class="empty-state"><p class="text-error">Failed to load tree: ' +
        escapeHtml(err.message || 'unknown error') + '</p></div>';
    }
  });
}

function renderTreeNodes(parentEl, nodes, depth, expanded, onSelect, closeModal) {
  nodes.forEach(function(node) {
    var row = document.createElement('div');
    row.className = 'tree-node';
    if (node.isEquipment) row.classList.add('tree-equipment');
    row.style.paddingLeft = (12 + depth * 16) + 'px';

    var hasChildren = node.children && node.children.length > 0;
    var isExpanded = depth === 0; // top level starts expanded

    // Arrow/icon
    var arrow = '';
    if (!node.isEquipment && hasChildren) {
      arrow = '<span class="tree-node-icon tree-arrow" style="transition:transform 0.15s;display:inline-block' +
        (isExpanded ? ';transform:rotate(90deg)' : '') + '">&#9654;</span>';
    } else if (node.isEquipment) {
      arrow = '<span class="tree-node-icon" style="color:var(--accent)">&#9670;</span>';
    } else {
      arrow = '<span class="tree-indent"></span>';
    }

    var label = '<span class="tree-node-label">' + escapeHtml(node.name || node.displayName || '') + '</span>';

    var meta = '';
    if (node.isEquipment) {
      var pointCount = node.pointCount || (node.points ? node.points.length : 0);
      meta = '<span class="badge" style="margin-left:auto;flex-shrink:0">' + pointCount + ' pts</span>';
    }

    row.innerHTML = arrow + label + meta;

    // Equipment path subtitle
    if (node.isEquipment && node.path) {
      var pathEl = document.createElement('div');
      pathEl.className = 'mono';
      pathEl.style.cssText = 'font-size:10px;color:var(--text-tertiary);padding-left:' + (12 + depth * 16 + 24) + 'px;padding-bottom:4px';
      pathEl.textContent = node.path;
      var wrapper = document.createDocumentFragment();
      wrapper.appendChild(row);
      wrapper.appendChild(pathEl);

      // Equipment click - select
      row.style.background = 'rgba(192,134,33,0.08)';
      row.style.cursor = 'pointer';
      row.addEventListener('click', function() {
        onSelect({
          name: node.name || node.displayName || '',
          path: node.path || '',
          pointCount: node.pointCount || (node.points ? node.points.length : 0)
        });
        closeModal();
      });
      pathEl.style.cursor = 'pointer';
      pathEl.addEventListener('click', function() {
        row.click();
      });

      parentEl.appendChild(wrapper);
    } else if (node.isEquipment) {
      // Equipment without path
      row.style.background = 'rgba(192,134,33,0.08)';
      row.style.cursor = 'pointer';
      row.addEventListener('click', function() {
        onSelect({
          name: node.name || node.displayName || '',
          path: node.path || '',
          pointCount: node.pointCount || (node.points ? node.points.length : 0)
        });
        closeModal();
      });
      parentEl.appendChild(row);
    } else {
      // Folder node
      parentEl.appendChild(row);

      if (hasChildren) {
        var childContainer = document.createElement('div');
        childContainer.style.display = isExpanded ? '' : 'none';
        parentEl.appendChild(childContainer);

        renderTreeNodes(childContainer, node.children, depth + 1, false, onSelect, closeModal);

        row.style.cursor = 'pointer';
        row.addEventListener('click', function() {
          var arrowEl = row.querySelector('.tree-arrow');
          if (childContainer.style.display === 'none') {
            childContainer.style.display = '';
            if (arrowEl) arrowEl.style.transform = 'rotate(90deg)';
          } else {
            childContainer.style.display = 'none';
            if (arrowEl) arrowEl.style.transform = 'rotate(0deg)';
          }
        });
      }
    }
  });
}
