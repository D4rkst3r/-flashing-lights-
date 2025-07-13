// ====================================================================
// FLASHING LIGHTS EMERGENCY SERVICES - MULTI-UNIT UI JAVASCRIPT
// NEUE FEATURES:
// 1. Zeigt assigned units bei jedem Call an
// 2. Ermöglicht mehrere Assignments pro Call
// 3. Verschiedene Button-States basierend auf Assignment-Status
// 4. Erweiterte Call-Status (pending/assigned/multi_assigned/in_progress/completed)
// ====================================================================

// Global state
let currentData = {};
let currentService = "";
let updateInterval = null;
let currentPlayerSource = null; // Track current player

// Service configurations
const serviceConfig = {
  fire: {
    icon: "fas fa-fire",
    color: "#e74c3c",
    name: "Fire Department",
  },
  police: {
    icon: "fas fa-shield-alt",
    color: "#3498db",
    name: "Police Department",
  },
  ems: {
    icon: "fas fa-ambulance",
    color: "#2ecc71",
    name: "Emergency Medical Services",
  },
};

// ====================================================================
// INITIALIZATION
// ====================================================================

document.addEventListener("DOMContentLoaded", function () {
  console.log("🚀 FL Emergency Services Multi-Unit UI loaded");

  // Initialize UI components
  initializeNavigation();
  initializeTime();

  // Hide all UIs initially
  hideAllUIs();
});

// ====================================================================
// MESSAGE HANDLING (ENHANCED FOR MULTI-UNIT)
// ====================================================================

// Listen for messages from client
window.addEventListener("message", function (event) {
  const data = event.data;
  console.log("📨 Received message:", data.type, data);

  switch (data.type) {
    case "showMDT":
      showMDT(data.data);
      break;

    case "hideUI":
      hideAllUIs();
      break;

    case "updateCalls":
      console.log("🔄 Updating calls with data:", data.data);
      updateActiveCalls(data.data);
      break;

    case "newCall":
      console.log("🆕 New call received:", data.callData);
      handleNewCall(data.callData);
      break;

    case "callAssigned":
      console.log("📞 Call assigned:", data.callData);
      handleCallAssigned(data.callData);
      break;

    case "callStatusChanged":
      console.log("📋 Call status changed:", data.callId, "->", data.newStatus);
      handleCallStatusChanged(data.callId, data.newStatus, data.callData);
      break;

    case "callCompleted":
      console.log("✅ Call completed:", data.callId);
      handleCallCompleted(data.callId);
      break;

    case "forceRefresh":
      console.log("🔁 Force refresh requested");
      updateActiveCalls(data.data);
      break;

    case "showNotification":
      showNotification(data.data);
      break;

    case "setPlayerSource":
      currentPlayerSource = data.source;
      console.log("👤 Player source set to:", currentPlayerSource);
      break;
  }
});

// ====================================================================
// CALL MANAGEMENT (ENHANCED FOR MULTI-UNIT)
// ====================================================================

function updateActiveCalls(calls) {
  console.log("🔄 updateActiveCalls called with:", calls);

  const callsList = document.getElementById("callsList");

  // Clear existing calls
  callsList.innerHTML = "";

  // Count calls by priority
  let highPriority = 0,
    mediumPriority = 0,
    lowPriority = 0;

  // Convert calls object to array and sort by priority and time
  const callsArray = Object.values(calls).sort((a, b) => {
    if (a.priority !== b.priority) {
      return a.priority - b.priority; // Higher priority first (1 = high)
    }
    return b.created_at - a.created_at; // Newer calls first
  });

  console.log("📊 Processed calls array:", callsArray);

  if (callsArray.length === 0) {
    callsList.innerHTML = `
            <div class="no-calls">
                <i class="fas fa-phone-slash"></i>
                <p>No active emergency calls</p>
            </div>
        `;

    // Update call stats to zero
    updateCallStats(0, 0, 0);
    return;
  }

  // Create call items
  callsArray.forEach((call) => {
    const callElement = createCallElement(call);
    callsList.appendChild(callElement);

    // Count priorities
    switch (call.priority) {
      case 1:
        highPriority++;
        break;
      case 2:
        mediumPriority++;
        break;
      case 3:
        lowPriority++;
        break;
    }
  });

  // Update call stats
  updateCallStats(highPriority, mediumPriority, lowPriority);

  console.log(
    "📈 Call stats updated - High:",
    highPriority,
    "Medium:",
    mediumPriority,
    "Low:",
    lowPriority
  );
}

