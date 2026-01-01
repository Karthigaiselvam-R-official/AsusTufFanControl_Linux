#include "FanController.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QDebug>
#include <QThread>

FanController::FanController(QObject *parent) 
    : QObject(parent), 
      m_manualMode(false),
      m_currentFanSpeed(0),
      m_useACPICalls(false),
      m_hasPWMControl(false),
      m_hasThermalPolicy(false),
      m_useDirectEC(false),
      m_acpiMethod(""),
      m_enforcementTimer(nullptr),
      m_statsTimer(nullptr),
      m_gpuProcess(nullptr)
{
    setStatusMessage(tr("Initializing..."));
    
    // Async GPU Process
    m_gpuProcess = new QProcess(this);
    connect(m_gpuProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &FanController::onGpuProcessFinished);

    // Stats Timer (1s) - Decouples I/O from Render Loop
    m_statsTimer = new QTimer(this);
    m_statsTimer->setInterval(1000);
    connect(m_statsTimer, &QTimer::timeout, this, &FanController::updateStats);
    m_statsTimer->start();
    
    // Timer to enforce manual mode if BIOS tries to take over
    m_enforcementTimer = new QTimer(this);
    m_enforcementTimer->setInterval(1500); // Check every 1.5s
    connect(m_enforcementTimer, &QTimer::timeout, this, &FanController::enforceManualMode);
    
    // Initialize immediately
    initializeController();
}

FanController::~FanController()
{
    // Ensure GPU process is stopped before destruction
    if (m_gpuProcess) {
        if (m_gpuProcess->state() != QProcess::NotRunning) {
            m_gpuProcess->terminate();
            if (!m_gpuProcess->waitForFinished(500)) {
                m_gpuProcess->kill();
                m_gpuProcess->waitForFinished(100);
            }
        }
    }

    // Safety measure: Always revert to Auto mode when closing
    enableAutoMode();
}

bool FanController::initializeController()
{
    qInfo() << "=== Initializing ASUS TUF F15 Fan Controller ===";
    
    // Step 1: Check for acpi_call module (Best for direct control)
    if (QFile::exists("/proc/acpi/call")) {
        m_useACPICalls = true;
        qInfo() << "✓ acpi_call module detected - using direct ACPI control";
    } else {
        qWarning() << "✗ acpi_call module not found";
        qWarning() << "   Install with: sudo apt install acpi-call-dkms && sudo modprobe acpi_call";
    }
    
    // Step 2: Find standard sensor paths (Temps/RPM)
    findPaths();
    
    // Step 3: Detect ACPI methods if module exists
    if (m_useACPICalls) {
        detectACPIMethods();
    }
    
    // Step 4: Try WMI as well (Required for Thermal Policy/Turbo unlocking)
    findWMIPaths();
    
    // Set status based on what we found
    bool ecProbeFound = QFile::exists("/bin/ec_probe");
    if (ecProbeFound) {
        qInfo() << "✓ ec_probe tool found - enabling Force EC Mode";
        m_useDirectEC = true;
    }

    if (m_useACPICalls && !m_acpiPaths.isEmpty()) {
        setStatusMessage(tr("Ready - Using Direct ACPI Control"));
        return true;
    } else if (m_hasPWMControl) {
        setStatusMessage(tr("Ready - Using WMI PWM Control"));
        return true;
    } else if (m_hasThermalPolicy) {
        setStatusMessage(tr("Ready - Using Thermal Policy"));
        return true;
    } else if (m_useDirectEC) {
        setStatusMessage(tr("Ready - Using Direct EC Injection (Driverless)"));
        return true;
    }

    
    setStatusMessage(tr("Error: No fan control methods found. Run with sudo?"));
    return false;
}

