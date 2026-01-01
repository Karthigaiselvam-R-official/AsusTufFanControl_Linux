#include <QDesktopServices>
#include <QUrl>
#include "SystemStatsMonitor.h"
#include <QSet>

SystemStatsMonitor::SystemStatsMonitor(QObject *parent) : QObject(parent)
{
    // Main stats timer - 0.5 second for instant UI (safe now due to async GPU)
    m_timer = new QTimer(this);
    m_timer->setInterval(500);  // 0.5s update for snappy USB/Graph response
    connect(m_timer, &QTimer::timeout, this, &SystemStatsMonitor::updateStats);
    m_timer->start();
    
    // Slow timer for heavy I/O operations (disk, network) - every 2 seconds
    m_slowTimer = new QTimer(this);
    m_slowTimer->setInterval(2000);  // 2s backup poll
    connect(m_slowTimer, &QTimer::timeout, this, &SystemStatsMonitor::updateSlowStats);
    m_slowTimer->start();
    
    // Enforcement Timer (5 seconds loop)
    m_enforcementTimer = new QTimer(this);
    m_enforcementTimer->setInterval(5000); 
    connect(m_enforcementTimer, &QTimer::timeout, this, &SystemStatsMonitor::enforceChargeLimit);
    m_enforcementTimer->start();

    // 3. GPU Process Init - async to avoid blocking
    m_gpuProcess = new QProcess(this);
    connect(m_gpuProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &SystemStatsMonitor::onGpuProcessFinished);
    
    // 4. Debounce Timer Init
    m_limitDebounceTimer = new QTimer(this);
    m_limitDebounceTimer->setSingleShot(true);
    m_limitDebounceTimer->setInterval(500); // Wait 500ms after last slide
    connect(m_limitDebounceTimer, &QTimer::timeout, this, &SystemStatsMonitor::applyPendingChargeLimit);




    // MTP Worker Thread (Background)
    m_mtpThread = new QThread(this);
    m_mtpWorker = new MtpWorker();
    m_mtpWorker->moveToThread(m_mtpThread);
    
    connect(m_mtpThread, &QThread::started, m_mtpWorker, &MtpWorker::start);
    connect(m_mtpWorker, &MtpWorker::devicesFound, this, &SystemStatsMonitor::onMtpDevicesFound);
    // Cleanup worker on thread finish
    connect(m_mtpThread, &QThread::finished, m_mtpWorker, &QObject::deleteLater);
    
    m_mtpThread->start();
    
    // Initial read
    readSystemInfo();
    
    // Restore Charge Limit (Double Persistence)
    // 1. Read what system thinks (Sysfs)
    readChargeLimit();
    
    // 2. Read what we saved last time (QSettings)
    // If system reset to 100% (or different), re-apply our saved limit
    QSettings settings("AsusTuf", "FanControl");
    int savedLimit = settings.value("ChargeLimit", -1).toInt();
    
    if (savedLimit >= 20 && savedLimit <= 100) {
        if (m_chargeLimit != savedLimit) {
            qDebug() << "Restoring saved charge limit:" << savedLimit;
            setChargeLimit(savedLimit);
        }
    }
    
    // Initial updates
    m_cachedVolumeCount = QStorageInfo::mountedVolumes().count();
    updateStats();
    updateSlowStats();  // Disk info on startup
}

SystemStatsMonitor::~SystemStatsMonitor()
{
    if (m_mtpThread) {
        m_mtpThread->quit();
        m_mtpThread->wait(1000);  // Max 1 second wait
    }
    if (m_gpuProcess) {
        if (m_gpuProcess->state() != QProcess::NotRunning) {
            m_gpuProcess->terminate();  // Graceful first
            if (!m_gpuProcess->waitForFinished(500)) {
                m_gpuProcess->kill();  // Force kill if graceful fails
                m_gpuProcess->waitForFinished(100);
            }
        }
    }
}

#include <sys/statvfs.h>

void SystemStatsMonitor::updateStats()
{
    // Fast stats only - lightweight sysfs reads
    readCpuFreq();
    readMemoryUsage();
    readCpuUsage();
    readGpuStats();  // Now async, won't block
    readBattery();
    // Fast Check for Disk Changes (Instant USB Detection)
    // QStorageInfo::mountedVolumes reads /proc/mounts (very fast).
    // If count changes, we trigger full disk scan immediately.
    auto currentVols = QStorageInfo::mountedVolumes();
    if (currentVols.count() != m_cachedVolumeCount) {
        m_cachedVolumeCount = currentVols.count();
        updateSlowStats(); // Trigger heavy scan immediately!
    }

    emit statsChanged();
}