function createCallElement(call) {
  console.log("🏗️ Creating call element for:", call.id, "Status:", call.status);

  const callDiv = document.createElement("div");
  callDiv.className = `call-item priority-${call.priority}`;
  callDiv.setAttribute("data-call-id", call.id);

  const priorityText = getPriorityText(call.priority);
  const priorityClass = getPriorityClass(call.priority);
  const timeAgo = getTimeAgo(call.created_at);

  // ENHANCED: Create assigned units display
  const assignedUnitsHtml = createAssignedUnitsDisplay(call.unit_details || []);

  // ENHANCED: Determine which buttons to show based on call status and assignment
  let actionButtons = getActionButtonsForStatus(
    call.status,
    call.id,
    call.unit_details || [],
    call.max_units || 4
  );

  callDiv.innerHTML = `
        <div class="call-header">
            <span class="call-id">${call.id}</span>
            <span class="call-priority ${priorityClass}">${priorityText}</span>
        </div>
        <div class="call-type">${formatCallType(call.type)}</div>
        <div class="call-description">${call.description}</div>
        <div class="call-meta">
            <span><i class="fas fa-clock"></i> ${timeAgo}</span>
            <span><i class="fas fa-map-marker-alt"></i> Emergency Location</span>
            <span><i class="fas fa-info-circle"></i> Status: <strong>${getStatusDisplayText(
              call.status
            )}</strong></span>
        </div>
        ${assignedUnitsHtml}
        <div class="call-actions">
            ${actionButtons}
        </div>
    `;

  console.log(
    "✅ Created call element for:",
    call.id,
    "with status:",
    call.status,
    "units:",
    call.unit_details ? call.unit_details.length : 0
  );
  return callDiv;
}

// NEW: Create assigned units display
function createAssignedUnitsDisplay(unitDetails) {
  if (!unitDetails || unitDetails.length === 0) {
    return `
            <div class="assigned-units">
                <div class="units-header">
                    <i class="fas fa-users"></i>
                    <span>No Units Assigned</span>
                </div>
            </div>
        `;
  }

  let unitsHtml = `
        <div class="assigned-units">
            <div class="units-header">
                <i class="fas fa-users"></i>
                <span>Assigned Units (${unitDetails.length})</span>
            </div>
            <div class="units-list">
    `;

  unitDetails.forEach((unit) => {
    unitsHtml += `
            <div class="unit-item">
                <div class="unit-callsign">${unit.callsign}</div>
                <div class="unit-name">${unit.name}</div>
                <div class="unit-rank">${unit.rank}</div>
            </div>
        `;
  });

  unitsHtml += `
            </div>
        </div>
    `;

  return unitsHtml;
}

