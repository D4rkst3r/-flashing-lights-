// ====================================================================
// FLASHING LIGHTS EMERGENCY SERVICES - UI JAVASCRIPT
// ====================================================================

// Global state
let currentData = {};
let currentService = "";
let updateInterval = null;

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
  console.log("FL Emergency Services UI loaded");

  // Initialize UI components
  initializeNavigation();
  initializeTime();

  // Hide all UIs initially
  hideAllUIs();
});

// ====================================================================
// MESSAGE HANDLING
// ====================================================================

// Listen for messages from client
window.addEventListener("message", function (event) {
  const data = event.data;

  switch (data.type) {
    case "showMDT":
      showMDT(data.data);
      break;

    case "hideUI":
      hideAllUIs();
      break;

    case "updateCalls":
      updateActiveCalls(data.data);
      break;

    case "showNotification":
      showNotification(data.data);
      break;
  }
});

// ====================================================================
// DUTY UI FUNCTIONS
// ====================================================================

function showDutyUI(data) {
  console.log("Showing duty UI for:", data);

  // Store current data
  currentData = data;
  currentService = data.serviceName;

  // Update UI elements
  updateDutyUIContent(data);

  // Show the UI
  document.getElementById("dutyUI").classList.remove("hidden");

  // Focus on start duty button
  setTimeout(() => {
    document.getElementById("startDutyBtn").focus();
  }, 100);
}

function updateDutyUIContent(data) {
  const config = serviceConfig[data.serviceName] || serviceConfig.fire;

  // Update service badge
  const serviceBadge = document.getElementById("serviceBadge");
  serviceBadge.className = config.icon;

  // Update station info
  document.getElementById("stationName").textContent = data.station;
  document.getElementById("serviceName").textContent = data.service;

  // Update modal colors
  const dutyModal = document.querySelector(".duty-modal");
  dutyModal.style.background = `linear-gradient(135deg, #2c3e50 0%, ${config.color} 100%)`;

  // Set up start duty button
  const startDutyBtn = document.getElementById("startDutyBtn");
  startDutyBtn.onclick = () => startDuty(data);
}

function startDuty(data) {
  console.log("Starting duty for:", data);

  // Send callback to client
  fetch(`https://${GetParentResourceName()}/startDuty`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      service: data.serviceName,
      stationId: data.stationId,
    }),
  });

  // Hide duty UI
  hideAllUIs();
}

// ====================================================================
// MDT UI FUNCTIONS
// ====================================================================

function showMDT(data) {
  console.log("Showing MDT for:", data);

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
// NAVIGATION FUNCTIONS
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
// CALLS MANAGEMENT (Fixed)
// ====================================================================

function updateActiveCalls(calls) {
  console.log("Updating active calls:", calls);

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

  console.log("Processed calls array:", callsArray);

  if (callsArray.length === 0) {
    callsList.innerHTML = `
            <div class="no-calls">
                <i class="fas fa-phone-slash"></i>
                <p>No active emergency calls</p>
            </div>
        `;

    // Update call stats to zero
    document.getElementById("highPriorityCalls").textContent = "0";
    document.getElementById("mediumPriorityCalls").textContent = "0";
    document.getElementById("lowPriorityCalls").textContent = "0";
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
  document.getElementById("highPriorityCalls").textContent = highPriority;
  document.getElementById("mediumPriorityCalls").textContent = mediumPriority;
  document.getElementById("lowPriorityCalls").textContent = lowPriority;

  console.log(
    "Call stats updated - High:",
    highPriority,
    "Medium:",
    mediumPriority,
    "Low:",
    lowPriority
  );
}

function createCallElement(call) {
  console.log("Creating call element for:", call);

  const callDiv = document.createElement("div");
  callDiv.className = `call-item priority-${call.priority}`;

  const priorityText = getPriorityText(call.priority);
  const priorityClass = getPriorityClass(call.priority);
  const timeAgo = getTimeAgo(call.created_at);

  // Determine which buttons to show based on call status
  let actionButtons = "";

  if (call.status === "pending") {
    actionButtons = `
            <button class="call-btn assign" onclick="assignToCall('${call.id}')">
                <i class="fas fa-user-plus"></i> Assign to Me
            </button>
        `;
  } else if (call.status === "assigned") {
    actionButtons = `
            <button class="call-btn complete" onclick="completeCall('${call.id}')">
                <i class="fas fa-check"></i> Complete Call
            </button>
        `;
  } else if (call.status === "completed") {
    actionButtons = `
            <span class="call-status completed">
                <i class="fas fa-check-circle"></i> Completed
            </span>
        `;
  }

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
            <span><i class="fas fa-info-circle"></i> Status: <strong>${call.status.toUpperCase()}</strong></span>
        </div>
        <div class="call-actions">
            ${actionButtons}
        </div>
    `;

  return callDiv;
}

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

function formatDistance(coords) {
  // This would need to be calculated based on player position
  // For now, return a placeholder
  return "Unknown distance";
}

// ====================================================================
// CALL ACTIONS (FIXED with better error handling)
// ====================================================================

function assignToCall(callId) {
  console.log("🎯 assignToCall called with ID:", callId);

  if (!callId) {
    console.error("❌ No callId provided to assignToCall");
    return;
  }

  // Immediately update UI optimistically
  console.log("⚡ Sending assignment request to server...");

  fetch(`https://${GetParentResourceName()}/assignToCall`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      callId: callId,
    }),
  })
    .then((response) => {
      console.log("✅ Assignment request sent successfully");
      return response.text();
    })
    .then((data) => {
      console.log("📨 Server response:", data);
    })
    .catch((error) => {
      console.error("❌ Error sending assignment request:", error);
    });
}

