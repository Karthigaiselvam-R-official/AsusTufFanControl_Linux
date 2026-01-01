#include "AuraController.h"
#include <QSettings>
#include <QRegularExpression>

AuraController::AuraController(QObject *parent) : QObject(parent), m_initThread(nullptr) {
    m_isAvailable = false;
    m_rogauraPath = "";
    
    // Setup Software Strobe Timer
    m_strobeTimer = new QTimer(this);
    connect(m_strobeTimer, &QTimer::timeout, this, &AuraController::onStrobeTimeout);
    m_strobeToggle = false;

    // Fix: Auto-Initialize on Startup (Async)
    // We delay slightly to allow the UI to load first
    QTimer::singleShot(100, this, &AuraController::initializeController);
}

// Destructor to clean up thread
AuraController::~AuraController() {
    if (m_initThread) {
        if (m_initThread->isRunning()) {
            m_initThread->quit();
            m_initThread->wait(500);
        }
        delete m_initThread;
    }
}

bool AuraController::runCommandBlocking(const QStringList &args) {
    if (m_rogauraPath.isEmpty()) return false;
    
    QProcess process;
    process.start(m_rogauraPath, args);
    if (!process.waitForStarted()) return false;
    process.waitForFinished();
    return (process.exitCode() == 0);
}

void AuraController::runCommand(const QStringList &args) {
    if (!m_isAvailable || m_rogauraPath.isEmpty()) return;
    
    // Non-blocking fire-and-forget for UI responsiveness
    QProcess::startDetached(m_rogauraPath, args);
}

void AuraController::initializeController() {
    // Prevent double-initialization
    if (m_initThread && m_initThread->isRunning()) return;

    qDebug() << "AuraController: Starting Async Initialization...";
    
    // Using QThread::create (Qt 5.10+) to run the heavy logic in background
    // This prevents the "Startup Freeze" issue.
    m_initThread = QThread::create([this]() {
        this->initializeControllerImpl();
    });
    
    // Safety Fix: Do NOT use deleteLater here.
    // We manage m_initThread in the destructor. 
    // Using deleteLater causes a double-free (Segfault) on application exit
    // because the destructor tries to delete a pointer that might already be freed.
    
    m_initThread->start();
}

void AuraController::initializeControllerImpl() {
    // 1. Kill conflicting ASUS services 
    // This mimics the "exclusive control" requirement
    QProcess::execute("systemctl", QStringList() << "stop" << "asusd");
    QProcess::execute("pkill", QStringList() << "-f" << "rog-control-center");
    QProcess::execute("killall", QStringList() << "asusd");

    bool avail = false;
    bool sysfs = false;
    bool asusctl = false;
    QString asusCtlPath = "";
    QString rogauraPath = "";

    // 2. Try Sysfs (Native)
    QString testPath = "/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode";
    if (QFile::exists(testPath)) {
        sysfs = true;
        avail = true;
        // Wake up sequence
        QFile f("/sys/class/leds/asus::kbd_backlight/kbd_rgb_state");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&f);
            out << "1 1 1 0 1" << Qt::endl;
            f.close();
        }
    } 
    // 3. Try asusctl
    else if (QFile::exists("/usr/bin/asusctl") || QFile::exists("/usr/local/bin/asusctl")) {
        asusCtlPath = QFile::exists("/usr/bin/asusctl") ? "/usr/bin/asusctl" : "/usr/local/bin/asusctl";
        asusctl = true;
        avail = true;
    }
    // 4. Try Rogauracore
    else {
        if (QFile::exists("/usr/local/bin/rogauracore")) rogauraPath = "/usr/local/bin/rogauracore";
        else if (QFile::exists("/usr/bin/rogauracore")) rogauraPath = "/usr/bin/rogauracore";
        
        if (!rogauraPath.isEmpty()) {
            // Initializing rogauracore is slow (USB/HID interaction), hence why we are threaded!
             QProcess process;
             process.start(rogauraPath, QStringList() << "initialize_keyboard");
             if (process.waitForStarted() && process.waitForFinished()) {
                 if (process.exitCode() == 0) avail = true;
             }
             if (!avail) avail = true; // Fallback: Assume available if binary exists? matching old logic
        }
    }

    // UPDATE STATE ON MAIN THREAD
    // We use QMetaObject::invokeMethod over a queued connection to safely update member variables
    QMetaObject::invokeMethod(this, [=]() {
        // We capture values by copy ([=]) so we get the results from the thread
        this->m_useSysfs = sysfs;
        this->m_useAsusCtl = asusctl;
        this->m_asusCtlPath = asusCtlPath;
        this->m_rogauraPath = rogauraPath;
        this->m_isAvailable = avail;
        
        qDebug() << "AuraController: Init Complete. Available:" << avail << " Sysfs:" << sysfs << " AsusCtl:" << asusctl;
        emit this->isAvailableChanged();
        
        // Auto-restore last state if available
        if (avail) {
            QString lastM = this->getLastMode();
            QString lastC = this->getLastColor();
            // Trigger a UI update implicitly or we can just apply it:
            // But 'applyAura' is in QML.
            // However, we can use setStatic etc if we knew what to call.
            // QML 'initTimer' also tries to load state.
            // If QML loads faster than this thread, QML will see isAvailable=false.
            // When we emit isAvailableChanged, QML should react?
            // ui/pages/AuraPage.qml doesn't react to isAvailableChanged automatically to re-apply.
            // But that's fine, the user can click. Or we can update QML to auto-apply when available.
        }
    });
}