// ENHANCED: Get action buttons based on call status and assignment
function getActionButtonsForStatus(status, callId, unitDetails, maxUnits) {
  console.log(
    "🔘 Getting action buttons for status:",
    status,
    "callId:",
    callId,
    "units:",
    unitDetails.length,
    "max:",
    maxUnits
  );

  const isPlayerAssigned =
    currentPlayerSource &&
    unitDetails.some((unit) => unit.source === currentPlayerSource);
  const canAssignMore = unitDetails.length < maxUnits;

  switch (status) {
    case "pending":
      return `
                <button class="call-btn assign" onclick="assignToCall('${callId}')">
                    <i class="fas fa-user-plus"></i> Assign to Me
                </button>
            `;

    case "assigned":
    case "multi_assigned":
      let buttons = "";

      if (!isPlayerAssigned && canAssignMore) {
        // Player can still assign themselves
        buttons += `
                    <button class="call-btn assign secondary" onclick="assignToCall('${callId}')">
                        <i class="fas fa-user-plus"></i> Join Response
                    </button>
                `;
      }

      if (isPlayerAssigned) {
        // Player is assigned - show progress/complete buttons
        if (status !== "in_progress") {
          buttons += `
                        <button class="call-btn start-work" onclick="startWorkOnCall('${callId}')">
                            <i class="fas fa-play"></i> Start Work
                        </button>
                    `;
        }
        buttons += `
                    <button class="call-btn complete" onclick="completeCall('${callId}')">
                        <i class="fas fa-check"></i> Complete Call
                    </button>
                `;
      }

      if (!canAssignMore && !isPlayerAssigned) {
        buttons += `
                    <span class="call-status max-units">
                        <i class="fas fa-users"></i> Maximum Units Assigned
                    </span>
                `;
      }

      return (
        buttons ||
        `
                <span class="call-status assigned">
                    <i class="fas fa-user-check"></i> Units Assigned
                </span>
            `
      );

    case "in_progress":
      if (isPlayerAssigned) {
        return `
                    <button class="call-btn complete" onclick="completeCall('${callId}')">
                        <i class="fas fa-check"></i> Complete Call
                    </button>
                `;
      } else {
        return `
                    <span class="call-status in-progress">
                        <i class="fas fa-cogs"></i> Work in Progress
                    </span>
                `;
      }

    case "completed":
      return `
                <span class="call-status completed">
                    <i class="fas fa-check-circle"></i> Completed
                </span>
            `;

    default:
      console.warn("⚠️ Unknown call status:", status);
      return `
                <span class="call-status unknown">
                    <i class="fas fa-question-circle"></i> Unknown Status
                </span>
            `;
  }
}

// NEW: Get display text for status
function getStatusDisplayText(status) {
  const statusTexts = {
    pending: "PENDING",
    assigned: "ASSIGNED",
    multi_assigned: "MULTIPLE UNITS",
    in_progress: "IN PROGRESS",
    completed: "COMPLETED",
  };

  return statusTexts[status] || status.toUpperCase();
}

// Enhanced event handlers
function handleNewCall(callData) {
  console.log("🆕 Handling new call:", callData.id);

  if (!currentData.activeCalls) {
    currentData.activeCalls = {};
  }
  currentData.activeCalls[callData.id] = callData;

  updateActiveCalls(currentData.activeCalls);
}

function handleCallAssigned(callData) {
  console.log(
    "📞 Handling call assignment:",
    callData.id,
    "Status:",
    callData.status,
    "Units:",
    callData.unit_details ? callData.unit_details.length : 0
  );

  if (currentData.activeCalls) {
    currentData.activeCalls[callData.id] = callData;
  }

  // Full refresh for assigned calls to update unit details
  updateActiveCalls(currentData.activeCalls);
}

function handleCallStatusChanged(callId, newStatus, callData) {
  console.log("📋 Handling status change for:", callId, "->", newStatus);

  if (currentData.activeCalls && currentData.activeCalls[callId]) {
    currentData.activeCalls[callId] = callData;
  }

  updateActiveCalls(currentData.activeCalls);
}

function handleCallCompleted(callId) {
  console.log("✅ Handling call completion:", callId);

  if (currentData.activeCalls) {
    delete currentData.activeCalls[callId];
  }

  updateActiveCalls(currentData.activeCalls);
}

// Helper function to update call stats
function updateCallStats(high, medium, low) {
  document.getElementById("highPriorityCalls").textContent = high;
  document.getElementById("mediumPriorityCalls").textContent = medium;
  document.getElementById("lowPriorityCalls").textContent = low;
}

// ====================================================================
// CALL ACTIONS (ENHANCED FOR MULTI-UNIT)
// ====================================================================

