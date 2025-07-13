// ====================================================================
// FLASHING LIGHTS EMERGENCY SERVICES - UI JAVASCRIPT (KORRIGIERTE VERSION)
// ALLE KRITISCHEN FIXES IMPLEMENTIERT:
// ✅ Robustes UI State Management mit Error Recovery
// ✅ Throttled Update System für Performance
// ✅ Enhanced Error Handling für alle NUI Callbacks
// ✅ Safe Message Handling mit Validation
// ✅ Improved Close UI Function mit Multiple Attempts
// ====================================================================

// Enhanced global state with error recovery
let currentData = {};
let currentService = "";
let updateInterval = null;
let currentPlayerSource = null;

// UI state management with error recovery and throttling
const UIState = {
  isVisible: false,
  lastUpdate: 0,
  updateThrottle: 100, // Minimum 100ms between updates
  pendingUpdates: new Set(),
  errorCount: 0,
  maxErrors: 5,

  // Safe state updates
  setVisible: function (visible) {
    this.isVisible = visible;
    console.log("📱 UI state changed to:", visible ? "VISIBLE" : "HIDDEN");
  },

  // Reset error count
  resetErrors: function () {
    this.errorCount = 0;
    console.log("🔄 UI error count reset");
  },

  // Throttled update system
  scheduleUpdate: function (updateType, data) {
    const now = Date.now();

    if (now - this.lastUpdate < this.updateThrottle) {
      // Schedule for later
      if (!this.pendingUpdates.has(updateType)) {
        this.pendingUpdates.add(updateType);
        setTimeout(() => {
          this.executeUpdate(updateType, data);
          this.pendingUpdates.delete(updateType);
        }, this.updateThrottle);
      }
      return;
    }

    this.executeUpdate(updateType, data);
  },

  executeUpdate: function (updateType, data) {
    this.lastUpdate = Date.now();

    try {
      switch (updateType) {
        case "calls":
          updateActiveCalls(data);
          break;
        case "units":
          updateUnits(data);
          break;
        default:
          console.warn("⚠️ Unknown update type:", updateType);
      }

      // Reset error count on successful update
      if (this.errorCount > 0) {
        this.resetErrors();
      }
    } catch (error) {
      this.handleUpdateError(updateType, error);
    }
  },

  handleUpdateError: function (updateType, error) {
    this.errorCount++;
    console.error("❌ UI Update Error for", updateType, ":", error);
    console.error("❌ Error count:", this.errorCount);

    // Show error notification
    showNotification({
      type: "error",
      title: "UI Update Error",
      message: "Failed to update " + updateType + ". Please try refreshing.",
      duration: 5000,
    });

    // If too many errors, try to recover
    if (this.errorCount >= this.maxErrors) {
      console.error("❌ Too many UI errors - attempting full recovery");
      this.attemptFullRecovery();
    } else {
      // Try to recover
      setTimeout(() => {
        console.log("🔄 Attempting UI recovery...");
        this.executeUpdate(updateType, currentData.activeCalls || {});
      }, 2000);
    }
  },

  attemptFullRecovery: function () {
    console.log("🚨 ATTEMPTING FULL UI RECOVERY");

    // Reset all state
    this.errorCount = 0;
    this.pendingUpdates.clear();
    this.isVisible = false;

    // Force hide all UIs
    try {
      hideAllUIs();
    } catch (e) {
      console.error("❌ Error in full recovery hideAllUIs:", e);
    }

    // Show recovery notification
    showNotification({
      type: "warning",
      title: "UI Recovery",
      message: "UI has been reset due to errors. Please try opening again.",
      duration: 10000,
    });

    // Send recovery signal to game
    sendNUICallback("uiRecovery", { reason: "tooManyErrors" }).catch((e) => {
      console.error("❌ Failed to send recovery signal:", e);
    });
  },
};

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
// INITIALIZATION (ENHANCED)
// ====================================================================

