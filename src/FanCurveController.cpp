#include "FanCurveController.h"
#include <QDir>

FanCurveController::FanCurveController(QObject *parent)
    : QObject(parent)
{
    // Find system paths
    findPaths();
    
    // Load saved settings
    loadSettings();
    
    // Create evaluation timer (1 second interval)
    m_evalTimer = new QTimer(this);
    m_evalTimer->setInterval(1000);
    connect(m_evalTimer, &QTimer::timeout, this, &FanCurveController::evaluateTemperature);
    
    // Start timer if auto curve was previously enabled
    if (m_autoCurveEnabled) {
        m_evalTimer->start();
    }
}

FanCurveController::~FanCurveController()
{
    saveSettings();
    if (m_evalTimer) {
        m_evalTimer->stop();
    }
}

void FanCurveController::findPaths()
{
    // Find thermal policy path
    QString basePath = "/sys/devices/platform/asus-nb-wmi";
    if (QFile::exists(basePath + "/throttle_thermal_policy")) {
        m_thermalPolicyPath = basePath + "/throttle_thermal_policy";
    }
    
    // Find CPU temperature path (check multiple possible locations)
    QStringList tempPaths = {
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
        "/sys/class/hwmon/hwmon1/temp1_input",
        "/sys/class/hwmon/hwmon2/temp1_input"
    };
    
    for (const QString &path : tempPaths) {
        if (QFile::exists(path)) {
            m_cpuTempPath = path;
            break;
        }
    }
}

void FanCurveController::setAutoCurveEnabled(bool enabled)
{
    if (m_autoCurveEnabled == enabled) return;
    
    m_autoCurveEnabled = enabled;
    
    if (enabled) {
        m_lastPolicy = -1;  // Reset to force first evaluation
        m_evalTimer->start();
        evaluateTemperature();  // Evaluate immediately
        qDebug() << "Auto Fan Curve ENABLED";
    } else {
        m_evalTimer->stop();
        m_currentAutoMode = "Manual";
        emit currentAutoModeChanged();
        qDebug() << "Auto Fan Curve DISABLED - Manual mode";
    }
    
    saveSettings();
    emit autoCurveEnabledChanged();
}

void FanCurveController::setSilentThreshold(int temp)
{
    if (temp < 30) temp = 30;
    if (temp > 80) temp = 80;
    if (temp >= m_balancedThreshold) temp = m_balancedThreshold - 5;
    
    if (m_silentThreshold == temp) return;
    
    m_silentThreshold = temp;
    saveSettings();
    emit thresholdsChanged();
    
    // Re-evaluate if auto curve is enabled
    if (m_autoCurveEnabled) {
        evaluateTemperature();
    }
}

void FanCurveController::setBalancedThreshold(int temp)
{
    if (temp < 40) temp = 40;
    if (temp > 95) temp = 95;
    if (temp <= m_silentThreshold) temp = m_silentThreshold + 5;
    
    if (m_balancedThreshold == temp) return;
    
    m_balancedThreshold = temp;
    saveSettings();
    emit thresholdsChanged();
    
    // Re-evaluate if auto curve is enabled
    if (m_autoCurveEnabled) {
        evaluateTemperature();
    }
}

int FanCurveController::readCpuTemp()
{
    if (m_cpuTempPath.isEmpty()) return 50;  // Default fallback
    
    QFile file(m_cpuTempPath);
    if (!file.open(QIODevice::ReadOnly)) return 50;
    
    QString content = file.readAll().trimmed();
    file.close();
    
    int temp = content.toInt();
    
    // Most temp files report in millidegrees (e.g., 65000 = 65°C)
    if (temp > 1000) {
        temp = temp / 1000;
    }
    
    return temp;
}

void FanCurveController::setThermalPolicy(int policy)
{
    if (m_thermalPolicyPath.isEmpty()) {
        qDebug() << "Thermal policy path not found!";
        return;
    }
    
    // Avoid redundant writes
    if (policy == m_lastPolicy) return;
    
    QFile file(m_thermalPolicyPath);
    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open thermal policy for writing:" << m_thermalPolicyPath;
        return;
    }
    
    file.write(QString::number(policy).toUtf8());
    file.close();
    
    m_lastPolicy = policy;
    m_currentAutoMode = policyToString(policy);
    emit currentAutoModeChanged();
    
    // Debug output removed for cleaner terminal
}

QString FanCurveController::policyToString(int policy)
{
    switch (policy) {
        case 0: return "Balanced";
        case 1: return "Turbo";
        case 2: return "Silent";
        default: return "Unknown";
    }
}

void FanCurveController::evaluateTemperature()
{
    if (!m_autoCurveEnabled) return;
    
    m_currentCpuTemp = readCpuTemp();
    emit currentCpuTempChanged();
    
    int targetPolicy;
    
    if (m_currentCpuTemp <= m_silentThreshold) {
        targetPolicy = 2;  // Silent
    } else if (m_currentCpuTemp <= m_balancedThreshold) {
        targetPolicy = 0;  // Balanced
    } else {
        targetPolicy = 1;  // Turbo
    }
    
    setThermalPolicy(targetPolicy);
}

void FanCurveController::applyPreset(const QString &presetName)
{
    if (presetName == "Gaming") {
        m_silentThreshold = 40;
        m_balancedThreshold = 60;
    } else if (presetName == "Quiet") {
        m_silentThreshold = 65;
        m_balancedThreshold = 80;
    } else if (presetName == "Balanced") {
        m_silentThreshold = 50;
        m_balancedThreshold = 70;
    } else if (presetName == "Performance") {
        m_silentThreshold = 35;
        m_balancedThreshold = 50;
    }
    
    saveSettings();
    emit thresholdsChanged();
    
    if (m_autoCurveEnabled) {
        evaluateTemperature();
    }
    
    // Debug output removed for cleaner terminal
}

QStringList FanCurveController::getPresetNames() const
{
    return QStringList() << "Gaming" << "Quiet" << "Balanced" << "Performance";
}

void FanCurveController::loadSettings()
{
    QSettings settings("AsusTuf", "FanControl");
    settings.beginGroup("FanCurve");
    
    m_autoCurveEnabled = settings.value("autoCurveEnabled", false).toBool();
    m_silentThreshold = settings.value("silentThreshold", 50).toInt();
    m_balancedThreshold = settings.value("balancedThreshold", 70).toInt();
    
    settings.endGroup();
}

void FanCurveController::saveSettings()
{
    QSettings settings("AsusTuf", "FanControl");
    settings.beginGroup("FanCurve");
    
    settings.setValue("autoCurveEnabled", m_autoCurveEnabled);
    settings.setValue("silentThreshold", m_silentThreshold);
    settings.setValue("balancedThreshold", m_balancedThreshold);
    
    settings.endGroup();
    settings.sync();
}
