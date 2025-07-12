// ===================================
// EMERGENCY SERVICES TABLET UI
// Modern JavaScript Interface
// ===================================

let currentData = null;
let dutyTimer = null;
let dutyStartTime = null;
let currentJob = "fire"; // Will be set dynamically
let activeTab = "duty";

// ===================================
// IMMEDIATE INITIALIZATION - KOMPLETT TRANSPARENT
// ===================================

// SOFORT beim Laden der Seite - aggressiv transparent machen
(function () {
  console.log("Emergency Services UI - Immediate transparent setup");

  // HTML und Body sofort transparent machen - AGGRESSIV
  function makeTransparent() {
    const elementsToMakeTransparent = [
      document.documentElement,
      document.body,
      document.querySelector("html"),
      document.querySelector("body"),
    ].filter(Boolean);

    elementsToMakeTransparent.forEach((element) => {
      if (element) {
        element.style.background = "transparent";
        element.style.backgroundColor = "transparent";
        element.style.backgroundImage = "none";
        element.style.backdropFilter = "none";
      }
    });
  }

  // Sofort ausführen
  makeTransparent();

  // Bei DOM-Load nochmal
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", makeTransparent);
  } else {
    makeTransparent();
  }

  // NUR BASIS CSS - SEHR MINIMAL
  const style = document.createElement("style");
  style.textContent = `
        html, body, * {
            background: transparent !important;
            background-color: transparent !important;
            background-image: none !important;
        }
        
        html, body {
            backdrop-filter: none !important;
        }
        
        #tabletContainer { 
            display: none;
            visibility: hidden;
            opacity: 0;
            pointer-events: none;
        }
        #quickHUD { 
            display: none;
            visibility: hidden;
            opacity: 0;
            pointer-events: none;
        }
        #controlsHint {
            display: none;
            visibility: hidden;
            opacity: 0;
            pointer-events: none;
        }
    `;
  document.head.appendChild(style);

  console.log("Aggressive transparency applied to all elements");
})();

// ===================================
// INITIALIZATION
// ===================================

document.addEventListener("DOMContentLoaded", function () {
  console.log("Emergency Services Tablet UI loaded");

  // SOFORT Body und HTML transparent machen falls nicht schon geschehen
  document.documentElement.style.background = "transparent";
  document.documentElement.style.backgroundColor = "transparent";
  document.body.style.background = "transparent";
  document.body.style.backgroundColor = "transparent";

  // WICHTIG: UI beim Start komplett verstecken mit display: none
  const tablet = document.getElementById("tabletContainer");
  const hud = document.getElementById("quickHUD");
  const hint = document.getElementById("controlsHint");

  if (tablet) {
    tablet.style.display = "none";
    tablet.style.visibility = "hidden";
    tablet.style.opacity = "0";
    tablet.style.pointerEvents = "none";
    tablet.classList.add("hidden");
    tablet.classList.remove("show");
    console.log("Tablet set to display: none on load");
  }

  if (hud) {
    hud.style.display = "none";
    hud.style.visibility = "hidden";
    hud.style.opacity = "0";
    hud.style.pointerEvents = "none";
    hud.classList.add("hidden");
    hud.classList.remove("show");
    console.log("HUD set to display: none on load");
  }

  if (hint) {
    hint.style.display = "none";
    hint.style.visibility = "hidden";
    hint.style.opacity = "0";
    hint.style.pointerEvents = "none";
    hint.classList.add("hidden");
    hint.classList.remove("show");
    console.log("Hint set to display: none on load");
  }

  // Initialize time display
  updateCurrentTime();
  setInterval(updateCurrentTime, 1000);

  // Apply job-specific theme
  applyJobTheme(currentJob);

  // Set up keyboard shortcuts
  setupKeyboardShortcuts();

  // Initialize mock data
  initializeMockData();

  console.log("Emergency Services UI fully loaded and hidden");

  // WICHTIG: Signal an den Client dass NUI ready ist
  fetch(`https://${GetParentResourceName()}/nuiReady`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  })
    .then(() => {
      console.log("Notified client that NUI is ready");
    })
    .catch((error) => {
      console.error("Failed to notify client NUI ready:", error);
    });
});

