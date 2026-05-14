# Android Media Server Guide: Native Termux Edition 🚀

This guide provides the definitive steps to run a high-performance media server (Jellyfin, Radarr, Sonarr, Prowlarr, and Bazarr) **100% natively** on Android via Termux. This method completely bypasses PRoot/Linux emulation, resulting in significantly lower CPU and RAM usage.

## 🛠️ Prerequisites
* **Android Device:** Android 8.0 or higher.
* **Termux (F-Droid):** Do not use the Play Store version.
* **Termux:API (F-Droid):** Required for battery automation and notifications.
* **TUR Repo:** Enabled for native packages.

---

## ⚙️ The Technical Challenge & Solution
The standard Linux ARM64 binaries for the *Arr stack are compiled for **glibc**. Android uses **Bionic**, which causes these binaries to fail.

**Our Solution:**
1.  Use the **Native Termux .NET Runtime** (`dotnet-runtime-9.0`).
2.  Install native Android versions of the required helper libraries (`libMonoPosixHelper.so` and `libe_sqlite3.so`).
3.  Configure the applications to run in **Framework-Dependent** mode rather than self-contained mode.

---

## 🚀 Installation Steps

### Option 1: Automated Setup (Recommended)
The easiest way to get started is to use the provided automation script. It handles all dependencies, library linking, and runtime configurations for you:

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/DevGitPit/Android-Native-Media-Server/main/setup_media_server.sh

# 2. Make it executable and run it
chmod +x setup_media_server.sh && ./setup_media_server.sh
```

---

### Option 2: Manual Installation (Step-by-Step)

### 1. Update and Dependencies
```bash
pkg update -y && pkg upgrade -y
pkg install tur-repo -y
pkg install wget curl sqlite libicu mono libesqlite3 ffmpeg jq termux-api dotnet-runtime-9.0 jellyfin-server -y
```

### 2. Setup the *Arr Stack
```bash
mkdir -p $PREFIX/opt

# Download and Extract (Radarr, Sonarr, Prowlarr)
# Note: Use the standard Linux ARM64 (core) downloads.
# Example for Radarr:
wget -O radarr.tar.gz "https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=arm64"
tar -xvzf radarr.tar.gz -C $PREFIX/opt/

