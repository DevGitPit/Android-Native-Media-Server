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

### 1. Update and Dependencies
```bash
pkg update -y && pkg upgrade -y
pkg install tur-repo -y
pkg install wget curl sqlite libicu mono libesqlite3 dotnet-runtime-9.0 jellyfin-server -y
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

1.  **Remove bundled glibc libraries:**
    ```bash
    rm $PREFIX/opt/[AppName]/*.so
    ```
2.  **Link native Android libraries:**
    ```bash
    ln -s $PREFIX/lib/libMonoPosixHelper.so $PREFIX/opt/[AppName]/
    ln -s $PREFIX/lib/libe_sqlite3.so $PREFIX/opt/[AppName]/
    ```
3.  **Disable the forced dependency check:**
    ```bash
    mv $PREFIX/opt/[AppName]/[AppName].deps.json $PREFIX/opt/[AppName]/[AppName].deps.json.bak
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

Before starting, it is recommended to set the `.NET` root environment variable so the applications can find the native runtime:

```bash
export DOTNET_ROOT=$PREFIX/lib/dotnet
```

| Service | Command | Access URL |
| :--- | :--- | :--- |
| **Jellyfin** | `jellyfin &` | `http://[YOUR_IP]:8096` |
| **Radarr** | `dotnet $PREFIX/opt/Radarr/Radarr.dll -nobrowser &` | `http://[YOUR_IP]:7878` |
| **Sonarr** | `dotnet $PREFIX/opt/Sonarr/Sonarr.dll -nobrowser &` | `http://[YOUR_IP]:8989` |
| **Prowlarr** | `dotnet $PREFIX/opt/Prowlarr/Prowlarr.dll -nobrowser &` | `http://[YOUR_IP]:9696` |

> **Pro-Tip:** Add `export DOTNET_ROOT=$PREFIX/lib/dotnet` to your `~/.bashrc` file so you don't have to type it every time.

---

## 📝 Maintenance
* **Stopping:** Use `pkill dotnet` or `pkill jellyfin`.
* **Restarting:** You will need to start these commands again after a phone reboot or Termux restart.
