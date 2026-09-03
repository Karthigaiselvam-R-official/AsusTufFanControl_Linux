<div align="center">

# 🎮 ASUS TUF Fan Control



![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Language](https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=c%2B%2B&logoColor=white)
![Framework](https://img.shields.io/badge/Qt6-41CD52?style=for-the-badge&logo=qt&logoColor=white)
![Build](https://img.shields.io/badge/CMake-064F8C?style=for-the-badge&logo=cmake&logoColor=white)
![License](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge)
![Translations](https://img.shields.io/badge/Translations-22_Languages-orange?style=for-the-badge&logo=google-translate&logoColor=white)

**A powerful system control utility for ASUS Gaming Laptops on Linux**

*Open-source alternative to Armoury Crate & G-Helper*

</div>

---

## 📸 Screenshots

<table>
  <tr>
    <td><img src="resources/SystemInfo.png" width="400" alt="Dashboard"></td>
    <td><img src="resources/FanControl.png" width="400" alt="Fan Control"></td>
  </tr>
  <tr>
    <td align="center"><b>System Dashboard</b></td>
    <td align="center"><b>Fan Control</b></td>
  </tr>
  <tr>
    <td><img src="resources/AuraSync.png" width="400" alt="Aura Sync"></td>
    <td><img src="resources/BatteryManagement.png" width="400" alt="Battery"></td>
  </tr>
  <tr>
    <td align="center"><b>Aura Sync RGB</b></td>
    <td align="center"><b>Battery Management</b></td>
  </tr>
</table>

---

## ✨ Features

### 🌀 Fan Control
- Real-time RPM monitoring for CPU & GPU fans
- **Manual Mode:** Silent / Balanced / Turbo performance modes
- **Auto Fan Curve:** Temperature-based automatic mode switching
- Visual animated fan indicators
- Automatic thermal management via ACPI/WMI

### 🎛️ Auto Fan Curve (NEW)
Intelligent temperature-based fan management that automatically switches between modes:

| Mode | Condition | Use Case |
|------|-----------|----------|
| **Silent** | CPU < Silent Threshold | Light tasks, quiet environment |
| **Balanced** | Between thresholds | Normal usage, web browsing |
| **Turbo** | CPU > Turbo Threshold | Gaming, heavy workloads |

**Built-in Presets:**
- 🎮 **Gaming** – Silent ≤40°C, Turbo ≥60°C (aggressive cooling)
- ⚖️ **Balanced** – Silent ≤50°C, Turbo ≥70°C (default)
- 🔇 **Quiet** – Silent ≤65°C, Turbo ≥80°C (prioritize silence)
- 🚀 **Performance** – Silent ≤35°C, Turbo ≥50°C (max cooling)

### 🔋 Battery Health
- Charge limiting (60% / 80% / 100%) to extend battery lifespan
- Real-time charging status
- Persistent settings across reboots

### 💡 Aura Sync RGB
- Keyboard backlight control
- Multiple effects: Static, Breathing, Strobing, Rainbow
- Custom color picker
- Brightness adjustment

### 📊 System Dashboard
- CPU/GPU temperature & utilization
- Memory and disk usage
- Network activity monitoring
- MTP device detection (Android phones, cameras)

### 🎨 Premium UI
- Modern glassmorphic design
- Dark / Light mode support
- Responsive sidebar navigation
- Built with Qt6/QML

### 🌍 Global Language Support
- Fully translated into **22 languages** including:
  **Tamil**, Bengali, Spanish, French, German, Chinese, Japanese, Korean, Russian, Portuguese, Italian, Arabic, Turkish, Hindi, and more.
- Automatic system language detection
- Right-to-Left (RTL) layout support (Arabic, Farsi, Urdu)

---

## �️ Supported Hardware

| Series | Models |
|--------|--------|
| **TUF Gaming** | F15, F17, A15, A17, Dash F15 |
| **ROG Strix** | G15, G17, Scar 15, Scar 17, G512, G513, G531, G713, G733 |
| **ROG Zephyrus** | G14, G15, M15, M16 |
| **ROG Flow** | X13, X16, Z13 |

### ✅ Tested Distributions
Ubuntu • Fedora • Arch Linux • Kali Linux • Manjaro • Pop!_OS

---

## 📋 Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Linux (Kernel 5.4+) |
| **Hardware** | ASUS TUF / ROG / Strix Gaming Laptop |
| **Modules** | `asus_wmi`, `asus_nb_wmi`, `acpi_call` (for 2nd fan) |
| **Dependencies** | Qt6, CMake, GCC, `acpi-call-dkms` |

---

## 📥 Installation

### 1️⃣ Install Hardware Prerequisites (Important for Dual Fans)
To ensure the application can detect and control secondary fans (especially on Zenbooks), install the `acpi_call` module:
```bash
sudo apt update
sudo apt install acpi-call-dkms
sudo modprobe acpi_call
```
> **Note:** If `modprobe` fails with "Operation not permitted" or "Key was rejected", you must **disable Secure Boot** in your BIOS for the custom module to load.

### 2️⃣ Clone the Repository
```bash
git clone https://github.com/Karthigaiselvam-R-official/AsusTufFanControl_Linux.git
cd AsusTufFanControl_Linux
```

### 3️⃣ Run Setup Script
```bash
chmod +x setup.sh
sudo ./setup.sh
```
> This installs dependencies, builds `ec_probe`, configures polkit, and sets up desktop integration.

### 4️⃣ Build the Application
```bash
mkdir build && cd build
cmake .. 
# (This automatically runs patch_translations.py to ensure all languages are up to date)
make -j$(nproc)
```

### 5️⃣ Install the Binary
```bash
sudo cp ./AsusTufFanControl_Linux /opt/asus-tuf-fan-control/
```

---

## ▶️ Running the Application

### 🖱️ Desktop (Recommended)
Launch **"ASUS TUF Fan Control"** from your Applications menu.
A password prompt will appear, then the app runs with elevated privileges.

### 💻 Terminal
```bash
sudo -E /opt/asus-tuf-fan-control/AsusTufFanControl_Linux
```

> **Note:** The `-E` flag is required to preserve your DBus user session (fixes UI and setting issues). Root privileges are required for EC/ACPI hardware access.

---

## 🔧 How It Works

```
┌─────────────────────────────────────────────────────┐
│                    Application                       │
├─────────────────────────────────────────────────────┤
│  Qt6/QML UI  →  C++ Backend  →  Hardware Control    │
└─────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌──────────┐
    │  ACPI   │    │   WMI    │    │    EC    │
    │  Call   │    │  Sysfs   │    │  Probe   │
    └─────────┘    └──────────┘    └──────────┘
         │               │               │
         └───────────────┴───────────────┘
                         │
                   Hardware Layer
            (Fans, Battery, RGB, Sensors)
```

**Fallback Chain:** ACPI → WMI Thermal Policy → WMI PWM → EC Probe

---

## ⚠️ Disclaimer

> **Use at your own risk.**

This tool manipulates low-level system hardware (Embedded Controller and ACPI methods).

- Improper fan settings could lead to overheating
- The authors are not responsible for any hardware damage
- Always monitor temperatures when adjusting fan curves

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the project
2. Create your feature branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m 'Add some AmazingFeature'`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a Pull Request

---

## 👤 Author

**Karthigaiselvam R**

[![Email](https://img.shields.io/badge/Email-karthigaiselvamr.cs2022%40gmail.com-red?style=flat-square&logo=gmail)](mailto:karthigaiselvamr.cs2022@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Karthigaiselvam_R-blue?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/karthigaiselvam-r-7b9197258/)

---

## 📄 License

**Source Available License:** Commons Clause + GNU General Public License v3.0

| ✅ Allowed | 🚫 Not Allowed |
|------------|----------------|
| Use freely | Sell the software |
| Modify code | Commercial services |
| Share code | Paid distribution |

See [LICENSE](LICENSE) for full text.

---

<div align="center">

**If you find this project useful, please ⭐ star the repository!**

Made with ❤️ for the ASUS Linux Community

</div>