// ===================================
// MESSAGE HANDLERS
// ===================================

window.addEventListener("message", function (event) {
  const data = event.data;

  switch (data.action) {
    case "showTablet":
      showTablet(data.data);
      break;
    case "hideTablet":
      hideTablet();
      break;
    case "forceShow":
      forceShowTablet();
      break;
    case "updateDutyStatus":
      updateDutyStatus(data.data);
      break;
    case "showQuickHUD":
      showQuickHUD(data.data);
      break;
    case "hideQuickHUD":
      hideQuickHUD();
      break;
    case "showControlsHint":
      showControlsHint();
      break;
    case "hideControlsHint":
      hideControlsHint();
      break;
    case "updateStats":
      updateStatsData(data.data);
      break;
    case "addActivity":
      addActivityItem(data.data);
      break;
    case "updateEquipment":
      updateEquipmentList(data.data);
      break;
    case "updateVehicles":
      updateVehicleList(data.data);
      break;
    default:
      break;
  }
});

// ===================================
// TABLET MANAGEMENT
// ===================================

function showTablet(data) {
  currentData = data;

  console.log("showTablet called with data:", data);

  if (data.job) {
    currentJob = data.job;
    applyJobTheme(currentJob);
  }

  // Update station information
  if (data.station) {
    document.getElementById("stationName").textContent =
      data.station.label || "Emergency Services";
    document.getElementById("stationCode").textContent = getStationCode(
      data.station.job
    );
    document.getElementById("currentStation").textContent =
      data.station.label || "Unknown Station";
  }

  // Update player information
  if (data.player) {
    updatePlayerInfo(data.player);
  }

  // Update duty status
  if (data.dutyStatus !== undefined) {
    updateDutyDisplay(data.dutyStatus);
  }

  // Show the tablet - FORCE SICHTBAR MACHEN
  const tablet = document.getElementById("tabletContainer");

  if (tablet) {
    // ALLES FORCIERT SICHTBAR MACHEN
    tablet.style.display = "block";
    tablet.style.visibility = "visible";
    tablet.style.opacity = "1";
    tablet.style.pointerEvents = "all";
    tablet.style.zIndex = "1000";

    // CSS Klassen
    tablet.classList.remove("hidden");
    tablet.classList.add("show");

    console.log("Tablet styles set - should be visible now");
    console.log("Tablet display:", tablet.style.display);
    console.log("Tablet visibility:", tablet.style.visibility);
    console.log("Tablet opacity:", tablet.style.opacity);

    // Notify client that tablet is open
    fetch(`https://${GetParentResourceName()}/tabletOpened`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });

    // Auto-focus on first interactive element
    setTimeout(() => {
      const firstBtn = tablet.querySelector("button");
      if (firstBtn) firstBtn.focus();
    }, 300);
  } else {
    console.error("Tablet element not found!");
  }
}

function hideTablet() {
  const tablet = document.getElementById("tabletContainer");

  if (tablet) {
    tablet.classList.remove("show");
    tablet.classList.add("hidden");

    // Nach transition alles verstecken
    setTimeout(() => {
      tablet.style.display = "none";
      tablet.style.visibility = "hidden";
      tablet.style.opacity = "0";
      tablet.style.pointerEvents = "none";
      console.log("Tablet fully hidden");
    }, 300);

    // Notify client that tablet is closed
    fetch(`https://${GetParentResourceName()}/tabletClosed`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });

    stopDutyTimer();
    currentData = null;
  }
}

function closeTablet() {
  // Send close event to client
  fetch(`https://${GetParentResourceName()}/closeTablet`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });

  hideTablet();
}

// ===================================
// TAB MANAGEMENT
// ===================================