// Slow stats - heavy I/O operations (disk, network)
void SystemStatsMonitor::updateSlowStats()
{
    readDiskUsage();
    readNetworkUsage();
    emit statsChanged();
}

void SystemStatsMonitor::readCpuFreq()
{
    QFile file("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        double khz = in.readLine().toDouble();
        m_cpuFreq = khz / 1000.0;
        file.close();
    }
}

void SystemStatsMonitor::readMemoryUsage()
{
    QFile file("/proc/meminfo");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = file.readAll();
        file.close();
        
        // Regex for MemTotal and MemAvailable
        // MemTotal:       16303032 kB
        QRegularExpression reTotal("MemTotal:\\s+(\\d+)");
        QRegularExpression reAvail("MemAvailable:\\s+(\\d+)");
        
        QRegularExpressionMatch matchTotal = reTotal.match(content);
        QRegularExpressionMatch matchAvail = reAvail.match(content);
        
        double total = 0;
        double available = 0;
        
        if (matchTotal.hasMatch()) {
            total = matchTotal.captured(1).toDouble();
        }
        
        if (matchAvail.hasMatch()) {
            available = matchAvail.captured(1).toDouble();
        }
        
        if (total > 0) {
            m_memoryUsage = ((total - available) / total) * 100.0;
        } else {
            m_memoryUsage = 0;
        }
    }
}

void SystemStatsMonitor::readCpuUsage()
{
    QFile file("/proc/stat");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        QString line = in.readLine();
        file.close();
        
        QStringList parts = line.split(QRegularExpression("\\s+"));
        if (parts.length() > 4) {
            long long user = parts[1].toLongLong();
            long long nice = parts[2].toLongLong();
            long long system = parts[3].toLongLong();
            long long idle = parts[4].toLongLong();
            long long iowait = (parts.length() > 5) ? parts[5].toLongLong() : 0;
            long long irq = (parts.length() > 6) ? parts[6].toLongLong() : 0;
            long long softirq = (parts.length() > 7) ? parts[7].toLongLong() : 0;
            long long total = user + nice + system + idle + iowait + irq + softirq;
            long long totalIdle = idle + iowait;
            
            if (m_prevTotal > 0) {
                long long totalDiff = total - m_prevTotal;
                long long idleDiff = totalIdle - m_prevIdle;
                if (totalDiff > 0) m_cpuUsage = ((double)(totalDiff - idleDiff) / totalDiff) * 100.0;
            }
            m_prevTotal = total;
            m_prevIdle = totalIdle;
        }
    }
}

void SystemStatsMonitor::readGpuStats()
{
    // Async GPU query - doesn't block UI thread
    if (m_gpuProcess->state() != QProcess::NotRunning) return;
    
    m_gpuProcess->start("nvidia-smi", QStringList() << "--query-gpu=clocks.gr,utilization.gpu" << "--format=csv,noheader,nounits");
    // Result handled in onGpuProcessFinished() - no blocking wait!
}

void SystemStatsMonitor::onGpuProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    Q_UNUSED(status);
    if (exitCode != 0) return;
    
    QString output = m_gpuProcess->readAllStandardOutput().trimmed();
    if (output.isEmpty()) return;
    
    QStringList parts = output.split(",");
    if (parts.length() >= 2) {
        m_gpuFreq = parts[0].trimmed().toDouble();
        m_gpuUsage = parts[1].trimmed().toDouble();
    } else if (parts.length() == 1) {
        m_gpuFreq = parts[0].trimmed().toDouble();
    }
    emit statsChanged();
}

