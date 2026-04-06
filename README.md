# 🍏 iOS-Emulator-Lab: QEMU-iOS on Android

![License](https://img.shields.io/badge/License-Research_Only-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android_Termux-green.svg)
![Architecture](https://img.shields.io/badge/Arch-AArch64-orange.svg)

An automated toolchain and installer to build and run the **devos50/qemu-ios** emulator (iPod Touch 2G / S5L8720) directly on Android. This project leverages **Termux-X11** for hardware-accelerated display and **Openbox** for window management.

---

## 🌟 Features
* **Automatic Build:** Compiles QEMU from source optimized for the `ipod_touch_2g` branch.
* **ROM Auto-Provisioning:** Downloads required BootROM, NOR, and NAND images from official release assets.
* **GUI Ready:** Pre-configured for Termux-X11 and Openbox for a seamless desktop experience.
* **One-Click Launch:** Includes a startup script that handles display variables, window management, and QEMU arguments automatically.

---

## 📋 Prerequisites

To run this lab successfully, your device should meet the following specifications:

| Requirement | Minimum | Recommended |
| :--- | :--- | :--- |
| **Storage** | 4GB Free | 8GB Free |
| **RAM** | 4GB | 8GB+ |
| **Android** | v10 | v12+ |
| **App** | [Termux-X11 APK](https://github.com/termux/termux-x11/releases) | Latest Debug Build |

> [!IMPORTANT]
> You **must** install the Termux-X11 companion APK on your Android device for the graphical interface to work.

---

## 🚀 Installation & Setup

### 1. Prepare Termux
Ensure your Termux environment is updated and has storage access:
```bash
1- Setup storage + Update
termux-setup-storage
pkg update && pkg upgrade -y

2. Run the Installer
Download the install_ios.sh script, make it executable, and run it:
cd ipod
chmod +x install_ios.sh
./install_ios.sh

Note: The compilation process takes 15–40 minutes depending on your CPU speed.

``` 
## 🖥️ Launching the Emulator
 * Open the Termux-X11 app on your phone.
 * Switch back to Termux and run the launch script:
   bash ~/start-ios.sh 

 * Switch back to the Termux-X11 app. A window will open automatically with the QEMU terminal and the emulator output. 

## 📂 Directory Layout
After installation, your home directory will contain:
 * ~/qemu-ios/ — The source code and compiled binaries.
 * ~/ios-workspace/ — The emulator working directory.
   * ~/ios-workspace/roms/ — BootROM and NOR files.
   * ~/ios-workspace/nand/ — Extracted NAND filesystem.
 * ~/start-ios.sh — Main launcher script.
## 🛠️ Troubleshooting
1. Compilation Failed (Step 6)
This is usually caused by the Android Phantom Process Killer or running out of RAM.
 * Fix: Edit install_ios.sh and change make -j$(nproc) to make -j2 to reduce memory pressure.
 * Fix: Disable "Child Process Restrictions" in your Android Developer Options.
2. Display Not Found
Ensure the Termux-X11 app is running in the background before you launch start-ios.sh.
3. Permission Denied
Ensure you have given Termux storage permissions and marked the scripts as executable:
chmod +x ~/start-ios.sh

## 📜 Credits & Disclaimer
 * QEMU-iOS Core: Developed by devos50.
 * UI Inspiration: UI framework inspired by Tech Jarves.
 * Legal Disclaimer: This project is for educational and security research purposes only. Apple ROMs and iOS software are proprietary; ensure you have the legal right to use them before proceeding.
>