function switchTab(tabName) {
  // Update tab buttons
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.remove("active");
  });
  document.querySelector(`[data-tab="${tabName}"]`).classList.add("active");

  // Update content panels
  document.querySelectorAll(".content-panel").forEach((panel) => {
    panel.classList.remove("active");
  });
  document.getElementById(`${tabName}Panel`).classList.add("active");

  activeTab = tabName;

  // Load tab-specific data
  loadTabData(tabName);
}

function loadTabData(tabName) {
  switch (tabName) {
    case "equipment":
      refreshEquipment();
      break;
    case "vehicles":
      refreshVehicles();
      break;
    case "stats":
      refreshStats();
      break;
  }
}

// ===================================
// DUTY MANAGEMENT
// ===================================

function updatePlayerInfo(playerData) {
  const elements = {
    officerName: playerData.name || "John Doe",
    officerRank: playerData.rank || "Officer",
    officerBadge: `Badge #${playerData.badge || "1234"}`,
    currentUnit: playerData.unit || getDefaultUnit(currentJob),
  };

  Object.entries(elements).forEach(([id, value]) => {
    const element = document.getElementById(id);
    if (element) element.textContent = value;
  });
}

function updateDutyDisplay(onDuty) {
  const statusBadge = document.getElementById("dutyStatusBadge");
  const toggleButton = document.getElementById("dutyToggleBtn");
  const dutyTimerEl = document.getElementById("dutyTimer");

  if (onDuty) {
    // On duty
    statusBadge.textContent = "On Duty";
    statusBadge.classList.add("on-duty");

    toggleButton.innerHTML = `
            <span class="btn-icon">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="6" y="4" width="4" height="16"></rect>
                    <rect x="14" y="4" width="4" height="16"></rect>
                </svg>
            </span>
            End Duty
        `;
    toggleButton.classList.add("end-duty");

    dutyTimerEl.style.display = "block";
    startDutyTimer();

    // Show quick HUD
    showQuickHUD({
      callsign: getDefaultUnit(currentJob),
      status: "Available",
    });
  } else {
    // Off duty
    statusBadge.textContent = "Off Duty";
    statusBadge.classList.remove("on-duty");

    toggleButton.innerHTML = `
            <span class="btn-icon">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
                </svg>
            </span>
            Start Duty
        `;
    toggleButton.classList.remove("end-duty");

    dutyTimerEl.style.display = "none";
    stopDutyTimer();

    // Hide quick HUD
    hideQuickHUD();
  }
}

function toggleDuty() {
  if (!currentData) return;

  const isOnDuty = document
    .getElementById("dutyStatusBadge")
    .classList.contains("on-duty");

  if (isOnDuty) {
    // End duty
    fetch(`https://${GetParentResourceName()}/endDuty`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        station: currentData.station?.id || "unknown",
      }),
    });
  } else {
    // Start duty
    fetch(`https://${GetParentResourceName()}/startDuty`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        station: currentData.station?.id || "unknown",
      }),
    });
  }
}

// ===================================
// DUTY TIMER
// ===================================

function startDutyTimer() {
  dutyStartTime = new Date();
  dutyTimer = setInterval(updateDutyTimer, 1000);
}

function stopDutyTimer() {
  if (dutyTimer) {
    clearInterval(dutyTimer);
    dutyTimer = null;
    dutyStartTime = null;
  }
}

function updateDutyTimer() {
  if (!dutyStartTime) return;

  const now = new Date();
  const elapsed = Math.floor((now - dutyStartTime) / 1000);

  const timeString = formatTime(elapsed);

  // Update main timer
  const timerDisplay = document.getElementById("timerDisplay");
  if (timerDisplay) timerDisplay.textContent = timeString;

  // Update HUD timer
  const hudTimer = document.getElementById("hudDutyTime");
  if (hudTimer) hudTimer.textContent = timeString;
}

