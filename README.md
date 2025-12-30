# ASUS TUF Fan Controller (Linux)


<table>
  <tr>
    <td><img src="resources/SystemInfo.png" width="400" alt="Dashboard"></td>
    <td><img src="resources/FanControl.png" width="400" alt="Fan Control"></td>
  </tr>
  <tr>
    <td><img src="resources/AuraSync.png" width="400" alt="Aura Sync"></td>
    <td><img src="resources/BatteryManagement.png" width="400" alt="Battery"></td>
  </tr>
</table>

![Platform](https://img.shields.io/badge/Platform-Linux-linux?style=flat-square&logo=linux)
![Language](https://img.shields.io/badge/Language-C%2B%2B-00599C?style=flat-square&logo=c%2B%2B)
![Framework](https://img.shields.io/badge/Framework-Qt6-41CD52?style=flat-square&logo=qt)
![Build](https://img.shields.io/badge/Build-CMake-064F8C?style=flat-square&logo=cmake)

A powerful, expert-level system control utility for **ASUS TUF** and **ROG** laptops running Linux. This application provides granular control over fans, battery health, RGB lighting, and performance profiles, serving as a comprehensive **open-source alternative to Armoury Crate** and **G-Helper** for Linux users.

> [!NOTE]
> **🚧 Work In Progress**: I am actively working to improve this project and adding many new features. Stay tuned for updates!

## 🚀 Supported Models
Optimized for the entire ASUS Gaming lineup:
*   **ASUS TUF Gaming** (F15, F17, A15, A17, Dash F15)
*   **ASUS ROG Strix** (G15, G17, Scar 15, Scar 17)
*   **ASUS ROG Zephyrus** (G14, G15, M15, M16)
*   **ASUS ROG Flow** (X13, X16, Z13)

It works flawlessly on all major distributions including **Ubuntu**, **Fedora**, **Arch Linux**, **Kali Linux**, **Manjaro**, and **Pop!_OS**.

## ⚙️ Key Features

*   **Advanced Fan Control**
    *   Real-time RPM monitoring for CPU and GPU fans.
    *   Manual fan speed control with easy-to-use sliders.
    *   Visual spinning animations synced to active state.
    *   Automatic thermal management.

*   **Battery Health Management**
    *   **Charge Limiting:** Prolong battery lifespan by capping charge at 60%, 80%, or 100%.
    *   Real-time status monitoring.

*   **Aura Sync RGB Control**
    *   Customize keyboard lighting effects (Static, Breathing, Strobing).
    *   Color selection and brightness control.
    *   Multi-zone support.

*   **System Performance**
    *   **Dashboard:** Comprehensive overview of CPU/GPU temperatures and utilization.
    *   **Performance Modes:** Toggle between Silent, Balanced, and Turbo power profiles.

*   **Premium UI**
    *   Modern, Glassmorphic design using Qt6/QML.
    *   Dark Mode / Light Mode support.
    *   Responsive Sidebar navigation.

## 📋 Prerequisites

*   **OS:** Linux (Tested on Kali Linux, compatible with Ubuntu/Debian derivatives).
*   **Hardware:** ASUS TUF Gaming F15 / A15 or similar ROG laptops.
*   **Kernel:** Requires `asus_wmi` and `asus_nb_wmi` modules.

## 📥 Installation

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/Karthigaiselvam-R-official/AsusTufFanControl_Linux.git
    cd AsusTufFanControl_Linux
    ```

2.  **Run the Setup Script:**
    This script installs necessary system dependencies, builds the low-level `ec_probe` tool, and configures permissions.
    ```bash
    chmod +x setup.sh
    sudo ./setup.sh
    ```
    *Note: A reboot is recommended after running the setup script.*

3.  **Build the Application:**
    ```bash
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    ```

## ▶️ Running the Application

Due to the need for direct hardware access (EC read/write), the application must currently be run with root privileges:

```bash
sudo ./AsusTufFanControl_Linux
```

## ⚠️ Disclaimer

This tool manipulates low-level system hardware (Embedded Controller and ACPI methods). While designed with safety in mind:
*   **Use at your own risk.**
*   Improper fan settings could lead to overheating.
*   The authors are not responsible for any hardware damage.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 👤 Author

**Name: Karthigaiselvam R**
* Email: karthigaiselvamr.cs2022@gmail.com
* LinkedIn: [Karthigaiselvam R](https://www.linkedin.com/in/karthigaiselvam-r-7b9197258/)

## 📄 License

**Source Available License:** Distributed under the **commons Clause** + **GNU General Public License v3.0**.

This project uses the GPLv3 terms for open contribution and sharing, with the **Commons Clause** added to **strictly prohibit selling** the software.

*   ✅ **You CAN:** Use, modify, and share the code freely.
*   🚫 **You CANNOT:** Sell the software or offer it as a commercial service for a fee.

See `LICENSE` for the full text.