// Restore Services: Writes to /etc/asusd/aura_tuf.ron directly to bypass asusctl version issues
void AuraController::restoreServices(const QString &mode, const QString &color) {
    m_strobeTimer->stop(); 
    
    qDebug() << "AuraController: Patching asusd config and restarting service...";
    
    // 1. Reset Hardware to Known State (Static) to prevent asusd confusion
    // This removes our 'Mode 10' or 'Mode 4' overrides.
    writeSysfs("/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode", "0");
    
    // 2. Update Config File Directly (The "Deep Research" Fix)
    updateAsusdConfig(mode, color);
    
    // 3. Start Services Detached (Fixes "Lag on Close")
    // We restart the system daemon only - user service will auto-sync
    QProcess::startDetached("systemctl", QStringList() << "start" << "asusd");
    
    // Note: User service (asusd-user) should auto-detect changes via dbus
    // Removed manual restart as it caused crashes with signal issues
}

void AuraController::updateAsusdConfig(const QString &mode, const QString &color) {
    QFile f("/etc/asusd/aura_tuf.ron");
    if (!f.open(QIODevice::ReadWrite | QIODevice::Text)) {
        qDebug() << "Failed to open /etc/asusd/aura_tuf.ron";
        return;
    }
    
    QString content = f.readAll();
    
    // 1. Map Mode
    QString targetMode = "Static";
    if (mode == "Breathing") targetMode = "Breathe";
    if (mode == "Rainbow") targetMode = "RainbowCycle";
    if (mode == "Strobing") targetMode = "Pulse";
    
    // 2. Replace current_mode
    // Pattern: current_mode: Something,
    // Note: The file uses 'current_mode: Static,' formatting
    QRegularExpression reMode("current_mode: \\w+,");
    content.replace(reMode, "current_mode: " + targetMode + ",");
    
    // 3. Replace Color for the Target Mode
    // Find the block "TargetMode: ("
    int blkIdx = content.indexOf(targetMode + ": (");
    if (blkIdx != -1) {
        // Find colour1 inside this block
        int c1Idx = content.indexOf("colour1: (", blkIdx);
        if (c1Idx != -1) {
             QString c = formatColor(color); 
             bool ok;
             int r = c.mid(0, 2).toInt(&ok, 16);
             int g = c.mid(2, 2).toInt(&ok, 16);
             int b = c.mid(4, 2).toInt(&ok, 16);
             
             // Replace r: \d+,
             QRegularExpression reR("r: \\d+,");
             QRegularExpressionMatch matchR = reR.match(content, c1Idx);
             if (matchR.hasMatch()) {
                 content.replace(matchR.capturedStart(), matchR.capturedLength(), "r: " + QString::number(r) + ",");
             }

             // Re-match G (offsets might have shifted, but G is after R so c1Idx is safe reference? 
             // Wait, if R replacement changed length, logic might break.
             // Better: Find G relative to R? Or just re-match from c1Idx?
             // Since we modify 'content', indices shift!
             // Safe way: Replace one by one, updating content. But c1Idx might be invalid?
             // Actually, if we use separate searches it's safer.
             // But G match from original c1Idx might find a "g" BEFORE the modified R if we are not careful? No, G is after R.
             // Safer: Calculate offsets relative to current content state.
             
             // Simplest Safe Logic:
             // 1. Find block again or use offsets carefully.
             // Since G is usually next line, shift is minimal.
             
             // Let's just create matches first? No, replacing invalidates matches.
             // Let's find G starting from NEW c1Idx? No c1Idx also shifts!
             
             // Robust way:
             // Replace R.
             // Find G starting from (matchR.capturedStart() + newLength).
             
             // Updated Logic:
             int currentSearchPos = c1Idx;
             
             QRegularExpressionMatch mR = reR.match(content, currentSearchPos);
             if (mR.hasMatch()) {
                 QString repl = "r: " + QString::number(r) + ",";
                 content.replace(mR.capturedStart(), mR.capturedLength(), repl);
                 currentSearchPos = mR.capturedStart() + repl.length();
             }
             
             QRegularExpression reG("g: \\d+,");
             QRegularExpressionMatch mG = reG.match(content, currentSearchPos);
             if (mG.hasMatch()) {
                 QString repl = "g: " + QString::number(g) + ",";
                 content.replace(mG.capturedStart(), mG.capturedLength(), repl);
                 currentSearchPos = mG.capturedStart() + repl.length();
             }
             
             QRegularExpression reB("b: \\d+,");
             QRegularExpressionMatch mB = reB.match(content, currentSearchPos);
             if (mB.hasMatch()) {
                 QString repl = "b: " + QString::number(b) + ",";
                 content.replace(mB.capturedStart(), mB.capturedLength(), repl);
             }
        }
    }
    
    f.seek(0);
    f.write(content.toUtf8());
    f.resize(f.pos());
    f.close();
}