function formatTime(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  return `${hours.toString().padStart(2, "0")}:${minutes
    .toString()
    .padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
}

// ===================================
// QUICK HUD
// ===================================

function showQuickHUD(data) {
  const hud = document.getElementById("quickHUD");

  if (data.callsign) {
    document.getElementById("hudCallsign").textContent = data.callsign;
  }

  if (data.status) {
    document.getElementById("hudStatus").textContent = data.status;
  }

  // Show HUD with display and classes
  hud.style.display = "block"; // Erst display setzen
  hud.classList.remove("hidden");
  hud.classList.add("show", "fade-in");

  console.log("Quick HUD shown");
}

function hideQuickHUD() {
  const hud = document.getElementById("quickHUD");
  hud.classList.remove("show", "fade-in");
  hud.classList.add("hidden");

  // Nach transition display none setzen
  setTimeout(() => {
    hud.style.display = "none";
    console.log("Quick HUD hidden");
  }, 300);
}

// ===================================
// CONTROLS HINT MANAGEMENT
// ===================================

function showControlsHint() {
  const hint = document.getElementById("controlsHint");
  hint.style.display = "block";
  hint.classList.remove("hidden");
  hint.classList.add("show");
  console.log("Controls hint shown");
}

function hideControlsHint() {
  const hint = document.getElementById("controlsHint");
  hint.classList.remove("show");
  hint.classList.add("hidden");

  setTimeout(() => {
    hint.style.display = "none";
    console.log("Controls hint hidden");
  }, 300);
}

// ===================================
// FORCE SHOW (DEBUG)
// ===================================

function forceShowTablet() {
  console.log("Force show tablet called");

  const tablet = document.getElementById("tabletContainer");

  if (tablet) {
    // RESPONSIVE GROESSE BERECHNEN
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    let width, height;

    if (vw >= 1920) {
      width = Math.min(vw * 0.8, 1200);
      height = Math.min(vh * 0.8, 800);
    } else if (vw >= 1200) {
      width = Math.min(vw * 0.85, 1000);
      height = Math.min(vh * 0.85, 700);
    } else if (vw >= 992) {
      width = Math.min(vw * 0.9, 900);
      height = Math.min(vh * 0.85, 650);
    } else if (vw >= 768) {
      width = vw * 0.95;
      height = vh * 0.9;
    } else if (vw >= 576) {
      width = vw * 0.98;
      height = vh * 0.95;
    } else {
      // Mobile: Fullscreen
      width = vw;
      height = vh;
    }

    // ALLE versteckenden Styles entfernen
    tablet.style.display = "block";
    tablet.style.visibility = "visible";
    tablet.style.opacity = "1";
    tablet.style.pointerEvents = "all";
    tablet.style.zIndex = "9999";
    tablet.style.position = "fixed";

    // Mobile: Fullscreen, Desktop: Centered
    if (vw <= 575) {
      tablet.style.top = "0";
      tablet.style.left = "0";
      tablet.style.transform = "none";
    } else {
      tablet.style.top = "50%";
      tablet.style.left = "50%";
      tablet.style.transform = "translate(-50%, -50%)";
    }

    tablet.style.width = width + "px";
    tablet.style.height = height + "px";

    // KEIN schwarzer Hintergrund - nur das Tablet-Frame
    tablet.style.background = "transparent";
    tablet.style.backgroundColor = "transparent";

    // CSS Klassen
    tablet.classList.remove("hidden");
    tablet.classList.add("show");

    console.log(
      `Tablet force shown - Size: ${width}x${height} (Screen: ${vw}x${vh})`
    );

    // Test data einfügen
    showTablet({
      station: { label: "Force Test Station", job: "fire", id: "force_test" },
      player: {
        name: "Force Test User",
        rank: "Force Rank",
        badge: 999,
        unit: "Force Unit",
      },
      job: "fire",
      dutyStatus: false,
    });
  } else {
    console.error("Tablet element not found in DOM!");

    // DOM Debugging
    console.log("Available elements:");
    console.log("Body children:", document.body.children);
    console.log("All elements with ID:", document.querySelectorAll("[id]"));
  }
}

// ===================================
// EQUIPMENT MANAGEMENT
// ===================================

function refreshEquipment() {
  // Request equipment data from client
  fetch(`https://${GetParentResourceName()}/getEquipment`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
}