void FanController::detectACPIMethods()
{
    qInfo() << "Detecting ACPI fan control methods...";
    
    // Common ASUS ACPI paths for Fan Control (SFNV = Set Fan Value)
    // These paths are specific to ASUS TUF/ROG motherboards
    QStringList testPaths = {
        "\\_SB.PCI0.LPCB.EC0.SFNV",  // Most common on TUF FX506
        "\\_SB.PCI0.SBRG.EC0.SFNV",  // Alternative chipset path
        "\\_SB.PCI0.LPCB.EC.SFNV",   // Generic ASUS
        "\\_SB.PCI0.SBRG.EC.SFNV",
        "\\_SB.ATKD.QMOD",            // Older ATK Method
        // "\\_SB.ATKD.SPLV",         // REMOVED: Controls Keyboard Backlight, not Fans
        "\\_SB.PCI0.LPCB.EC0.ST98",  // Specific to some TUF models
        "\\_SB.PCI0.SBRG.EC0.ST98",
        // Newer TUF Models (2021+)
        "\\_SB_.PCI0.LPCB.EC0.VPC0.SFNV",
        "\\_SB.AMW0.SFNV",
        "\\_SB.PCI0.SBRG.EC0.FANC",
        "\\_SB.PCI0.LPCB.EC0.FANC",
        "\\_SB.PCI0.LPCB.EC0.FANL",
        "\\_SB.PCI0.SBRG.EC0.FANL",
        "\\_SB.PCI0.LPCB.EC.FANL"
    };
    
    m_acpiPaths.clear();
    
    for (const QString &path : testPaths) {
        // Test if the method exists by sending a harmless command (Fan 0 speed 0)
        // We look for a response that isn't "AE_NOT_FOUND"
        QString testCmd;
        if (path.contains("SPLV")) {
            // For SPLV, test with a valid argument like 0xA (10)
            testCmd = QString("%1 0xA").arg(path);
        } else if (path.contains("FANL")) {
            // FANL is usually "Fan Level". Test with a safe value like 0 or 50.
            // Often it takes 1 arg.
            testCmd = QString("%1 50").arg(path); 
        } else if (path.contains("SFNV") || path.contains("FANC") || path.contains("ST98")) {
            // For SFNV/FANC/ST98, test with 0 0 (index 0, value 0)
            testCmd = QString("%1 0 0").arg(path);
        } else {
            // For other methods like QMOD, just test existence without args
            testCmd = path;
        }

        QString result = callACPI(testCmd);
        
        if (!result.contains("Error") && !result.contains("not found")) {
            m_acpiPaths.append(path);
            qInfo() << "✓ Found valid ACPI method:" << path;
        }
    }
    
    if (m_acpiPaths.isEmpty()) {
        qWarning() << "✗ No known ACPI fan control methods found.";
    } else {
        qInfo() << "Using primary ACPI path:" << m_acpiPaths.first();
    }
}

QString FanController::callACPI(const QString &command)
{
    if (!QFile::exists("/proc/acpi/call")) {
        return "Error: acpi_call not available";
    }
    
    QFile acpiCall("/proc/acpi/call");
    
    // Write the command to the kernel module
    if (!acpiCall.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to open /proc/acpi/call for writing. Check sudo.";
        return "Error: Cannot open acpi_call";
    }
    
    QTextStream out(&acpiCall);
    out << command;
    acpiCall.close();
    
    // Read the result from the kernel module
    if (!acpiCall.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open /proc/acpi/call for reading.";
        return "Error: Cannot read acpi_call";
    }
    
    QTextStream in(&acpiCall);
    QString response = in.readAll().trimmed();
    acpiCall.close();
    
    return response;
}

bool FanController::setFanSpeedACPI(int percentage)
{
    if (m_acpiPaths.isEmpty()) return false;
    
    QString acpiPath = m_acpiPaths.first();
    bool success = true;

    // Handle SPLV (0-10 Scale)
    if (acpiPath.contains("SPLV")) {
        // Map 0-100% to 0-10
        int acpiArg = percentage / 10;
        if (percentage > 0 && acpiArg == 0) acpiArg = 1; // Minimum speed
        if (percentage >= 100) acpiArg = 10; // Max speed (0xA)
        
        qInfo() << "ACPI Call: " << acpiPath << " (" << acpiArg << ")";
        QString cmd = QString("%1 %2").arg(acpiPath).arg(acpiArg);
        QString result = callACPI(cmd);
        if (result.contains("Error")) {
            success = false;
        }
        if (result.contains("Error")) {
            success = false;
        }
    } 
    // Handle FANL (Typical ASUS Fan Level)
    else if (acpiPath.contains("FANL")) {
        // FANL usually expects 0-100 or 0-255. 
        // Given it's a "Level", let's assume 0-100 first? 
        // Actually on ASUS N-series, FANL is often 0-255.
        // Let's safe bet: 255 scale.
        int val = static_cast<int>((percentage / 100.0) * 255);
        if (percentage >= 100) val = 255;
        if (percentage > 0 && val == 0) val = 1;

        // FANL(Value) - Single Fan Control (usually controlling both tied together)
        QString cmd = QString("%1 %2").arg(acpiPath).arg(val);
        QString res = callACPI(cmd);
        if (res.contains("Error")) success = false;
    }
    // Handle Standard 0-255 methods (SFNV, FANL, etc.)
    else {
        // ASUS EC usually expects 0-255 for fan speed
        int fanValue = static_cast<int>((percentage / 100.0) * 255);
        
        // Ensure 100% is truly MAX (255)
        if (percentage >= 100) fanValue = 255;
        
        // On some TUF models, 0 might mean "Auto", so we use 1 as minimum for manual "Low"
        if (percentage > 0 && fanValue == 0) fanValue = 1;
        
        // SFNV usually takes (Index, Value) or just (Value) depending on model.
        // Standard ASUS is: Method(Index, Value) where Index 0=CPU, 1=GPU.
        
        // Set CPU Fan (Index 0)
        QString cmdCPU = QString("%1 0 %2").arg(acpiPath).arg(fanValue);
        QString resultCPU = callACPI(cmdCPU);
        
        if (resultCPU.contains("Error")) {
            success = false;
        }
        
        // Set GPU Fan (Index 1)
        QString cmdGPU = QString("%1 1 %2").arg(acpiPath).arg(fanValue);
        QString resultGPU = callACPI(cmdGPU);
        if (resultGPU.contains("Error")) success = false; // GPU might fail on some models, not critical if CPU works
    }
    
    return success;
}