int AuraController::getSystemBrightness() {
    // Try to read generic LED brightness
    QFile f("/sys/class/leds/asus::kbd_backlight/brightness");
    if (f.open(QIODevice::ReadOnly)) {
        QByteArray val = f.readAll().trimmed();
        f.close();
        
        int b = val.toInt();
        // Map 0-3 (or 0-255? Asus usually 0-3)
        // Check max brightness to be sure
        QFile fmax("/sys/class/leds/asus::kbd_backlight/max_brightness");
        if (fmax.open(QIODevice::ReadOnly)) {
            int max = fmax.readAll().trimmed().toInt();
            fmax.close();
            if (max > 3) {
                // Scale to 0-3
                return (b * 3) / max;
            }
        }
        return b;
    }
    return -1; // Unknown
}

QString AuraController::formatColor(const QString &hex) {
    QString c = hex;
    if (c.startsWith("#")) c.remove(0, 1);
    
    // Security Fix: Validate that string contains only Hex characters
    // This prevents argument injection if 'hex' contained shell characters
    static const QRegularExpression hexRegex("^[0-9a-fA-F]{0,6}$");
    if (!hexRegex.match(c).hasMatch()) {
        qWarning() << "Security Warning: Invalid color format received:" << hex << "- Defaulting to red";
        return "ff0000";
    }

    while (c.length() < 6) c.prepend("0");
    return c;
}

void AuraController::setStatic(const QString &colorHex) {
    m_strobeTimer->stop(); // Stop any active strobe
    if (m_useAsusCtl) {
        QProcess::startDetached(m_asusCtlPath, QStringList() << "aura" << "static" << "-c" << formatColor(colorHex));
    } else if (m_useSysfs) {
        setSysfsColor(0, colorHex, 0); // Mode 0 = Static
    } else {
        runCommand(QStringList() << "single_static" << formatColor(colorHex));
    }
}

void AuraController::setBreathing(const QString &colorHex, int speed) {
    m_strobeTimer->stop(); // Stop any active strobe
    if (m_useAsusCtl) {
        QString s = (speed <= 1) ? "low" : (speed == 2 ? "med" : "high");
        QProcess::startDetached(m_asusCtlPath, QStringList() << "aura" << "breathe" << "-c" << formatColor(colorHex) << "-s" << s);
    } else if (m_useSysfs) {
        // Map 1-3 to 0-2 (0=Low, 1=Med, 2=High)
        int s = speed - 1;
        if (s < 0) s = 0;
        if (s > 2) s = 2;
        setSysfsColor(1, colorHex, s); // Mode 1 = Breathing
    } else {
        runCommand(QStringList() << "single_breathing" << formatColor(colorHex) << "000000" << QString::number(speed));
    }
}

