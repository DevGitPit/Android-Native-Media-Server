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

### Option 1: Native Packages (Best Performance)
The most efficient way to run these apps is using native Termux packages. This eliminates the need for manual library linking and shimming.

```bash
pkg install radarr sonarr prowlarr -y
```

### Option 2: Automated Setup (Legacy Support)
If you prefer a managed setup or need a specific version, use the provided script. It handles all dependencies, library linking, and runtime configurations:

```bash
bash ./setup_media_server.sh
```

---

### 🛠️ Manual Service Control & Automation Modes
The server uses a **Pilot/Auto-pilot** system to manage power and manual interventions:

*   **Auto-pilot Mode 🤖**: The default mode. The `battery-monitor.sh` background script manages services based on battery level (Full vs. Eco).
*   **Pilot (Manual) Mode 🕹️**: Triggered automatically whenever you run a manual service command. The battery monitor will **stop** overriding your choices until you return to Auto-pilot.

#### **Available Commands**
Use `./service-control.sh <command>` to manage the stack:

| Command | Description |
| :--- | :--- |
| **`status`** | Shows current services and whether you are in `AUTO` or `MANUAL` mode. |
| **`auto`** | **Resume Auto-pilot**. Clears manual overrides and enforces battery rules immediately. |
| **`start-all`** | Starts every service and enters Manual Mode. |
| **`stop-all`** | Stops every service and enters Manual Mode. |
| **`stop-eco`** | Stops everything except Jellyfin (and active Transmission) and enters Manual Mode. |
| **`start-<app>`** | Start a specific app (e.g., `start-sonarr`). Enters Manual Mode. |
| **`stop-<app>`** | Stop a specific app (e.g., `stop-radarr`). Enters Manual Mode. |
| **`re-shim`** | Re-applies native library patches after an app update. |

> [!TIP]
> **Example:** If you want to keep Sonarr running while charging even if the battery is low, just run `./service-control.sh start-sonarr`. The monitor will "stand down" and let you work. When finished, run `./service-control.sh auto` to let the battery logic take back over.

---

## 🌟 Extra Features

### Overserr / Jellyseerr Support
This repository includes a native installer for **Seerr** (a request management tool for your media stack). 
```bash
./install-seerr.sh
```
*It handles dependencies (Node.js, Python), fetches the source, and applies native patches for the Termux environment.*

---

## ▶️ Running the Server

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