// --- Disk Usage Logic ---
// --- Disk Usage Logic ---
// Revised: Use lsblk -P (Pairs) with PARTLABEL and Precise Math
void SystemStatsMonitor::readDiskUsage()
{
    QProcess lsblk;
    // Added PARTLABEL
    lsblk.start("lsblk", QStringList() << "-P" << "-b" << "-o" << "NAME,LABEL,PARTLABEL,MOUNTPOINT,FSTYPE,SIZE,TYPE,FSUSE%,FSAVAIL,PATH");
    
    if (!lsblk.waitForFinished(1500)) {
        return; 
    }
    
    QByteArray output = lsblk.readAllStandardOutput();
    QStringList lines = QString(output).split('\n', Qt::SkipEmptyParts);
    
    QVariantList newPartitions;
    double totalAll = 0;
    double usedAll = 0;
    
    for (const QString &line : lines) {
        QMap<QString, QString> props;
        QRegularExpression re("([A-Z%]+)=\"([^\"]*)\"");
        QRegularExpressionMatchIterator i = re.globalMatch(line);
        while (i.hasNext()) {
            QRegularExpressionMatch match = i.next();
            props[match.captured(1)] = match.captured(2);
        }
        
        QString fstype = props["FSTYPE"];
        
        // Filter logic
        if (props["TYPE"] != "part" && props["TYPE"] != "disk") continue; // Allow parts and whole disks (USB)
        if (fstype == "swap") continue; // Explicitly ignore SWAP
        
        QString mp = props["MOUNTPOINT"];
        if (mp == "[SWAP]") continue;   // Extra safety for SWAP
        if (mp.startsWith("/snap") || mp.startsWith("/run/snap") || mp.startsWith("/boot")) continue; 
        
        QString label = props["LABEL"];
        QString partLabel = props["PARTLABEL"];
        QString name = props["NAME"];
        
        double sizeBytes = props["SIZE"].toDouble();
        
        // Lower threshold to 100MB to support small USB drives
        if (sizeBytes < 100.0 * 1000.0 * 1000.0) continue;
        
        // Lower threshold to 100MB to support small USB drives
        if (sizeBytes < 100.0 * 1000.0 * 1000.0) continue;
        
        // Hide raw unmounted disks (reduces duplicates like "1000.2 GB Local Disk" vs its partitions)
        // We allow TYPE="disk" ONLY if it is mounted (for whole-disk USB drives)
        if (props["TYPE"] == "disk" && mp.isEmpty()) continue;

        double sizeGB = sizeBytes / (1000.0 * 1000.0 * 1000.0);
        bool isMounted = !mp.isEmpty();
        
        // ... (rest of logic) ...
        bool hasUsage = !props["FSAVAIL"].isEmpty(); // FSAVAIL is the source of truth for free space
        
        double freeBytes = 0;
        double usedBytes = 0;
        double usagePercent = 0;
        
        if (hasUsage) {
            freeBytes = props["FSAVAIL"].toDouble();
            usedBytes = sizeBytes - freeBytes;
            if (sizeBytes > 0) usagePercent = (usedBytes / sizeBytes) * 100.0;
        }
        
        double freeGB = freeBytes / (1000.0 * 1000.0 * 1000.0);
        double usedGB = usedBytes / (1000.0 * 1000.0 * 1000.0);
        double freePercent = (sizeGB > 0) ? (freeGB / sizeGB) * 100.0 : 0; // Usage of Free for %
        
        // Name Logic: Label > PartLabel (filtered) > Username(Root) > Pretty Mount > Basename
        QString displayName;
        
        // Filter generic Windows partition labels
        if (partLabel == "Basic data partition" || partLabel == "Microsoft reserved partition" || partLabel == "EFI system partition") {
            partLabel.clear(); 
        }

        if (!label.isEmpty()) displayName = label;
        else if (!partLabel.isEmpty()) displayName = partLabel;
        else if (isMounted) {
             if (mp == "/") {
                 // User Request: Use Username for Root if no label
                 // Must check SUDO_USER because we run as sudo
                 QString user = qgetenv("SUDO_USER");
                 if (user.isEmpty()) user = qgetenv("USER");
                 
                 if (user.isEmpty() || user == "root") {
                     user = tr("System");
                 } else {
                     user[0] = user[0].toUpper();
                 }
                 displayName = user;
             }
             else if (mp == "/home") displayName = tr("Home");
             else displayName = mp.section('/', -1);
             if (displayName.isEmpty()) displayName = tr("Volume");
        } else {
            displayName = tr("Local Disk"); 
        }
        
        QVariantMap p;
        p["name"] = displayName;
        p["device"] = props["PATH"];
        p["mount"] = mp;
        p["fsType"] = fstype;
        p["total"] = QString::number(sizeGB, 'f', 1);
        p["used"] = QString::number(usedGB, 'f', 1);
        p["free"] = QString::number(freeGB, 'f', 1);
        p["usage"] = usagePercent;
        p["freePercent"] = freePercent;
        p["isMounted"] = isMounted;
        p["hasUsage"] = hasUsage; 
        
        newPartitions.append(p);
        
        if (hasUsage) {
            totalAll += sizeGB;
            usedAll += usedGB;
        }
    }
    
    // Append cached MTP devices
    for (const QVariant &v : m_cachedMtpDevices) {
        QVariantMap p = v.toMap();
        newPartitions.append(p);
        
        // Add to totals
        totalAll += p["total"].toDouble();
        usedAll += p["used"].toDouble();
    }
    
    m_diskPartitions = newPartitions;
    
    m_diskTotal = totalAll;
    m_diskUsed = usedAll;
    
    if (totalAll > 0) {
        m_diskUsage = (usedAll / totalAll) * 100.0;
    } else {
        m_diskUsage = 0;
    }
}