void FanController::setFanSpeed(int percentage)
{
    // Clamp percentage
    if (percentage < 0) percentage = 0;
    if (percentage > 100) percentage = 100;
    
    m_currentFanSpeed = percentage;
    
    // Update UI state and start enforcement
    if (!m_manualMode) {
        m_manualMode = true;
        emit manualModeChanged();
        m_enforcementTimer->start();
        enforceManualMode(); // Apply immediately
    } else {
        enforceManualMode(); // Apply immediately if already in manual mode
    }
    
    bool success = false;
    
    // REVISED STRATEGY: Smart Mode Mapper
    // Hardware is locked, so we map slider to Thermal Policies (Performance Profiles).
    // 0-33%   -> Silent (Policy 2)
    // 34-66%  -> Balanced (Policy 0)
    // 67-100% -> Turbo (Policy 1)
    
    if (m_hasThermalPolicy) {
        int targetPolicy = 0; // Default to Balanced (Medium)

        if (percentage < 34) {
            targetPolicy = 2; // Silent
        } else if (percentage < 67) {
            targetPolicy = 0; // Balanced
        } else {
            targetPolicy = 1; // Turbo
        }
        
        int currentPolicy = readIntFromFile(m_wmiBasePath + "/throttle_thermal_policy");
        
        // Write only if changed to avoid spamming WMI
        if (currentPolicy != targetPolicy) {
            writeToSysfs(m_wmiBasePath + "/throttle_thermal_policy", targetPolicy);
            
            QString modeName;
            if (targetPolicy == 2) modeName = "Silent (0 RPM < 60°C)";
            else if (targetPolicy == 0) modeName = "Balanced (0 RPM < 60°C)";
            else modeName = "Turbo (Active Cooling)";
            
            qInfo() << "Switched Thermal Policy to" << modeName << "(" << targetPolicy << ")";
        }
        
        // Update UI Status
        QString modeName;
        if (targetPolicy == 2) modeName = tr("Silent (Absolute Quiet)");
        else if (targetPolicy == 0) modeName = tr("Balanced (Starts > 60°C)");
        else if (targetPolicy == 1) modeName = tr("Turbo (Always Active)");
        else modeName = tr("Unknown Mode"); // Fallback
        
        setStatusMessage(tr("Mode: %1").arg(modeName));
        emit statsUpdated();
        success = true;
    }
    
    // Attempt WMI PWM if available (unlikely on this model but harmless)
    if (m_hasPWMControl && !success) {
        // Convert to PWM 0-255
        int pwmValue = static_cast<int>((percentage / 100.0) * 255);
        if (percentage >= 100) pwmValue = 255;
        
        // Enable manual mode
        writeToSysfs(m_wmiHwmonPath + "/pwm1_enable", 1);
        writeToSysfs(m_wmiHwmonPath + "/pwm2_enable", 1);
        
        success = writeToSysfs(m_wmiHwmonPath + "/pwm1", pwmValue);
        bool gpuSuccess = writeToSysfs(m_wmiHwmonPath + "/pwm2", pwmValue);
        
        if (success || gpuSuccess) {
            setStatusMessage(QString("Manual (WMI): %1%").arg(percentage));
            emit statsUpdated();
            return;
        }
    }

    if (!success) {
        setStatusMessage("Error: No fan control method available.");
    }
}