function updateEquipmentList(equipmentData) {
  const grid = document.getElementById("equipmentGrid");
  if (!grid || !equipmentData) return;

  // Clear existing content except categories
  grid.innerHTML = "";

  // Group equipment by category
  const categories = groupEquipmentByCategory(equipmentData);

  Object.entries(categories).forEach(([categoryName, items]) => {
    const categoryDiv = createEquipmentCategory(categoryName, items);
    grid.appendChild(categoryDiv);
  });
}

function createEquipmentCategory(name, items) {
  const categoryDiv = document.createElement("div");
  categoryDiv.className = "equipment-category";

  categoryDiv.innerHTML = `
        <h3>${name}</h3>
        <div class="equipment-items">
            ${items
              .map(
                (item) => `
                <div class="equipment-item ${item.status}" onclick="selectEquipment('${item.id}')">
                    <div class="item-icon">${item.icon}</div>
                    <div class="item-info">
                        <div class="item-name">${item.name}</div>
                        <div class="item-status">${item.status}</div>
                    </div>
                </div>
            `
              )
              .join("")}
        </div>
    `;

  return categoryDiv;
}

function selectEquipment(equipmentId) {
  fetch(`https://${GetParentResourceName()}/selectEquipment`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ equipmentId }),
  });
}

// ===================================
// VEHICLE MANAGEMENT
// ===================================

function refreshVehicles() {
  fetch(`https://${GetParentResourceName()}/getVehicles`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
}

function updateVehicleList(vehicleData) {
  const grid = document.getElementById("vehicleGrid");
  if (!grid || !vehicleData) return;

  grid.innerHTML = vehicleData
    .map(
      (vehicle) => `
        <div class="vehicle-card ${vehicle.status}">
            <div class="vehicle-image">${vehicle.icon}</div>
            <div class="vehicle-info">
                <h3>${vehicle.name}</h3>
                <p>${vehicle.type}</p>
                <div class="vehicle-stats">
                    <span>Fuel: ${vehicle.fuel}%</span>
                    <span>Status: ${vehicle.status}</span>
                </div>
            </div>
            ${
              vehicle.status === "available"
                ? `<button class="spawn-btn" onclick="spawnVehicle('${vehicle.id}')">Spawn</button>`
                : `<button class="return-btn" onclick="returnVehicle('${vehicle.id}')">Return</button>`
            }
        </div>
    `
    )
    .join("");
}

function spawnVehicle(vehicleId) {
  fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ vehicleId }),
  });
}

function returnVehicle(vehicleId) {
  fetch(`https://${GetParentResourceName()}/returnVehicle`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ vehicleId }),
  });
}

// ===================================
// STATISTICS
// ===================================

function refreshStats() {
  fetch(`https://${GetParentResourceName()}/getStats`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
}

function updateStatsData(statsData) {
  if (!statsData) return;

  // Update stat cards
  const stats = {
    onDutyCount: statsData.onDuty || 0,
    callsToday: statsData.calls || 0,
    responseTime: statsData.responseTime || "0:00",
    unitsActive: statsData.activeUnits || 0,
  };

  Object.entries(stats).forEach(([id, value]) => {
    const element = document.getElementById(id);
    if (element) element.textContent = value;
  });
}

function updateStats(timeRange) {
  fetch(`https://${GetParentResourceName()}/updateStats`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ timeRange }),
  });
}

function addActivityItem(activity) {
  const activityList = document.getElementById("activityList");
  if (!activityList) return;

  const activityDiv = document.createElement("div");
  activityDiv.className = "activity-item";
  activityDiv.innerHTML = `
        <div class="activity-time">${activity.time}</div>
        <div class="activity-desc">${activity.description}</div>
    `;

  // Add to top of list
  activityList.insertBefore(activityDiv, activityList.firstChild);

  // Remove oldest items if too many
  while (activityList.children.length > 10) {
    activityList.removeChild(activityList.lastChild);
  }
}

// ===================================
// UTILITY FUNCTIONS
// ===================================