void SystemStatsMonitor::onMtpDevicesFound(QVariantList devices)
{
    m_cachedMtpDevices = devices;
    // Trigger update immediately to show new devices
    updateStats();
}

void SystemStatsMonitor::readNetworkUsage()
{
    QFile file("/proc/net/dev");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        // Skip headers
        in.readLine();
        in.readLine();
        
        long long currentRx = 0;
        long long currentTx = 0;
        
        while (!in.atEnd()) {
            QString line = in.readLine();
            QStringList parts = line.trimmed().split(QRegularExpression("\\s+"));
            if (parts.length() > 9) {
                // Interface name ends with ':'
                if (!parts[0].startsWith("lo") && !parts[0].startsWith("vmnet")) {
                    currentRx += parts[1].toLongLong();
                    currentTx += parts[9].toLongLong();
                }
            }
        }
        file.close();
        
        if (m_prevRx > 0) {
            // Bytes per 0.5 sec -> KB/s
            // (diff * 2) / 1024
            m_netDown = (currentRx - m_prevRx) * 2.0 / 1024.0;
            m_netUp = (currentTx - m_prevTx) * 2.0 / 1024.0;
        }
        
        m_prevRx = currentRx;
        m_prevTx = currentTx;
    }
}

void SystemStatsMonitor::readSystemInfo() {
    // 1. Laptop Model
    QFile fModel("/sys/class/dmi/id/product_name");
    if (fModel.open(QIODevice::ReadOnly)) {
        m_laptopModel = fModel.readAll().trimmed();
        fModel.close();
    } else {
        m_laptopModel = "ASUS TUF Gaming";
    }

    // 2. OS Version
    QFile fOs("/etc/os-release");
    if (fOs.open(QIODevice::ReadOnly)) {
        QString content = fOs.readAll();
        QRegularExpression re("PRETTY_NAME=\"([^\"]+)\"");
        QRegularExpressionMatch match = re.match(content);
        if (match.hasMatch()) {
            m_osVersion = match.captured(1);
        } else {
            m_osVersion = "Linux";
        }
        fOs.close();
    }

    // 3. CPU Model
    QFile fCpu("/proc/cpuinfo");
    if (fCpu.open(QIODevice::ReadOnly)) {
        QString content = fCpu.readAll();
        QRegularExpression re("model name\\s+:\\s+(.+)"); // Find first match
        QRegularExpressionMatch match = re.match(content);
        if (match.hasMatch()) {
             m_cpuModel = match.captured(1).trimmed();
        }
        fCpu.close();
    }
    
    // 4. GPU Model (lspci)
    QProcess p;
    p.start("/usr/bin/lspci"); // Absolute path for safety
    if (p.waitForFinished(3000)) { // 3s timeout
        QString out = p.readAllStandardOutput();
        QStringList lines = out.split("\n");
        m_gpuModels.clear();
        for (const QString &line : lines) {
            if (line.contains("VGA") || line.contains("3D")) {
                // e.g. "01:00.0 VGA compatible controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)"
                int idx = line.indexOf(": ");
                if (idx != -1) {
                    QString model = line.mid(idx + 2);
                    // Simplify: Get text inside [] if present
                    QRegularExpression reBracket("\\[([^\\]]+)\\]");
                    QRegularExpressionMatch m = reBracket.match(model);
                    if (m.hasMatch()) {
                        m_gpuModels.append(m.captured(1));
                    } else {
                        // Fallback: Remove redundant "VGA compatible controller: " if present
                         if (model.contains("controller: ")) {
                             model = model.section("controller: ", 1);
                         }
                         m_gpuModels.append(model.trimmed());
                    }
                }
            }
        }
        if (m_gpuModels.isEmpty()) m_gpuModels.append(tr("Generic GPU"));

    } else {
        qDebug() << "lspci timed out or failed";
        m_gpuModels.append(tr("GPU Detection Failed"));
    }
}