void FanController::enforceManualMode()
{
    // This function is called every 1.5s by the timer.
    // It re-sends the command to overwrite BIOS auto-adjustments.
    if (m_manualMode) {
        // Enforce the Mode Selection
        // This timer ensures the BIOS doesn't switch back to a "Default" mode automatically.
        if (m_hasThermalPolicy) {
            int targetPolicy = 0; // Default Balanced
            
            // Re-calculate target based on current slider value (m_currentFanSpeed)
            if (m_currentFanSpeed <= 33) targetPolicy = 2;       // Silent
            else if (m_currentFanSpeed <= 66) targetPolicy = 0;  // Balanced
            else targetPolicy = 1;                              // Turbo

            int currentPolicy = readIntFromFile(m_wmiBasePath + "/throttle_thermal_policy");
            if (currentPolicy != targetPolicy) {
                writeToSysfs(m_wmiBasePath + "/throttle_thermal_policy", targetPolicy);
                // qInfo() << "Re-enforcing Policy:" << targetPolicy;
            }
        }

    }
    
    // Safety Watchdog: If in manual mode > 80% but RPM is 0 for too long, revert!
    if (m_manualMode && m_currentFanSpeed > 80 && getCpuFanRpm() == 0) {
        static int stallCounter = 0;
        stallCounter++;
        if (stallCounter > 10) { // ~15 seconds
            qWarning() << "Safety Watchdog: Fans stalled! Reverting to Auto.";
            enableAutoMode();
            stallCounter = 0;
        }
    } else {
        static int stallCounter = 0;
        stallCounter = 0;
    }

}

void FanController::enableAutoMode()
{
    m_manualMode = false;
    emit manualModeChanged();
    m_enforcementTimer->stop();
    
    qInfo() << "Reverting to Auto Mode...";
    
    // 1. Reset ACPI (Usually writing 0 or specific auto arg)
    if (m_useACPICalls && !m_acpiPaths.isEmpty()) {
        QString path = m_acpiPaths.first();
        // Sending 0 usually returns control to auto
        callACPI(QString("%1 0 0").arg(path)); // CPU Auto
        callACPI(QString("%1 1 0").arg(path)); // GPU Auto
    }
    
    // 2. Reset WMI PWM (2 = Auto)
    if (m_hasPWMControl) {
        writeToSysfs(m_wmiHwmonPath + "/pwm1_enable", 2);
        writeToSysfs(m_wmiHwmonPath + "/pwm2_enable", 2);
    }
    
    // 3. Reset Thermal Policy (0 = Balanced)
    if (m_hasThermalPolicy) {
        writeToSysfs(m_wmiBasePath + "/throttle_thermal_policy", 0);
    }
    
    setStatusMessage("Auto Mode (BIOS Control)");
    emit statsUpdated();
}

void FanController::testECAccess()
{
    qInfo() << "=== Diagnostic Test ===";
    detectACPIMethods();
    findWMIPaths();
    qInfo() << "ACPI Found:" << !m_acpiPaths.isEmpty();
    qInfo() << "PWM Found:" << m_hasPWMControl;
}

bool FanController::findWMIPaths()
{
    // Search for ASUS WMI platform device in sysfs
    QDir devicesDir("/sys/devices/platform/");
    QStringList devices = devicesDir.entryList(QStringList() << "asus*", QDir::Dirs);
    
    for (const QString &device : devices) {
        QString basePath = "/sys/devices/platform/" + device;
        
        // Check for Thermal Policy file
        if (QFile::exists(basePath + "/throttle_thermal_policy")) {
            m_wmiBasePath = basePath;
            m_hasThermalPolicy = true;
            qInfo() << "✓ Found Thermal Policy at:" << basePath;
        }
        
        // Check for HWMON directory (PWM control) inside WMI device
        QDir hwmonDir(basePath + "/hwmon");
        QStringList hwmons = hwmonDir.entryList(QStringList() << "hwmon*", QDir::Dirs);
        if (!hwmons.isEmpty()) {
            m_wmiHwmonPath = basePath + "/hwmon/" + hwmons.first();
            if (QFile::exists(m_wmiHwmonPath + "/pwm1")) {
                m_hasPWMControl = true;
                qInfo() << "✓ Found WMI PWM control at:" << m_wmiHwmonPath;
                return true; // Found primary control, return
            }
        }
    }
    return m_hasPWMControl || m_hasThermalPolicy;
}

bool FanController::writeToSysfs(const QString &path, int value)
{
    // Security Fix: Whitelist allowed paths
    // Only allow writing to ASUS WMI paths to prevent arbitrary file overwrite
    if (!path.startsWith("/sys/devices/platform/asus") && 
        !path.startsWith("/sys/class/hwmon")) {
        qWarning() << "Security Block: Attempted write to unauthorized path:" << path;
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        // Silent failure is common if permission denied or file missing
        return false;
    }
    QTextStream out(&file);
    out << value;
    file.close();
    file.close();
    return true;
}