document.addEventListener("DOMContentLoaded", function () {
  console.log("🚀 FL Emergency Services Multi-Unit UI loaded");

  try {
    // Initialize UI components
    initializeNavigation();
    initializeTime();

    // Hide all UIs initially
    hideAllUIs();

    // Setup error handlers
    setupErrorHandlers();

    console.log("✅ UI initialization completed successfully");
  } catch (error) {
    console.error("❌ Error during UI initialization:", error);
    showNotification({
      type: "error",
      title: "Initialization Error",
      message: "Failed to initialize UI properly. Some features may not work.",
      duration: 10000,
    });
  }
});

// Setup global error handlers
function setupErrorHandlers() {
  // Handle unhandled promise rejections
  window.addEventListener("unhandledrejection", function (event) {
    console.error("❌ Unhandled Promise Rejection:", event.reason);
    console.error("❌ Promise:", event.promise);

    // Prevent default handling
    event.preventDefault();

    showNotification({
      type: "error",
      title: "Promise Error",
      message: "An async operation failed. Check console for details.",
      duration: 5000,
    });
  });

  // Handle general errors
  window.addEventListener("error", function (event) {
    console.error("❌ JavaScript Error:", event.error);
    console.error("❌ Error Details:", {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
    });

    showNotification({
      type: "error",
      title: "JavaScript Error",
      message: "A script error occurred. Check console for details.",
      duration: 5000,
    });
  });
}

// ====================================================================
// ENHANCED MESSAGE HANDLING (ROBUST VERSION)
// ====================================================================

window.addEventListener("message", function (event) {
  const data = event.data;

  // Validate message structure
  if (!data || typeof data !== "object" || !data.type) {
    console.warn("⚠️ Invalid message received:", data);
    return;
  }

  console.log("📨 Received message:", data.type, data);

  try {
    switch (data.type) {
      case "showMDT":
        handleShowMDT(data.data);
        break;

      case "hideUI":
        handleHideUI();
        break;

      case "updateCalls":
        console.log("🔄 Updating calls with data:", data.data);
        UIState.scheduleUpdate("calls", data.data);
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
        console.log(
          "📋 Call status changed:",
          data.callId,
          "->",
          data.newStatus
        );
        handleCallStatusChanged(data.callId, data.newStatus, data.callData);
        break;

      case "callCompleted":
        console.log("✅ Call completed:", data.callId);
        handleCallCompleted(data.callId);
        break;

      case "forceRefresh":
        console.log("🔁 Force refresh requested");
        UIState.scheduleUpdate("calls", data.data);
        break;

      case "showNotification":
        showNotification(data.data);
        break;

      case "setPlayerSource":
        currentPlayerSource = data.source;
        console.log("👤 Player source set to:", currentPlayerSource);
        break;

      default:
        console.warn("⚠️ Unknown message type:", data.type);
    }
  } catch (error) {
    console.error("❌ Error handling message:", error);
    console.error("❌ Message data:", data);

    // Show error notification
    showNotification({
      type: "error",
      title: "Message Handling Error",
      message: "An error occurred processing UI message: " + data.type,
      duration: 3000,
    });

    // Increment error count
    UIState.errorCount++;
    if (UIState.errorCount >= UIState.maxErrors) {
      UIState.attemptFullRecovery();
    }
  }
});

// ====================================================================
// SAFE NUI CALLBACK SYSTEM (ENHANCED)
// ====================================================================