function updateCurrentTime() {
  const now = new Date();
  const timeString = now.toLocaleTimeString("en-US", {
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });

  const timeElement = document.getElementById("currentTime");
  if (timeElement) timeElement.textContent = timeString;
}

function applyJobTheme(job) {
  // Remove existing job classes
  document.body.classList.remove("job-fire", "job-ambulance", "job-police");

  // Add new job class
  document.body.classList.add(`job-${job}`);

  // Update connection status color
  const statusIndicator = document.getElementById("connectionStatus");
  if (statusIndicator) {
    statusIndicator.style.background = getJobColor(job);
    statusIndicator.style.boxShadow = `0 0 10px ${getJobColor(job)}`;
  }
}

function getJobColor(job) {
  const colors = {
    fire: "#dc3545",
    ambulance: "#28a745",
    police: "#007bff",
  };
  return colors[job] || "#007bff";
}

function getStationCode(job) {
  const codes = {
    fire: "FD-1",
    ambulance: "EMS-1",
    police: "PD-1",
  };
  return codes[job] || "UNIT-1";
}

function getDefaultUnit(job) {
  const units = {
    fire: "Engine 1",
    ambulance: "Medic 1",
    police: "Unit 1",
  };
  return units[job] || "Unit 1";
}

function groupEquipmentByCategory(equipment) {
  const categories = {};

  equipment.forEach((item) => {
    const category = item.category || "Miscellaneous";
    if (!categories[category]) {
      categories[category] = [];
    }
    categories[category].push(item);
  });

  return categories;
}

function setupKeyboardShortcuts() {
  document.addEventListener("keydown", function (event) {
    const tabletContainer = document.getElementById("tabletContainer");
    const isTabletVisible =
      tabletContainer && !tabletContainer.classList.contains("hidden");

    // Immer ESC handhaben um UI zu schließen
    if (event.key === "Escape") {
      if (isTabletVisible) {
        closeTablet();
      }
      return;
    }

    // F1 für direkten UI Test (nur im Debug)
    if (event.key === "F1") {
      console.log("F1 pressed - direct UI test");

      if (isTabletVisible) {
        hideTablet();
        console.log("Direct test: hiding tablet");
      } else {
        // DIREKT ZEIGEN ohne Client-Interaktion
        showTablet({
          station: { label: "Test Station", job: "fire", id: "test" },
          player: {
            name: "Test User",
            rank: "Test Rank",
            badge: 123,
            unit: "Test Unit",
          },
          job: "fire",
          dutyStatus: false,
        });
        console.log("Direct test: showing tablet");
      }
      return;
    }

    // Andere shortcuts nur wenn Tablet sichtbar ist
    if (!isTabletVisible) return;

    switch (event.key) {
      case "1":
        switchTab("duty");
        break;
      case "2":
        switchTab("equipment");
        break;
      case "3":
        switchTab("vehicles");
        break;
      case "4":
        switchTab("stats");
        break;
      case "Enter":
        if (activeTab === "duty") {
          toggleDuty();
        }
        break;
    }
  });
}

function initializeMockData() {
  // Initialize with some mock data for testing
  updateStatsData({
    onDuty: 12,
    calls: 8,
    responseTime: "4:32",
    activeUnits: 5,
  });

  // Add some mock activities
  const mockActivities = [
    { time: "14:23", description: "Officer Smith started duty at Station 1" },
    { time: "14:15", description: "Engine 1 responded to structure fire" },
    { time: "13:45", description: "Equipment check completed" },
  ];

  mockActivities.forEach((activity) => addActivityItem(activity));
}

// ===================================
// RESOURCE NAME HELPER
// ===================================

function GetParentResourceName() {
  return "fl_core"; // This should match your resource name
}

// ===================================
// ERROR HANDLING
// ===================================

window.addEventListener("error", function (event) {
  console.error("Tablet UI Error:", event.error);
});

// Prevent context menu
document.addEventListener("contextmenu", function (event) {
  event.preventDefault();
});