bool FanController::writeECRegister(int reg, int value)
{
    if (!QFile::exists("/bin/ec_probe")) return false;
    
    QProcess proc;
    // Format: ec_probe write <reg_int> <val_int>
    QStringList args;
    args << "write" << QString::number(reg) << QString::number(value);
    
    proc.start("/bin/ec_probe", args);
    proc.waitForFinished(500); // Fast timeout
    
    return (proc.exitCode() == 0);
}

void FanController::findPaths()
{
    QDir hwmonDir("/sys/class/hwmon/");
    QFileInfoList list = hwmonDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);

    for (const QFileInfo &fileInfo : list) {
        QString path = fileInfo.absoluteFilePath();
        QFile nameFile(path + "/name");
        
        if (nameFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString name = QTextStream(&nameFile).readAll().trimmed();
            nameFile.close();
            
            // Map known sensor names to internal variables
            if (name == "coretemp") {
                m_tempPath = path; // Intel CPU temp
            } else if (name == "asus") {
                m_rpmPath = path;  // Standard ASUS sensor path
            } else if (name == "amdgpu" || name.contains("nvidia")) {
                m_gpuTempPath = path; // GPU Temp
            }
        }
    }
}

int FanController::readIntFromFile(QString path)
{
    if (path.isEmpty()) return 0;
    
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return 0;
    
    QTextStream in(&file);
    return in.readAll().trimmed().toInt();
}

void FanController::setStatusMessage(const QString &msg)
{
    if (m_statusMessage != msg) {
        m_statusMessage = msg;
        emit statusMessageChanged();
    }
}

int FanController::getCpuFanRpm()
{
    return m_cachedCpuFanRpm;
}

int FanController::getGpuFanRpm()
{
    return m_cachedGpuFanRpm;
}

int FanController::getCpuTemp()
{
    return m_cachedCpuTemp;
}

int FanController::getGpuTemp()
{
    return m_cachedGpuTemp;
}

void FanController::updateStats()
{
    // 1. CPU Fan RPM
    // Try WMI path first (more reliable on TUF)
    int rpm = 0;
    if (!m_wmiHwmonPath.isEmpty()) {
        rpm = readIntFromFile(m_wmiHwmonPath + "/fan1_input");
    }
    // Fallback to generic ASUS sensor
    if (rpm <= 0 && !m_rpmPath.isEmpty()) {
        rpm = readIntFromFile(m_rpmPath + "/fan1_input");
    }
    m_cachedCpuFanRpm = rpm;

    // 2. GPU Fan RPM
    int gpuRpm = 0;
    if (!m_wmiHwmonPath.isEmpty()) {
        gpuRpm = readIntFromFile(m_wmiHwmonPath + "/fan2_input");
    }
    if (gpuRpm <= 0 && !m_rpmPath.isEmpty()) {
        gpuRpm = readIntFromFile(m_rpmPath + "/fan2_input");
    }
    m_cachedGpuFanRpm = gpuRpm;

    // 3. CPU Temp
    if (!m_tempPath.isEmpty()) {
        m_cachedCpuTemp = readIntFromFile(m_tempPath + "/temp1_input") / 1000;
    }

    // 4. GPU Temp (Async or File)
    bool gpuRead = false;
    if (!m_gpuTempPath.isEmpty()) {
        int t = readIntFromFile(m_gpuTempPath + "/temp1_input"); 
        if (t <= 0) t = readIntFromFile(m_gpuTempPath + "/temp");
        
        if (t > 0) {
            m_cachedGpuTemp = t / 1000;
            gpuRead = true;
        }
    }
    
    // If file read failed, try nvidia-smi ASYNC
    if (!gpuRead && m_gpuProcess) {
        if (m_gpuProcess->state() == QProcess::NotRunning) {
            m_gpuProcess->start("nvidia-smi", QStringList() << "--query-gpu=temperature.gpu" << "--format=csv,noheader,nounits");
        }
    }
    
    emit statsUpdated();
}

void FanController::onGpuProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    Q_UNUSED(status);
    if (exitCode == 0) {
        QString out = m_gpuProcess->readAllStandardOutput().trimmed();
        bool ok;
        int val = out.toInt(&ok);
        if (ok) {
            m_cachedGpuTemp = val;
            emit statsUpdated(); // Notify change immediately
        }
    }
}