void SystemStatsMonitor::readBattery() {
    QFile fCap("/sys/class/power_supply/BAT1/capacity");
    if (fCap.open(QIODevice::ReadOnly)) {
        m_batteryPercent = fCap.readAll().trimmed().toInt();
        fCap.close();
    }

    QFile fStatus("/sys/class/power_supply/BAT1/status");
    if (fStatus.open(QIODevice::ReadOnly)) {
        m_batteryState = fStatus.readAll().trimmed();
        m_isCharging = (m_batteryState == "Charging");
        fStatus.close();
    }
}

// --- Charge Limit Logic ---

int SystemStatsMonitor::readChargeLimit() {
    QFile file("/sys/class/power_supply/BAT1/charge_control_end_threshold");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        int val = file.readAll().trimmed().toInt();
        file.close();
        if (val > 0) m_chargeLimit = val;
    }
    return m_chargeLimit;
}

void SystemStatsMonitor::setChargeLimit(int limit) {
    if (limit < 60) limit = 60; 
    if (limit > 100) limit = 100;

    // Debounce Logic:
    // 1. Store the desired limit
    m_pendingChargeLimit = limit;
    
    // 2. Restart the timer (resets the 500ms countdown)
    m_limitDebounceTimer->start();
    
    // 3. Optimistic UI update?
    // User expects UI to react. We can set m_chargeLimit here OR wait.
    // Setting it here makes UI responsive.
    m_chargeLimit = limit;
    emit chargeLimitChanged();
}

void SystemStatsMonitor::applyPendingChargeLimit() {
    int limit = m_pendingChargeLimit;
    if (limit < 60 || limit > 100) return;

    // Path to battery threshold file
    QString batPath = "/sys/class/power_supply/BAT1/charge_control_end_threshold";
    if (!QFile::exists(batPath)) {
        batPath = "/sys/class/power_supply/BAT0/charge_control_end_threshold";
    }

    bool success = false;
    
    // 1. Try asusctl first
    QProcess asusctl;
    asusctl.start("asusctl", QStringList() << "-c" << QString::number(limit));
    if (asusctl.waitForFinished(1000) && asusctl.exitCode() == 0) {
        // VERIFY: Check if the file actually updated
        QFile checkFile(batPath);
        if (checkFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            int currentVal = checkFile.readAll().trimmed().toInt();
            checkFile.close();
            if (currentVal == limit) {
                success = true;
            }
        }
    }
    
    // 2. Fallback: Direct Sysfs Write (If asusctl failed OR verification failed)
    if (!success) {
        QFile file(batPath);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << limit;
            file.close();
            success = true; // Assume success if write didn't throw
        }
    }

    if (success) {
        // Persist to Robust System Service Config
        QFile conf("/etc/asus_battery_limit.conf");
        if (conf.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream confOut(&conf);
            confOut << limit;
            conf.close();
        }
        
        // Update QSettings
        QSettings settings("AsusTuf", "FanControl");
        settings.setValue("ChargeLimit", limit);
        
        // Persist to asusd config (Secondary Backup)
        updateAsusdChargeLimit(limit);
        
        // Force Immediate Enforcement
        enforceChargeLimit();
    }
}

void SystemStatsMonitor::updateAsusdChargeLimit(int limit) {
    // Patch /etc/asusd/asusd.ron
    QFile f("/etc/asusd/asusd.ron");
    if (!f.open(QIODevice::ReadWrite | QIODevice::Text)) return;
    
    QString content = f.readAll();
    
    // Pattern: charge_control_end_threshold: 90,
    // Regex handles flexible spacing
    QRegularExpression re("charge_control_end_threshold:\\s*\\d+,");
    QRegularExpressionMatch match = re.match(content);
    
    if (match.hasMatch()) {
        content.replace(match.capturedStart(), match.capturedLength(), "charge_control_end_threshold: " + QString::number(limit) + ",");
        f.seek(0);
        f.write(content.toUtf8());
        f.resize(f.pos());
    }
    f.close();
}

