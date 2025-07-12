// ===================================
// FLASHING LIGHTS UI JAVASCRIPT
// ===================================

let currentData = null;
let dutyTimer = null;
let dutyStartTime = null;

// ===================================
// MESSAGE HANDLERS
// ===================================

window.addEventListener("message", function (event) {
  const data = event.data;

  switch (data.action) {
    case "showDutyUI":
      showDutyUI(data.data);
      break;
    case "hideDutyUI":
      hideDutyUI();
      break;
    case "updateDutyStatus":
      updateDutyStatus(data.data);
      break;
    case "showAlert":
      showAlert(data.data);
      break;
    case "updateStatusDisplay":
      updateStatusDisplay(data.data);
      break;
    default:
      break;
  }
});

// ===================================
// DUTY UI FUNCTIONS
// ===================================

function showDutyUI(data) {
  currentData = data;

  // Update station information
  document.getElementById("stationName").textContent = data.station.label;
  document.getElementById("stationCode").textContent = getStationCode(
    data.station.job
  );
  document.getElementById("stationAddress").textContent = getStationAddress(
    data.station
  );

  // Update player information
  updatePlayerInfo(data);

  // Update duty status
  updateDutyDisplay(data);

  // Apply job-specific styling
  applyJobStyling(data.playerJob.name);

  // Show the UI
  document.getElementById("dutyUI").style.display = "flex";
  document.getElementById("dutyUI").classList.add("fade-in");
}

function hideDutyUI() {
  document.getElementById("dutyUI").style.display = "none";
  document.getElementById("dutyUI").classList.remove("fade-in");
  stopDutyTimer();
  currentData = null;
}

function updatePlayerInfo(data) {
  // This would normally come from player data
  // For now, we'll use placeholder data
  document.getElementById("playerName").textContent = "John Doe"; // Replace with actual player name
  document.getElementById("playerBadge").textContent =
    data.playerJob.grade.level || "1234";
  document.getElementById("playerRank").textContent =
    data.playerJob.grade.label || "Officer";
}

function updateDutyDisplay(data) {
  const statusElement = document.getElementById("dutyStatus");
  const toggleButton = document.getElementById("dutyToggle");
  const dutyTimeElement = document.getElementById("dutyTime");

  if (data.onDuty) {
    // On duty
    statusElement.textContent = "On Duty";
    statusElement.className = "status on-duty pulse";

    toggleButton.textContent = "End Duty";
    toggleButton.className = "duty-btn end-duty";

    dutyTimeElement.style.display = "block";
    startDutyTimer();
  } else {
    // Off duty
    statusElement.textContent = "Off Duty";
    statusElement.className = "status off-duty";

    toggleButton.textContent = "Start Duty";
    toggleButton.className = "duty-btn start-duty";

    dutyTimeElement.style.display = "none";
    stopDutyTimer();
  }
}