function sendNUICallback(endpoint, data, retries = 3) {
  const resourceName = "fl_core";

  return new Promise((resolve, reject) => {
    const attemptFetch = (attempt) => {
      // Validate input
      if (!endpoint || endpoint === "") {
        reject(new Error("Invalid endpoint provided"));
        return;
      }

      fetch(`https://${resourceName}/${endpoint}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(data || {}),
      })
        .then((response) => {
          console.log(`📡 NUI ${endpoint} response:`, response.status);

          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }

          return response.json();
        })
        .then((responseData) => {
          console.log(`📨 NUI ${endpoint} success:`, responseData);
          resolve(responseData);
        })
        .catch((error) => {
          console.error(
            `❌ NUI ${endpoint} error (attempt ${attempt}):`,
            error
          );

          if (attempt < retries) {
            const retryDelay = attempt * 1000;
            console.log(`🔄 Retrying ${endpoint} in ${retryDelay}ms...`);
            setTimeout(() => attemptFetch(attempt + 1), retryDelay);
          } else {
            console.error(
              `❌ NUI ${endpoint} failed after ${retries} attempts`
            );
            reject(error);

            // Show error notification only for critical endpoints
            if (
              ["assignToCall", "completeCall", "startWorkOnCall"].includes(
                endpoint
              )
            ) {
              showNotification({
                type: "error",
                title: "Connection Error",
                message: `Failed to ${endpoint} after ${retries} attempts`,
                duration: 3000,
              });
            }
          }
        });
    };

    attemptFetch(1);
  });
}

// ====================================================================
// ENHANCED ACTION FUNCTIONS (ROBUST CALLBACKS)
// ====================================================================

function assignToCall(callId) {
  console.log("🎯 assignToCall called with ID:", callId);

  if (!callId || callId === "") {
    console.error("❌ No callId provided to assignToCall");
    showNotification({
      type: "error",
      title: "Assignment Error",
      message: "No call ID provided",
    });
    return;
  }

  // Disable button to prevent double-clicks
  const button = document.querySelector(
    `[onclick="assignToCall('${callId}')"]`
  );
  if (button) {
    button.disabled = true;
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Assigning...';

    // Re-enable after 3 seconds
    setTimeout(() => {
      button.disabled = false;
      button.innerHTML = originalText;
    }, 3000);
  }

  sendNUICallback("assignToCall", { callId: callId })
    .then((data) => {
      if (data && data.success) {
        console.log(
          "✅ Assignment request sent successfully for call:",
          callId
        );
        showNotification({
          type: "success",
          title: "Assignment Sent",
          message: "Assignment request sent for call " + callId,
        });
      } else {
        throw new Error(data ? data.message : "Unknown error");
      }
    })
    .catch((error) => {
      console.error("❌ Assignment failed:", error);
      showNotification({
        type: "error",
        title: "Assignment Failed",
        message: error.message || "Failed to assign to call",
      });
    })
    .finally(() => {
      // Re-enable button
      if (button) {
        button.disabled = false;
        button.innerHTML =
          button.getAttribute("data-original-text") ||
          '<i class="fas fa-user-plus"></i> Assign to Me';
      }
    });
}

function startWorkOnCall(callId) {
  console.log("🚀 startWorkOnCall called with ID:", callId);

  if (!callId || callId === "") {
    console.error("❌ No callId provided to startWorkOnCall");
    showNotification({
      type: "error",
      title: "Start Work Error",
      message: "No call ID provided",
    });
    return;
  }

  // Disable button to prevent double-clicks
  const button = document.querySelector(
    `[onclick="startWorkOnCall('${callId}')"]`
  );
  if (button) {
    button.disabled = true;
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Starting...';

    setTimeout(() => {
      button.disabled = false;
      button.innerHTML = originalText;
    }, 3000);
  }

  sendNUICallback("startWorkOnCall", { callId: callId })
    .then((data) => {
      if (data && data.success) {
        console.log(
          "✅ Start work request sent successfully for call:",
          callId
        );
        showNotification({
          type: "success",
          title: "Work Started",
          message: "Started working on call " + callId,
        });
      } else {
        throw new Error(data ? data.message : "Unknown error");
      }
    })
    .catch((error) => {
      console.error("❌ Start work failed:", error);
      showNotification({
        type: "error",
        title: "Start Work Failed",
        message: error.message || "Failed to start work on call",
      });
    })
    .finally(() => {
      if (button) {
        button.disabled = false;
        button.innerHTML =
          button.getAttribute("data-original-text") ||
          '<i class="fas fa-play"></i> Start Work';
      }
    });
}

function completeCall(callId) {
  console.log("✅ completeCall called with ID:", callId);

  if (!callId || callId === "") {
    console.error("❌ No callId provided to completeCall");
    showNotification({
      type: "error",
      title: "Complete Call Error",
      message: "No call ID provided",
    });
    return;
  }

  // Disable button to prevent double-clicks
  const button = document.querySelector(
    `[onclick="completeCall('${callId}')"]`
  );
  if (button) {
    button.disabled = true;
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Completing...';

    setTimeout(() => {
      button.disabled = false;
      button.innerHTML = originalText;
    }, 5000);
  }

  sendNUICallback("completeCall", { callId: callId })
    .then((data) => {
      if (data && data.success) {
        console.log(
          "✅ Completion request sent successfully for call:",
          callId
        );
        showNotification({
          type: "success",
          title: "Call Completed",
          message: "Successfully completed call " + callId,
        });
      } else {
        throw new Error(data ? data.message : "Unknown error");
      }
    })
    .catch((error) => {
      console.error("❌ Completion failed:", error);
      showNotification({
        type: "error",
        title: "Completion Failed",
        message: error.message || "Failed to complete call",
      });
    })
    .finally(() => {
      if (button) {
        button.disabled = false;
        button.innerHTML =
          button.getAttribute("data-original-text") ||
          '<i class="fas fa-check"></i> Complete Call';
      }
    });
}

// ====================================================================
// MDT HANDLING FUNCTIONS (ENHANCED)
// ====================================================================

function handleShowMDT(data) {
  try {
    console.log("📱 Showing MDT for:", data);

    // Validate data
    if (!data || !data.service) {
      console.error("❌ Invalid MDT data:", data);
      showNotification({
        type: "error",
        title: "MDT Error",
        message: "Invalid service data received",
      });
      return;
    }

    // Store current data safely
    currentData = Object.assign({}, data); // Shallow copy for safety
    currentService = data.service;

    // Update MDT content
    updateMDTContent(data);

    // Show the MDT UI with error handling
    const mdtElement = document.getElementById("mdtUI");
    if (mdtElement) {
      mdtElement.classList.remove("hidden");
      UIState.setVisible(true);
    } else {
      console.error("❌ MDT UI element not found!");
      return;
    }

    // Start time updates
    startTimeUpdates();

    // Load active calls with safety check
    const activeCalls = data.activeCalls || {};
    UIState.scheduleUpdate("calls", activeCalls);

    console.log("✅ MDT opened successfully");
  } catch (error) {
    console.error("❌ Error showing MDT:", error);
    handleMDTError("Failed to open MDT");
  }
}

function handleMDTError(message) {
  console.error("❌ MDT Error:", message);

  // Force close UI
  hideAllUIs();

  // Show error notification
  showNotification({
    type: "error",
    title: "MDT Error",
    message: message + ". Please try again.",
    duration: 5000,
  });

  // Send error to game
  sendNUICallback("mdtError", { message: message }).catch((e) => {
    console.error("❌ Failed to send MDT error to game:", e);
  });
}

function handleHideUI() {
  console.log("🙈 Hiding UI");
  try {
    hideAllUIs();
  } catch (error) {
    console.error("❌ Error hiding UI:", error);
    // Force cleanup
    try {
      document.getElementById("dutyUI").classList.add("hidden");
      document.getElementById("mdtUI").classList.add("hidden");
      UIState.setVisible(false);
    } catch (e) {
      console.error("❌ Force cleanup failed:", e);
    }
  }
}

// ====================================================================
// CALL MANAGEMENT FUNCTIONS (ENHANCED ERROR HANDLING)
// ====================================================================

function updateActiveCalls(calls) {
  console.log("🔄 updateActiveCalls called with:", calls);

  try {
    const callsList = document.getElementById("callsList");
    if (!callsList) {
      console.error("❌ Calls list element not found!");
      return;
    }

    // Clear existing calls
    callsList.innerHTML = "";

    // Validate calls data
    if (!calls || typeof calls !== "object") {
      console.warn("⚠️ Invalid calls data, using empty object");
      calls = {};
    }

    // Count calls by priority
    let highPriority = 0,
      mediumPriority = 0,
      lowPriority = 0;

    // Convert calls object to array and sort by priority and time
    const callsArray = Object.values(calls)
      .filter((call) => call && call.id)
      .sort((a, b) => {
        if (a.priority !== b.priority) {
          return a.priority - b.priority; // Higher priority first (1 = high)
        }
        return (b.created_at || 0) - (a.created_at || 0); // Newer calls first
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
      try {
        const callElement = createCallElement(call);
        if (callElement) {
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
        }
      } catch (error) {
        console.error("❌ Error creating call element for:", call.id, error);
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
  } catch (error) {
    console.error("❌ Error in updateActiveCalls:", error);
    showNotification({
      type: "error",
      title: "Update Error",
      message: "Failed to update active calls display",
    });
  }
}

function createCallElement(call) {
  try {
    console.log(
      "🏗️ Creating call element for:",
      call.id,
      "Status:",
      call.status
    );

    if (!call || !call.id) {
      console.error("❌ Invalid call data for element creation");
      return null;
    }

    const callDiv = document.createElement("div");
    callDiv.className = `call-item priority-${call.priority || 2}`;
    callDiv.setAttribute("data-call-id", call.id);

    const priorityText = getPriorityText(call.priority);
    const priorityClass = getPriorityClass(call.priority);
    const timeAgo = getTimeAgo(call.created_at);

    // Create assigned units display
    const assignedUnitsHtml = createAssignedUnitsDisplay(
      call.unit_details || []
    );

    // Determine which buttons to show based on call status and assignment
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
            <div class="call-description">${
              call.description || "Emergency assistance required"
            }</div>
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
  } catch (error) {
    console.error("❌ Error creating call element:", error);
    return null;
  }
}

// Create assigned units display
function createAssignedUnitsDisplay(unitDetails) {
  try {
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
      const callsign = unit.callsign || "Unknown";
      const name = unit.name || "Unknown Officer";
      const rank = unit.rank || "Unknown Rank";

      unitsHtml += `
                <div class="unit-item">
                    <div class="unit-callsign">${callsign}</div>
                    <div class="unit-name">${name}</div>
                    <div class="unit-rank">${rank}</div>
                </div>
            `;
    });

    unitsHtml += `
                </div>
            </div>
        `;

    return unitsHtml;
  } catch (error) {
    console.error("❌ Error creating assigned units display:", error);
    return `
            <div class="assigned-units">
                <div class="units-header">
                    <i class="fas fa-exclamation-triangle"></i>
                    <span>Error loading unit details</span>
                </div>
            </div>
        `;
  }
}

// Get action buttons based on call status and assignment
function getActionButtonsForStatus(status, callId, unitDetails, maxUnits) {
  try {
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
                    <button class="call-btn assign" onclick="assignToCall('${callId}')" data-original-text="<i class='fas fa-user-plus'></i> Assign to Me">
                        <i class="fas fa-user-plus"></i> Assign to Me
                    </button>
                `;

      case "assigned":
      case "multi_assigned":
        let buttons = "";

        if (!isPlayerAssigned && canAssignMore) {
          buttons += `
                        <button class="call-btn assign secondary" onclick="assignToCall('${callId}')" data-original-text="<i class='fas fa-user-plus'></i> Join Response">
                            <i class="fas fa-user-plus"></i> Join Response
                        </button>
                    `;
        }

        if (isPlayerAssigned) {
          if (status !== "in_progress") {
            buttons += `
                            <button class="call-btn start-work" onclick="startWorkOnCall('${callId}')" data-original-text="<i class='fas fa-play'></i> Start Work">
                                <i class="fas fa-play"></i> Start Work
                            </button>
                        `;
          }
          buttons += `
                        <button class="call-btn complete" onclick="completeCall('${callId}')" data-original-text="<i class='fas fa-check'></i> Complete Call">
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
                        <button class="call-btn complete" onclick="completeCall('${callId}')" data-original-text="<i class='fas fa-check'></i> Complete Call">
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
  } catch (error) {
    console.error("❌ Error getting action buttons:", error);
    return `
            <span class="call-status error">
                <i class="fas fa-exclamation-triangle"></i> Error
            </span>
        `;
  }
}

// ====================================================================
// EVENT HANDLERS (ENHANCED)
// ====================================================================

function handleNewCall(callData) {
  try {
    console.log("🆕 Handling new call:", callData.id);

    if (!currentData.activeCalls) {
      currentData.activeCalls = {};
    }
    currentData.activeCalls[callData.id] = callData;

    UIState.scheduleUpdate("calls", currentData.activeCalls);
  } catch (error) {
    console.error("❌ Error handling new call:", error);
  }
}

function handleCallAssigned(callData) {
  try {
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

    UIState.scheduleUpdate("calls", currentData.activeCalls);
  } catch (error) {
    console.error("❌ Error handling call assignment:", error);
  }
}

function handleCallStatusChanged(callId, newStatus, callData) {
  try {
    console.log("📋 Handling status change for:", callId, "->", newStatus);

    if (currentData.activeCalls && currentData.activeCalls[callId]) {
      currentData.activeCalls[callId] = callData;
    }

    UIState.scheduleUpdate("calls", currentData.activeCalls);
  } catch (error) {
    console.error("❌ Error handling status change:", error);
  }
}

function handleCallCompleted(callId) {
  try {
    console.log("✅ Handling call completion:", callId);

    if (currentData.activeCalls) {
      delete currentData.activeCalls[callId];
    }

    UIState.scheduleUpdate("calls", currentData.activeCalls);
  } catch (error) {
    console.error("❌ Error handling call completion:", error);
  }
}

// ====================================================================
// UI MANAGEMENT FUNCTIONS (ENHANCED)
// ====================================================================

function updateMDTContent(data) {
  try {
    const config = serviceConfig[data.service] || serviceConfig.fire;

    // Update header
    const serviceIcon = document.getElementById("mdtServiceIcon");
    const serviceName = document.getElementById("mdtServiceName");

    if (serviceIcon) serviceIcon.className = config.icon;
    if (serviceName) serviceName.textContent = config.name;

    // Update tablet colors
    const tabletScreen = document.querySelector(".tablet-screen");
    if (tabletScreen) {
      tabletScreen.style.background = `linear-gradient(145deg, #2c3e50 0%, ${config.color}aa 100%)`;
    }
  } catch (error) {
    console.error("❌ Error updating MDT content:", error);
  }
}

function hideAllUIs() {
  console.log("🙈 Hiding all UIs");

  try {
    // Stop time updates
    if (updateInterval) {
      clearInterval(updateInterval);
      updateInterval = null;
    }

    // Hide UI elements
    const dutyUI = document.getElementById("dutyUI");
    const mdtUI = document.getElementById("mdtUI");

    if (dutyUI) dutyUI.classList.add("hidden");
    if (mdtUI) mdtUI.classList.add("hidden");

    // Update state
    UIState.setVisible(false);

    // Clear any pending updates
    UIState.pendingUpdates.clear();

    console.log("✅ All UIs hidden successfully");
  } catch (error) {
    console.error("❌ Error hiding UIs:", error);

    // Force hide with direct DOM manipulation
    try {
      const elements = document.querySelectorAll(".ui-container");
      elements.forEach((el) => {
        if (el) el.style.display = "none";
      });
    } catch (e) {
      console.error("❌ Force hide failed:", e);
    }
  }
}

function closeUI() {
  console.log("❌ Close UI function called");

  try {
    // Immediate UI cleanup
    hideAllUIs();

    // Multiple attempts to clear focus (async to prevent blocking)
    const clearFocus = () => {
      try {
        document.body.blur();
        window.blur();

        // Clear any active elements
        if (document.activeElement && document.activeElement.blur) {
          document.activeElement.blur();
        }

        // Force focus to body
        document.body.focus();
      } catch (e) {
        console.warn("⚠️ Focus clearing error:", e);
      }
    };

    // Clear focus multiple times with delays
    for (let i = 0; i < 10; i++) {
      setTimeout(clearFocus, i * 10);
    }

    // Send close signal with error handling
    sendNUICallback("closeUI", {})
      .then(() => {
        console.log("✅ Close UI callback sent successfully");
      })
      .catch((error) => {
        console.error("❌ Error sending close UI callback:", error);
        // Don't show notification for close errors as UI might be closing
      });
  } catch (error) {
    console.error("❌ Critical error in closeUI:", error);

    // Force cleanup as last resort
    try {
      document.getElementById("dutyUI").classList.add("hidden");
      document.getElementById("mdtUI").classList.add("hidden");
      UIState.setVisible(false);
    } catch (e) {
      console.error("❌ Force cleanup failed:", e);
    }
  }
}

// ====================================================================
// UTILITY FUNCTIONS (ENHANCED)
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
  if (!type || type === "") return "Unknown";
  return type.replace(/_/g, " ").replace(/\b\w/g, (l) => l.toUpperCase());
}

function getTimeAgo(timestamp) {
  try {
    if (!timestamp) return "Unknown";

    const now = Math.floor(Date.now() / 1000);
    const diff = now - timestamp;

    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    return `${Math.floor(diff / 3600)}h ago`;
  } catch (error) {
    console.error("❌ Error calculating time ago:", error);
    return "Unknown";
  }
}

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

function updateCallStats(high, medium, low) {
  try {
    const highElement = document.getElementById("highPriorityCalls");
    const mediumElement = document.getElementById("mediumPriorityCalls");
    const lowElement = document.getElementById("lowPriorityCalls");

    if (highElement) highElement.textContent = high;
    if (mediumElement) mediumElement.textContent = medium;
    if (lowElement) lowElement.textContent = low;
  } catch (error) {
    console.error("❌ Error updating call stats:", error);
  }
}

// ====================================================================
// NAVIGATION FUNCTIONS (ENHANCED)
// ====================================================================

function initializeNavigation() {
  try {
    const navButtons = document.querySelectorAll(".nav-btn");

    navButtons.forEach((btn) => {
      btn.addEventListener("click", function () {
        const tabName = this.getAttribute("data-tab");
        if (tabName) {
          switchTab(tabName);
        }
      });
    });
  } catch (error) {
    console.error("❌ Error initializing navigation:", error);
  }
}

function switchTab(tabName) {
  try {
    // Remove active class from all nav buttons and tabs
    document
      .querySelectorAll(".nav-btn")
      .forEach((btn) => btn.classList.remove("active"));
    document
      .querySelectorAll(".tab-content")
      .forEach((tab) => tab.classList.remove("active"));

    // Add active class to selected nav button and tab
    const navBtn = document.querySelector(`[data-tab="${tabName}"]`);
    const tabContent = document.getElementById(`${tabName}Tab`);

    if (navBtn) navBtn.classList.add("active");
    if (tabContent) tabContent.classList.add("active");

    // Load tab-specific content
    loadTabContent(tabName);
  } catch (error) {
    console.error("❌ Error switching tab:", error);
  }
}

function loadTabContent(tabName) {
  try {
    switch (tabName) {
      case "calls":
        UIState.scheduleUpdate("calls", currentData.activeCalls || {});
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
  } catch (error) {
    console.error("❌ Error loading tab content:", error);
  }
}

// ====================================================================
// TIME FUNCTIONS (ENHANCED)
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
  try {
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
  } catch (error) {
    console.error("❌ Error updating time:", error);
  }
}

// ====================================================================
// NOTIFICATION SYSTEM (ENHANCED)
// ====================================================================

function showNotification(data) {
  try {
    const notificationsContainer = document.getElementById("notifications");
    if (!notificationsContainer) {
      console.warn("⚠️ Notifications container not found");
      return;
    }

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
                <div class="notification-message">${data.message || ""}</div>
            </div>
        `;

    notificationsContainer.appendChild(notification);

    // Auto-remove after specified duration
    const duration = data.duration || 5000;
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
    }, duration);
  } catch (error) {
    console.error("❌ Error showing notification:", error);
  }
}

// ====================================================================
// PLACEHOLDER FUNCTIONS
// ====================================================================

function loadUnits() {
  try {
    const unitsList = document.getElementById("unitsList");
    if (unitsList) {
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
  } catch (error) {
    console.error("❌ Error loading units:", error);
  }
}

function loadMap() {
  console.log("🗺️ Loading map view");
}

function loadReports() {
  console.log("📄 Loading reports view");
}

// ====================================================================
// KEYBOARD HANDLING (ENHANCED)
// ====================================================================

document.addEventListener("keydown", function (event) {
  try {
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
  } catch (error) {
    console.error("❌ Error in keyboard handling:", error);
  }
});

console.log(
  "🎉 FL Emergency Services Multi-Unit UI script loaded with COMPLETE ERROR HANDLING & ROBUSTNESS"
);