function completeCall(callId) {
  console.log("✅ completeCall called with ID:", callId);

  if (!callId) {
    console.error("❌ No callId provided to completeCall");
    return;
  }

  console.log("⚡ Sending completion request to server...");

  fetch(`https://${GetParentResourceName()}/completeCall`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      callId: callId,
    }),
  })
    .then((response) => {
      console.log("✅ Completion request sent successfully");
      return response.text();
    })
    .then((data) => {
      console.log("📨 Server response:", data);
    })
    .catch((error) => {
      console.error("❌ Error sending completion request:", error);
    });
}

// ====================================================================
// OTHER TAB FUNCTIONS
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
  // Placeholder for map functionality
  console.log("Loading map view");
}

function loadReports() {
  // Placeholder for reports functionality
  console.log("Loading reports view");
}

// ====================================================================
// TIME FUNCTIONS
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
// NOTIFICATION SYSTEM
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
// UI MANAGEMENT (Fixed)
// ====================================================================

function hideAllUIs() {
  console.log("Hiding all UIs");

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

  console.log("All UIs hidden successfully");
}

function closeUI() {
  console.log("Close UI function called");

  // Send close signal to game
  fetch(`https://${GetParentResourceName()}/closeUI`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  })
    .then(() => {
      console.log("Close UI callback sent successfully");
    })
    .catch((error) => {
      console.error("Error sending close UI callback:", error);
    });

  // Hide UIs immediately
  hideAllUIs();
}

// ====================================================================
// KEYBOARD HANDLING (Improved)
// ====================================================================

document.addEventListener("keydown", function (event) {
  console.log("Key pressed:", event.key, "Code:", event.code);

  // ESC key to close UI
  if (event.key === "Escape" || event.code === "Escape") {
    console.log("ESC key detected - closing UI");
    event.preventDefault();
    closeUI();
    return false;
  }

  // BACKSPACE for emergency close
  if (event.key === "Backspace" || event.code === "Backspace") {
    console.log("BACKSPACE key detected - emergency close");
    event.preventDefault();
    closeUI();
    return false;
  }

  // Enter key to start duty when duty UI is open
  if (
    event.key === "Enter" &&
    !document.getElementById("dutyUI").classList.contains("hidden")
  ) {
    const startDutyBtn = document.getElementById("startDutyBtn");
    if (startDutyBtn) {
      startDutyBtn.click();
    }
  }
});

// Additional mouse click handler for UI
document.addEventListener("click", function (event) {
  // If clicking outside of modal content, close UI
  if (event.target.classList.contains("ui-container")) {
    console.log("Clicked outside modal - closing UI");
    closeUI();
  }
});

// Prevent context menu
document.addEventListener("contextmenu", function (event) {
  event.preventDefault();
  return false;
});

// Force focus management
window.addEventListener("focus", function () {
  console.log("Window gained focus");
});

window.addEventListener("blur", function () {
  console.log("Window lost focus");
});

// ====================================================================
// UTILITY FUNCTIONS
// ====================================================================

function GetParentResourceName() {
  return window.location.hostname;
}

// ====================================================================
// ERROR HANDLING
// ====================================================================

window.addEventListener("error", function (event) {
  console.error("FL UI Error:", event.error);
});

window.addEventListener("unhandledrejection", function (event) {
  console.error("FL UI Unhandled Promise Rejection:", event.reason);
});

// Add CSS animation for notification slide out
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
`;
document.head.appendChild(style);

console.log("FL Emergency Services UI script loaded successfully");