void AuraController::setRainbow(int speed) {
    m_strobeTimer->stop(); // Stop any active strobe
    if (m_useAsusCtl) {
        QString s = (speed <= 1) ? "low" : (speed == 2 ? "med" : "high");
        QProcess::startDetached(m_asusCtlPath, QStringList() << "aura" << "rainbow-cycle" << "-s" << s);
    } else if (m_useSysfs) {
        int s = speed - 1;
        if (s < 0) s = 0;
        if (s > 2) s = 2;
        setSysfsColor(2, "FFFFFF", s); // Mode 2 = Cycle
    } else {
        runCommand(QStringList() << "rainbow_cycle" << QString::number(speed));
    }
}

void AuraController::setPulsing(const QString &colorHex, int speed) {
    m_strobeTimer->stop(); // Reset
    
    if (m_useAsusCtl) {
        QString s = (speed <= 1) ? "low" : (speed == 2 ? "med" : "high");
        QProcess::startDetached(m_asusCtlPath, QStringList() << "aura" << "pulse" << "-c" << formatColor(colorHex) << "-s" << s);
    } else if (m_useSysfs) {
        // Hardware modes (3, 4, 10) are unreliable for Speed/Effect on some devices.
        // Using Software Strobing (Toggle Static Mode) used to guarantee Effect & Speed Control.
        m_strobeColor = colorHex;
        
        // Map Speed 1..3 to Interval (ms)
        // 1 = Slow (1000ms), 2 = Med (500ms), 3 = Fast (200ms)
        int interval = 1000;
        if (speed == 2) interval = 500;
        else if (speed >= 3) interval = 200;
        
        m_strobeToggle = true; // Start On
        setSysfsColor(0, m_strobeColor, 0); // Immediate
        m_strobeTimer->start(interval);
        
    } else {
        runCommand(QStringList() << "single_breathing" << formatColor(colorHex) << "000000" << "3");
    }
}

void AuraController::setBrightness(int level) {
    if (m_useAsusCtl) {
        // -k off, low, med, high
        QString l = (level <= 0) ? "off" : (level == 1 ? "low" : (level == 2 ? "med" : "high"));
        QProcess::startDetached(m_asusCtlPath, QStringList() << "-k" << l);
    } else if (m_useSysfs) {
        // Levels 0-3
        int lvl = level;
        if (lvl > 3) lvl = 3; 
        writeSysfs("/sys/class/leds/asus::kbd_backlight/brightness", QString::number(lvl));
    } else {
        runCommand(QStringList() << "brightness" << QString::number(level));
    }
}

// Helpers
void AuraController::writeSysfs(const QString &path, const QString &val) {
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&f);
        out << val << Qt::endl; // Mandatory newline for sysfs
        f.close();
    } else {
        qDebug() << "AuraController: Failed to write to" << path;
    }
}

void AuraController::setSysfsColor(int mode, const QString &hex, int speed) {
    // 1. Parse Color
    QString c = formatColor(hex); 
    bool ok;
    int r = c.mid(0, 2).toInt(&ok, 16);
    int g = c.mid(2, 2).toInt(&ok, 16);
    int b = c.mid(4, 2).toInt(&ok, 16);

    // 2. Set Mode & Color (Single Write to kbd_rgb_mode)
    // Hardware expects Standard RGB order.
    // Format: 1 <Mode> <Red> <Green> <Blue> <Speed>
    QString modeVal = QString("1 %1 %2 %3 %4 %5")
                        .arg(mode)
                        .arg(r).arg(g).arg(b)
                        .arg(speed);
    
    qDebug() << "AuraController: Writing Sysfs Mode (RGB):" << modeVal;
    
    // Write to kbd_rgb_mode (NOT state) for immediate effect
    writeSysfs("/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode", modeVal);
}

void AuraController::saveState(const QString &mode, const QString &color) {
    QSettings settings("AsusTuf", "FanControl");
    settings.setValue("auraMode", mode);
    settings.setValue("auraColor", color);
}

QString AuraController::getLastMode() {
    QSettings settings("AsusTuf", "FanControl");
    return settings.value("auraMode", "Static").toString();
}

QString AuraController::getLastColor() {
    QSettings settings("AsusTuf", "FanControl");
    return settings.value("auraColor", "FF0000").toString();
}

void AuraController::onStrobeTimeout() {
    m_strobeToggle = !m_strobeToggle;
    if (m_strobeToggle) {
        setSysfsColor(0, m_strobeColor, 0); // Static Color
    } else {
        setSysfsColor(0, "000000", 0); // Static Black (Off)
    }
}