void SystemStatsMonitor::enforceChargeLimit() {
    // 1. Read actual current kernel limit
    QString batPath = "/sys/class/power_supply/BAT1/charge_control_end_threshold";
    if (!QFile::exists(batPath)) batPath = "/sys/class/power_supply/BAT0/charge_control_end_threshold";
    
    int currentKernelLimit = -1;
    QFile f(batPath);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        currentKernelLimit = f.readAll().trimmed().toInt();
        f.close();
    }
    
    // 2. Mismatch Logic
    // If the kernel value is DIFFERENT from our target, RE-APPLY.
    // Also, if we are ABOVE limit and still charging, try RE-APPLYING to force stop.
    bool needsEnforcement = (currentKernelLimit != m_chargeLimit);
    
    if (needsEnforcement) {
        // Force Write to Sysfs (Direct "Iron-Fist" Approach)
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&f);
            out << m_chargeLimit;
            f.close();
            // qDebug() << "Enforcement: Re-applied limit of" << m_chargeLimit << "was" << currentKernelLimit;
        }
    }
}

void SystemStatsMonitor::openFileManager(const QString &mountPoint, const QString &deviceNode)
{
    // Determine the actual user
    QString user = qgetenv("SUDO_USER");
    if (user.isEmpty()) user = qgetenv("USER");
    
    // CASE 1: Drive IS mounted (or MTP)
    if (!mountPoint.isEmpty()) {
        if (user == "root" || user.isEmpty()) { 
             // We are root, but no SUDO_USER? Just try opening as root.
             QUrl url;
             if (mountPoint.contains("://")) url = QUrl(mountPoint);
             else url = QUrl::fromLocalFile(mountPoint);
             QDesktopServices::openUrl(url);
             return;
        }
    }
    
    // CASE 2: Drive is NOT mounted. We must mount it.
    bool attemptingMount = mountPoint.isEmpty();
    if (attemptingMount && deviceNode.isEmpty()) return;

    // Common Env Setup for runuser
    QProcess idProc;
    idProc.start("id", QStringList() << "-u" << user);
    idProc.waitForFinished();
    QString uid = idProc.readAllStandardOutput().trimmed();
    if (uid.isEmpty()) return;

    // Build critical environment variables for GUI apps
    QStringList envVars;
    envVars << QString("DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%1/bus").arg(uid);
    envVars << QString("XDG_RUNTIME_DIR=/run/user/%1").arg(uid);
    
    // Try to preserve/guess Display vars
    QString display = qgetenv("DISPLAY");
    if (display.isEmpty()) display = ":0";
    envVars << QString("DISPLAY=%1").arg(display);
    
    QString wayland = qgetenv("WAYLAND_DISPLAY");
    if (!wayland.isEmpty()) envVars << QString("WAYLAND_DISPLAY=%1").arg(wayland);
    
    QString xauth = qgetenv("XAUTHORITY");
    if (xauth.isEmpty()) {
        // Fallback guess for common locations
        QString home = QString("/home/%1").arg(user);
        if (QFile::exists(home + "/.Xauthority")) xauth = home + "/.Xauthority";
        else if (QFile::exists(QString("/run/user/%1/gdm/Xauthority").arg(uid))) xauth = QString("/run/user/%1/gdm/Xauthority").arg(uid);
    }
    if (!xauth.isEmpty()) envVars << QString("XAUTHORITY=%1").arg(xauth);

    if (attemptingMount) {
        // Try to mount using gio (triggers GUI password prompt)
        
        QStringList args;
        args << "-u" << user << "--" << "env";
        args.append(envVars);
        args << "gio" << "mount" << "-d" << deviceNode;
             
        // Use startDetached to avoid "Destroyed while process is still running"
        QProcess::startDetached("runuser", args);
        return;
    }

    // CASE 3: Opening an existing mount
    QStringList args;
    args << "-u" << user << "--" << "env";
    args.append(envVars);
    args << "xdg-open" << mountPoint;

    QProcess::startDetached("runuser", args);
}