# Repeat for Sonarr and Prowlarr using their respective URLs.
```

### 3. Native Optimization (CRITICAL)
For **each** application (Radarr, Sonarr, Prowlarr), you **MUST** perform the following:

1.  **Remove bundled glibc libraries & binaries:**
    ```bash
    rm $PREFIX/opt/[AppName]/*.so
    rm -f $PREFIX/opt/[AppName]/ffprobe
    rm -f $PREFIX/opt/[AppName]/ffmpeg
    ```
2.  **Link native Android libraries & binaries:**
    ```bash
    ln -s $PREFIX/lib/libMonoPosixHelper.so $PREFIX/opt/[AppName]/
    ln -s $PREFIX/lib/libe_sqlite3.so $PREFIX/opt/[AppName]/
    ln -s $PREFIX/bin/ffprobe $PREFIX/opt/[AppName]/
    ln -s $PREFIX/bin/ffmpeg $PREFIX/opt/[AppName]/
    ```
3.  **Patch the dependency manifest for .NET 9.0:**
    ```bash
    # This allows the app to find CoreCLR in the Termux environment
    sed -i 's/"6\.0\.0"/"9.0.0"/g' $PREFIX/opt/[AppName]/[AppName].deps.json
    ```
4.  **Update the Runtime Config:**
    Update `$PREFIX/opt/[AppName]/[AppName].runtimeconfig.json` to use `net9.0`.

---

## ▶️ Running the Server

Once installed, you can launch the entire stack using the master start script:

```bash
./start-server.sh
```

### 🧠 Smart Event-Driven Scheduler (New!)
The server now features an advanced, battery-efficient scheduling system that replaces constant background polling with Android-native job scheduling.

*   **Logic:** The system only wakes up the media stack if:
    1.  **Battery is healthy** (>50% or Charging).
    2.  **Media is missing** (A monitored show or movie aired > 1 hour ago).
    3.  **Active downloads** are present in Transmission.
*   **Dynamic Sleep:** If no media is due for release, the system enters a deep sleep. It calculates the exact time of the next release from the Sonarr/Radarr databases and schedules a wake-up call for **1 hour after release**.
*   **Heartbeat:** A 6-hour safety heartbeat ensures the system occasionally checks for metadata updates even during long idle periods.
*   **Interactive Control:** Notifications now include action buttons for quick management:
    *   **START:** Force-starts the entire stack and enables **Manual Override** (prevents automated shutdown).
    *   **ECO:** Stops non-essential services (Jellyfin only) and returns to **Automated Mode**.
    *   **STOP:** Gracefully shuts down all services including Jellyfin.

**Manual Control:**
*   `./service-control.sh status`: Check current service states.
*   `./check-needs.sh all`: See what the "Smart" logic currently detects.
*   `tail -f logs/scheduler.log`: Monitor the scheduler's decision-making process.

To stop all services and the scheduler:
```bash
./stop-server.sh
```

---

## 🛠️ Service Control & Monitoring
You can use `./service-control.sh` for granular control:
*   `smart-start`: Starts only the apps needed for current tasks.
*   `stop-eco`: Manually enter Eco Mode (Jellyfin only).
*   `start-all`: Force start everything.

**Note on Stability:** The stack includes watchdogs for Radarr, Sonarr, and Prowlarr. If a service exits or crashes, it will automatically restart after a 10-second delay.

---

## 🆙 Updating the Server

### 1. Radarr, Sonarr, and Prowlarr
You can update these directly from their respective Web UIs. However, because updates overwrite the native shims, you must perform a "Quick Fix" after the update completes:

1.  Click **Update** in the Web UI.
2.  Once finished, run: `./service-control.sh re-shim`
3.  Restart services: `./service-control.sh start-all`

### 2. Bazarr
Update via the Web UI. If the update breaks your custom Python requirements, simply run `./setup_media_server.sh` to restore your working configuration from `custom/bazarr/`.

### 3. Jellyfin & System Packages
Managed via the Termux package manager:
```bash
pkg upgrade
```

---

| Service | Access URL |
| :--- | :--- |
| **Jellyfin** | `http://[YOUR_IP]:8096` |
| **Radarr** | `http://[YOUR_IP]:7878` |
| **Sonarr** | `http://[YOUR_IP]:8989` |
| **Prowlarr** | `http://[YOUR_IP]:9696` |
| **Bazarr** | `http://[YOUR_IP]:6767` |
| **Transmission** | `http://[YOUR_IP]:9091` |

---

## 🔧 Custom Tweaks & Persistence
This repository supports custom file overrides (e.g., for hardware-specific Python `requirements.txt` in Bazarr).
*   Any files placed in `custom/bazarr/` will be automatically applied to the Bazarr installation directory during setup.
*   Use this to persist custom patches, configs, or library requirements that aren't part of the standard distribution.

> [!IMPORTANT]
> **Note for Users:** The `custom/bazarr/requirements.txt` included here contains specific tweaks (like pinning `numpy < 2.4.0`) to prevent segmentation faults on certain older Android hardware. If you are on a newer device or a different Termux environment, you may need to adjust these pins or remove them to match your system's current dependencies. Always check your startup logs if Bazarr fails to launch.

---

## 🗑️ Uninstallation

If you wish to remove the media server and all its configurations:

### Automated Uninstall
```bash
./uninstall_media_server.sh
```

### Manual Cleanup
1.  **Stop services:** `./stop-server.sh`.
2.  **Remove folders:** `rm -rf $PREFIX/opt/{Radarr,Sonarr,Prowlarr}`.
3.  **Delete configs:** `rm -rf ~/.config/{Radarr,Sonarr,Prowlarr,jellyfin}`.
4.  **Uninstall packages:** `pkg uninstall dotnet-runtime-9.0 jellyfin-server mono libesqlite3 sqlite jq termux-api -y`.
