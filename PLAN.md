# Battery Automation Plan

This plan outlines the implementation of a battery-aware power management system for the Termux media server stack.

## 1. Modular Service Control (`service-control.sh`)
Create a centralized script to manage all services. This avoids logic duplication and makes it easier to add new services like Bazarr.
- **Services Managed:** Jellyfin, Radarr, Sonarr, Prowlarr, Transmission, Bazarr.
- **Commands:**
  - `start <service|all>`: Starts a specific service or all of them. Includes watchdog loops for stability.
  - `stop <service|all|eco>`: Stops a specific service, everything, or enters "Eco" mode (stopping everything except Jellyfin).
  - `status`: Shows which services are currently running.

## 2. Battery Monitoring (`battery-monitor.sh`)
A background script that polls battery status and enforces power states.
- **Threshold:** 50% battery level.
- **Logic:**
  - **Low Power Mode:** Triggered when Battery <= 50% AND NOT Charging.
    - Action: `service-control.sh stop eco`
  - **Full Power Mode:** Triggered when Battery > 50% OR Charging.
    - Action: `service-control.sh start all`
- **Interval:** Check every 2 minutes (configurable).
- **Wake Lock:** Ensures the monitor continues running even when the screen is off.

## 3. Integration with Existing Scripts
Update `start-server.sh` and `stop-server.sh` to act as wrappers for `service-control.sh`.
- `start-server.sh` -> `./service-control.sh start all && ./battery-monitor.sh --start`
- `stop-server.sh` -> `./service-control.sh stop all && ./battery-monitor.sh --stop`

## 4. Implementation Steps
1.  **Integrate Bazarr** into the startup/shutdown logic.
2.  **Create `service-control.sh`** with the refactored logic.
3.  **Create `battery-monitor.sh`** with the polling loop.
4.  **Validate** transitions by manually spoofing battery values or using a lower threshold for testing.

---

### Questions for the User:
- **Bazarr Start Command:** Is `python /data/data/com.termux/files/usr/opt/bazarr/bazarr.py` the correct way to start it?
- **Notifications:** Would you like a Termux notification when the server switches modes?
- **Tasker vs. Polling:** Polling is easier to set up within Termux. Tasker is more battery-efficient. Do you have a preference? (I will proceed with Polling for the test branch as it's self-contained).