function applyJobStyling(job) {
  const panel = document.querySelector(".duty-panel");

  // Remove existing job classes
  panel.classList.remove("job-fire", "job-ambulance", "job-police");

  // Add new job class
  panel.classList.add(`job-${job}`);
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

  const hours = Math.floor(elapsed / 3600);
  const minutes = Math.floor((elapsed % 3600) / 60);
  const seconds = elapsed % 60;

  const timeString = `${hours.toString().padStart(2, "0")}:${minutes
    .toString()
    .padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  document.getElementById("timeDisplay").textContent = timeString;
}

// ===================================
// ALERT SYSTEM
// ===================================

function showAlert(alertData) {
  const alertsContainer = document.getElementById("emergencyAlerts");

  const alertElement = document.createElement("div");
  alertElement.className = "alert";
  alertElement.innerHTML = `
        <div class="alert-header">
            <span class="alert-title">${
              alertData.title || "Emergency Call"
            }</span>
            <span class="alert-priority">Priority ${
              alertData.priority || 2
            }</span>
        </div>
        <div class="alert-content">
            ${alertData.description || "No description available"}
        </div>
        <div class="alert-location">
            📍 ${alertData.location || "Location unknown"}
        </div>
    `;

  // Add to container
  alertsContainer.appendChild(alertElement);

  // Play alert sound (if available)
  playAlertSound(alertData.priority);

  // Auto-remove after 10 seconds unless it's high priority
  const autoRemoveTime = alertData.priority <= 2 ? 15000 : 30000;
  setTimeout(() => {
    if (alertElement.parentNode) {
      alertElement.style.animation = "alertSlideIn 0.3s ease-out reverse";
      setTimeout(() => {
        if (alertElement.parentNode) {
          alertElement.remove();
        }
      }, 300);
    }
  }, autoRemoveTime);

  // Add click to dismiss
  alertElement.addEventListener("click", () => {
    alertElement.style.animation = "alertSlideIn 0.3s ease-out reverse";
    setTimeout(() => {
      if (alertElement.parentNode) {
        alertElement.remove();
      }
    }, 300);
  });
}

function playAlertSound(priority) {
  // This would play different sounds based on priority
  // For now, we'll use a simple beep
  try {
    const audio = new Audio(
      "data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+D6uWkfBSx+z/LTfCgEHny+8t2OPggUYLLr6aRUEQlEnt/3uGoeEyh2y+DXgS0DBSp+0OPUnzEDBSd+0OHWoBECBSZ7z+DTpBUCD10zyubbtyUdBShwztfwSBYIAFa+29zxWBgIAUW+29vBsiUeC0Oz0d1mNy0DBUyX4t7eSxgKAlW9x9tXNjMDBU+U3+DeSBsEAFe7yNpENDAEAUW0z9pSTzIQAFev19d9PScGAUawy9haTzQZBUeqxtbwURgIAUm3yRJeNjEJAj8W2+LaD"
    );
    audio.volume = 0.1;
    audio.play().catch((e) => console.log("Could not play alert sound:", e));
  } catch (e) {
    console.log("Alert sound not available");
  }
}

// ===================================
// STATUS DISPLAY
// ===================================

function updateStatusDisplay(data) {
  const statusDisplay = document.getElementById("statusDisplay");
  const quickStatus = document.getElementById("quickStatus");
  const quickStation = document.getElementById("quickStation");

  if (data.show) {
    quickStatus.textContent = data.onDuty ? "On Duty" : "Off Duty";
    quickStation.textContent = data.station || "None";
    statusDisplay.style.display = "block";
  } else {
    statusDisplay.style.display = "none";
  }
}

// ===================================
// USER INTERACTIONS
// ===================================

function toggleDuty() {
  if (!currentData) return;

  if (currentData.onDuty) {
    // End duty
    fetch(`https://${GetParentResourceName()}/endDuty`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        station: currentData.station.id || "unknown",
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
        station: currentData.station.id || "unknown",
      }),
    });
  }
}

function closeUI() {
  fetch(`https://${GetParentResourceName()}/closeUI`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
}

// ===================================
// UTILITY FUNCTIONS
// ===================================

function getStationCode(job) {
  const codes = {
    fire: "FD-1",
    ambulance: "EMS-1",
    police: "PD-1",
  };
  return codes[job] || "UNIT-1";
}

function getStationAddress(station) {
  // This would normally come from the station configuration
  const addresses = {
    fire_station_1: "123 Fire Station Dr",
    ems_station_1: "456 Medical Center Blvd",
    police_station_1: "789 Mission Row",
  };
  return addresses[station.id] || "Unknown Address";
}

// ===================================
// KEYBOARD HANDLERS
// ===================================

document.addEventListener("keydown", function (event) {
  // ESC to close UI
  if (event.key === "Escape") {
    closeUI();
  }

  // Enter to toggle duty when UI is open
  if (event.key === "Enter" && currentData) {
    toggleDuty();
  }
});

// ===================================
// INITIALIZATION
// ===================================

document.addEventListener("DOMContentLoaded", function () {
  console.log("Flashing Lights UI loaded");

  // Hide UI initially
  document.getElementById("dutyUI").style.display = "none";
  document.getElementById("statusDisplay").style.display = "none";
});

// ===================================
// ERROR HANDLING
// ===================================

window.addEventListener("error", function (event) {
  console.error("UI Error:", event.error);
});

// Prevent context menu on right click
document.addEventListener("contextmenu", function (event) {
  event.preventDefault();
});

// ===================================
// RESOURCE NAME HELPER
// ===================================

function GetParentResourceName() {
  return "fl_core"; // This should match your resource name
}
