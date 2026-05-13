# Android Media Server Guide: Native Termux Edition 🚀

This guide provides the definitive steps to run a high-performance media server (Jellyfin, Radarr, Sonarr, and Prowlarr) **100% natively** on Android via Termux. This method completely bypasses PRoot/Linux emulation, resulting in significantly lower CPU and RAM usage.

## 🛠️ Prerequisites
* **Android Device:** Android 8.0 or higher.
* **Termux (F-Droid):** Do not use the Play Store version.
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
pkg install wget curl sqlite libicu mono libesqlite3 ffmpeg dotnet-runtime-9.0 jellyfin-server -y
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
    Replace the contents of `$PREFIX/opt/[AppName]/[AppName].runtimeconfig.json` with:
    ```json
    {
      "runtimeOptions": {
        "tfm": "net9.0",
        "frameworks": [
          { "name": "Microsoft.NETCore.App", "version": "9.0.0" },
          { "name": "Microsoft.AspNetCore.App", "version": "9.0.0" }
        ]
      }
    }
    ```

---

## ▶️ Starting the Services

Before starting, it is recommended to set the `.NET` root and library path environment variables so the applications can find the native runtime and libraries:

```bash
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib
```

| Service | Command | Access URL |
| :--- | :--- | :--- |
| **Jellyfin** | `jellyfin &` | `http://[YOUR_IP]:8096` |
| **Radarr** | `dotnet $PREFIX/opt/Radarr/Radarr.dll -nobrowser &` | `http://[YOUR_IP]:7878` |
| **Sonarr** | `dotnet $PREFIX/opt/Sonarr/Sonarr.dll -nobrowser &` | `http://[YOUR_IP]:8989` |
| **Prowlarr** | `dotnet $PREFIX/opt/Prowlarr/Prowlarr.dll -nobrowser &` | `http://[YOUR_IP]:9696` |

> **Pro-Tip:** Add `export DOTNET_ROOT=$PREFIX/lib/dotnet` and `export LD_LIBRARY_PATH=$PREFIX/lib` to your `~/.bashrc` file so you don't have to type them every time.

---

## ▶️ Running the Server

Once installed, you can launch the entire stack (including Transmission and Jellyfin) using the master start script:

```bash
./start-server.sh
```

**Battery Automation:** The server now includes a background monitor that automatically manages power:
*   **Full Mode:** (Battery > 50% or Charging) All services run normally.
*   **Eco Mode:** (Battery ≤ 50% and Discharging) All services except Jellyfin are stopped to save battery.
*   **Notifications:** You will receive a Termux notification whenever the server switches modes.

To stop all services and the monitor:

```bash
./stop-server.sh
```

### 🛠️ Manual Service Control
You can use `./service-control.sh` for granular control:
*   `./service-control.sh status`: See what's running.
*   `./service-control.sh stop-eco`: Manually enter Eco Mode.
*   `./service-control.sh start-all`: Force start everything.

**Note on Stability:** The start script includes watchdogs for Radarr, Sonarr, and Prowlarr. If a service exits or crashes, it will automatically restart after a 10-second delay.

| Service | Access URL |
| :--- | :--- |
| **Jellyfin** | `http://[YOUR_IP]:8096` |
| **Radarr** | `http://[YOUR_IP]:7878` |
| **Sonarr** | `http://[YOUR_IP]:8989` |
| **Prowlarr** | `http://[YOUR_IP]:9696` |
| **Transmission** | `http://[YOUR_IP]:9091` |

---

## 🗑️ Uninstallation

If you wish to remove the media server and all its configurations:

### Automated Uninstall
```bash
# 1. Download the script
wget https://raw.githubusercontent.com/DevGitPit/Android-Native-Media-Server/main/uninstall_media_server.sh

# 2. Run it
chmod +x uninstall_media_server.sh && ./uninstall_media_server.sh
```

### Manual Cleanup
1.  **Stop services:** `pkill dotnet` and `pkill jellyfin`.
2.  **Remove folders:** `rm -rf $PREFIX/opt/{Radarr,Sonarr,Prowlarr}`.
3.  **Delete configs:** `rm -rf ~/.config/{Radarr,Sonarr,Prowlarr,jellyfin}`.
4.  **Uninstall packages:** `pkg uninstall dotnet-runtime-9.0 jellyfin-server mono libesqlite3 sqlite -y`.
5.  **Remove DOTNET_ROOT** from your `~/.bashrc`.