function assignToCall(callId) {
  console.log("🎯 assignToCall called with ID:", callId);

  if (!callId) {
    console.error("❌ No callId provided to assignToCall");
    return;
  }

  console.log("⚡ Sending assignment request via NUI callback...");

  const resourceName = "fl_core";

  fetch(`https://${resourceName}/assignToCall`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      callId: callId,
    }),
  })
    .then((response) => {
      console.log("📡 NUI Assignment response received:", response.status);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then((data) => {
      console.log("📨 NUI Assignment response data:", data);

      if (data.success) {
        console.log(
          "✅ Assignment request sent successfully for call:",
          callId
        );
      } else {
        console.error("❌ Assignment failed:", data.message);
        showNotification({
          type: "error",
          title: "Assignment Failed",
          message: data.message || "Unknown error occurred",
        });
      }
    })
    .catch((error) => {
      console.error("❌ Error in NUI assignment request:", error);
      showNotification({
        type: "error",
        title: "Connection Error",
        message: "Failed to send assignment request",
      });
    });
}

// NEW: Start working on call
function startWorkOnCall(callId) {
  console.log("🚀 startWorkOnCall called with ID:", callId);

  if (!callId) {
    console.error("❌ No callId provided to startWorkOnCall");
    return;
  }

  console.log("⚡ Sending start work request via NUI callback...");

  const resourceName = "fl_core";

  fetch(`https://${resourceName}/startWorkOnCall`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      callId: callId,
    }),
  })
    .then((response) => {
      console.log("📡 NUI Start Work response received:", response.status);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then((data) => {
      console.log("📨 NUI Start Work response data:", data);

      if (data.success) {
        console.log(
          "✅ Start work request sent successfully for call:",
          callId
        );
      } else {
        console.error("❌ Start work failed:", data.message);
        showNotification({
          type: "error",
          title: "Start Work Failed",
          message: data.message || "Unknown error occurred",
        });
      }
    })
    .catch((error) => {
      console.error("❌ Error in NUI start work request:", error);
      showNotification({
        type: "error",
        title: "Connection Error",
        message: "Failed to send start work request",
      });
    });
}

function completeCall(callId) {
  console.log("✅ completeCall called with ID:", callId);

  if (!callId) {
    console.error("❌ No callId provided to completeCall");
    return;
  }

  console.log("⚡ Sending completion request via NUI callback...");

  const resourceName = "fl_core";

  fetch(`https://${resourceName}/completeCall`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      callId: callId,
    }),
  })
    .then((response) => {
      console.log("📡 NUI Completion response received:", response.status);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then((data) => {
      console.log("📨 NUI Completion response data:", data);

      if (data.success) {
        console.log(
          "✅ Completion request sent successfully for call:",
          callId
        );
      } else {
        console.error("❌ Completion failed:", data.message);
        showNotification({
          type: "error",
          title: "Completion Failed",
          message: data.message || "Unknown error occurred",
        });
      }
    })
    .catch((error) => {
      console.error("❌ Error in NUI completion request:", error);
      showNotification({
        type: "error",
        title: "Connection Error",
        message: "Failed to send completion request",
      });
    });
}

// ====================================================================
// MDT UI FUNCTIONS (unchanged)
// ====================================================================

function showMDT(data) {
  console.log("📱 Showing MDT for:", data);

  // Store current data
  currentData = data;
  currentService = data.service;

  // Update MDT content
  updateMDTContent(data);

  // Show the MDT UI
  document.getElementById("mdtUI").classList.remove("hidden");

  // Start time updates
  startTimeUpdates();

  // Load active calls
  updateActiveCalls(data.activeCalls || {});
}

function updateMDTContent(data) {
  const config = serviceConfig[data.service] || serviceConfig.fire;

  // Update header
  const serviceIcon = document.getElementById("mdtServiceIcon");
  const serviceName = document.getElementById("mdtServiceName");

  serviceIcon.className = config.icon;
  serviceName.textContent = config.name;

  // Update tablet colors
  const tabletScreen = document.querySelector(".tablet-screen");
  tabletScreen.style.background = `linear-gradient(145deg, #2c3e50 0%, ${config.color}aa 100%)`;
}

// ====================================================================
// NAVIGATION FUNCTIONS (unchanged)
// ====================================================================

function initializeNavigation() {
  const navButtons = document.querySelectorAll(".nav-btn");

  navButtons.forEach((btn) => {
    btn.addEventListener("click", function () {
      const tabName = this.getAttribute("data-tab");
      switchTab(tabName);
    });
  });
}

function switchTab(tabName) {
  // Remove active class from all nav buttons and tabs
  document
    .querySelectorAll(".nav-btn")
    .forEach((btn) => btn.classList.remove("active"));
  document
    .querySelectorAll(".tab-content")
    .forEach((tab) => tab.classList.remove("active"));

  // Add active class to selected nav button and tab
  document.querySelector(`[data-tab="${tabName}"]`).classList.add("active");
  document.getElementById(`${tabName}Tab`).classList.add("active");

  // Load tab-specific content
  loadTabContent(tabName);
}

function loadTabContent(tabName) {
  switch (tabName) {
    case "calls":
      updateActiveCalls(currentData.activeCalls || {});
      break;

    case "units":
      loadUnits();
      break;

    case "map":
      loadMap();
      break;

    case "reports":
      loadReports();
      break;
  }
}

// ====================================================================
// OTHER TAB FUNCTIONS (unchanged)
// ====================================================================

function loadUnits() {
  const unitsList = document.getElementById("unitsList");

  // Placeholder for units
  unitsList.innerHTML = `
        <div class="unit-item">
            <div class="unit-status available">AVAILABLE</div>
            <h4>Unit 101</h4>
            <p>Station 1</p>
        </div>
        <div class="unit-item">
            <div class="unit-status busy">BUSY</div>
            <h4>Unit 102</h4>
            <p>En Route to Call</p>
        </div>
        <div class="unit-item">
            <div class="unit-status offline">OFF DUTY</div>
            <h4>Unit 103</h4>
            <p>Station 2</p>
        </div>
    `;
}

function loadMap() {
  console.log("🗺️ Loading map view");
}

function loadReports() {
  console.log("📄 Loading reports view");
}

// ====================================================================
// UTILITY FUNCTIONS (unchanged)
// ====================================================================

function getPriorityText(priority) {
  switch (priority) {
    case 1:
      return "HIGH";
    case 2:
      return "MEDIUM";
    case 3:
      return "LOW";
    default:
      return "UNKNOWN";
  }
}

function getPriorityClass(priority) {
  switch (priority) {
    case 1:
      return "high";
    case 2:
      return "medium";
    case 3:
      return "low";
    default:
      return "low";
  }
}

function formatCallType(type) {
  return type.replace(/_/g, " ").replace(/\b\w/g, (l) => l.toUpperCase());
}

function getTimeAgo(timestamp) {
  const now = Math.floor(Date.now() / 1000);
  const diff = now - timestamp;

  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

// ====================================================================
// TIME FUNCTIONS (unchanged)
// ====================================================================

function initializeTime() {
  updateTime();
}

function startTimeUpdates() {
  if (updateInterval) {
    clearInterval(updateInterval);
  }

  updateInterval = setInterval(updateTime, 1000);
}

function updateTime() {
  const timeElement = document.getElementById("currentTime");
  if (timeElement) {
    const now = new Date();
    const timeString = now.toLocaleTimeString("en-US", {
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    timeElement.textContent = timeString;
  }
}

// ====================================================================
// NOTIFICATION SYSTEM (unchanged)
// ====================================================================

function showNotification(data) {
  const notificationsContainer = document.getElementById("notifications");

  const notification = document.createElement("div");
  notification.className = `notification ${data.type || "info"}`;

  const iconMap = {
    success: "fas fa-check-circle",
    error: "fas fa-exclamation-triangle",
    warning: "fas fa-exclamation-circle",
    info: "fas fa-info-circle",
  };

  const icon = iconMap[data.type] || iconMap.info;

  notification.innerHTML = `
        <div class="notification-icon">
            <i class="${icon}"></i>
        </div>
        <div class="notification-content">
            <div class="notification-title">${
              data.title || "Notification"
            }</div>
            <div class="notification-message">${data.message}</div>
        </div>
    `;

  notificationsContainer.appendChild(notification);

  // Auto-remove after 5 seconds
  setTimeout(() => {
    if (notification.parentNode) {
      notification.style.animation =
        "notificationSlideOut 0.3s ease-in forwards";
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }
  }, 5000);
}

// ====================================================================
// UI MANAGEMENT (unchanged)
// ====================================================================

function hideAllUIs() {
  console.log("🙈 Hiding all UIs");

  document.getElementById("dutyUI").classList.add("hidden");
  document.getElementById("mdtUI").classList.add("hidden");

  // Stop time updates
  if (updateInterval) {
    clearInterval(updateInterval);
    updateInterval = null;
  }

  // Clear focus
  if (document.activeElement) {
    document.activeElement.blur();
  }

  // Force remove any remaining focus
  document.body.focus();

  console.log("✅ All UIs hidden successfully");
}

function closeUI() {
  console.log("❌ Close UI function called");

  const resourceName = "fl_core";

  // Send close signal to game via NUI callback
  fetch(`https://${resourceName}/closeUI`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(() => {
      console.log("✅ Close UI callback sent successfully");
    })
    .catch((error) => {
      console.error("❌ Error sending close UI callback:", error);
    });

  // Hide UIs immediately
  hideAllUIs();
}

// ====================================================================
// KEYBOARD HANDLING (unchanged)
// ====================================================================

document.addEventListener("keydown", function (event) {
  console.log("⌨️ Key pressed:", event.key, "Code:", event.code);

  // ESC key to close UI
  if (event.key === "Escape" || event.code === "Escape") {
    console.log("⌨️ ESC key detected - closing UI");
    event.preventDefault();
    closeUI();
    return false;
  }

  // BACKSPACE for emergency close
  if (event.key === "Backspace" || event.code === "Backspace") {
    console.log("⌨️ BACKSPACE key detected - emergency close");
    event.preventDefault();
    closeUI();
    return false;
  }
});

// ====================================================================
// ERROR HANDLING (unchanged)
// ====================================================================

window.addEventListener("error", function (event) {
  console.error("❌ FL UI Error:", event.error);
  console.error("❌ FL UI Error Details:", {
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
  });
});

window.addEventListener("unhandledrejection", function (event) {
  console.error("❌ FL UI Unhandled Promise Rejection:", event.reason);
  console.error("❌ FL UI Promise Details:", event);
});

// Add CSS for multi-unit styling
const style = document.createElement("style");
style.textContent = `
    @keyframes notificationSlideOut {
        from {
            opacity: 1;
            transform: translateX(0);
        }
        to {
            opacity: 0;
            transform: translateX(100%);
        }
    }
    
    .no-calls {
        text-align: center;
        padding: 60px 20px;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .no-calls i {
        font-size: 48px;
        margin-bottom: 15px;
        display: block;
    }
    
    .no-calls p {
        font-size: 16px;
    }

    /* Multi-Unit Styling */
    .assigned-units {
        background: rgba(255, 255, 255, 0.05);
        border-radius: 8px;
        margin: 10px 0;
        padding: 12px;
    }

    .units-header {
        display: flex;
        align-items: center;
        gap: 8px;
        font-weight: 600;
        margin-bottom: 8px;
        color: #ecf0f1;
        font-size: 14px;
    }

    .units-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
    }

    .units-list .unit-item {
        background: rgba(52, 152, 219, 0.2);
        border: 1px solid rgba(52, 152, 219, 0.4);
        border-radius: 6px;
        padding: 8px 12px;
        min-width: 120px;
    }

    .unit-callsign {
        font-weight: 600;
        font-size: 14px;
        color: #3498db;
    }

    .unit-name {
        font-size: 12px;
        color: #ecf0f1;
        margin-top: 2px;
    }

    .unit-rank {
        font-size: 10px;
        color: rgba(255, 255, 255, 0.7);
        margin-top: 2px;
    }

    /* Enhanced Button Styling */
    .call-btn.secondary {
        background: rgba(52, 152, 219, 0.7);
    }

    .call-btn.secondary:hover {
        background: rgba(52, 152, 219, 0.9);
    }

    .call-btn.start-work {
        background: #f39c12;
        color: white;
    }

    .call-btn.start-work:hover {
        background: #e67e22;
    }

    .call-status.max-units {
        background: rgba(231, 76, 60, 0.2);
        color: #e74c3c;
        padding: 6px 12px;
        border-radius: 5px;
        font-size: 12px;
        font-weight: 600;
    }

    .call-status.in-progress {
        background: rgba(243, 156, 18, 0.3);
        color: #f39c12;
        padding: 6px 12px;
        border-radius: 5px;
        font-size: 12px;
        font-weight: 600;
    }
`;
document.head.appendChild(style);

console.log(
  "🎉 FL Emergency Services Multi-Unit UI script loaded successfully"
);
