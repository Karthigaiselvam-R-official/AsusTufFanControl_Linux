#ifndef FANCURVECONTROLLER_H
#define FANCURVECONTROLLER_H

#include <QObject>
#include <QTimer>
#include <QFile>
#include <QTextStream>
#include <QSettings>
#include <QDebug>

class FanCurveController : public QObject
{
    Q_OBJECT
    
    // Auto curve enabled state
    Q_PROPERTY(bool autoCurveEnabled READ autoCurveEnabled WRITE setAutoCurveEnabled NOTIFY autoCurveEnabledChanged)
    
    // Temperature thresholds (in Celsius)
    Q_PROPERTY(int silentThreshold READ silentThreshold WRITE setSilentThreshold NOTIFY thresholdsChanged)
    Q_PROPERTY(int balancedThreshold READ balancedThreshold WRITE setBalancedThreshold NOTIFY thresholdsChanged)
    
    // Current state
    Q_PROPERTY(QString currentAutoMode READ currentAutoMode NOTIFY currentAutoModeChanged)
    Q_PROPERTY(int currentCpuTemp READ currentCpuTemp NOTIFY currentCpuTempChanged)

public:
    explicit FanCurveController(QObject *parent = nullptr);
    ~FanCurveController();

    // Getters
    bool autoCurveEnabled() const { return m_autoCurveEnabled; }
    int silentThreshold() const { return m_silentThreshold; }
    int balancedThreshold() const { return m_balancedThreshold; }
    QString currentAutoMode() const { return m_currentAutoMode; }
    int currentCpuTemp() const { return m_currentCpuTemp; }

    // Setters
    void setAutoCurveEnabled(bool enabled);
    void setSilentThreshold(int temp);
    void setBalancedThreshold(int temp);

    // Presets
    Q_INVOKABLE void applyPreset(const QString &presetName);
    Q_INVOKABLE QStringList getPresetNames() const;

signals:
    void autoCurveEnabledChanged();
    void thresholdsChanged();
    void currentAutoModeChanged();
    void currentCpuTempChanged();

private slots:
    void evaluateTemperature();

private:
    // State
    bool m_autoCurveEnabled = false;
    int m_silentThreshold = 50;    // Below this → Silent
    int m_balancedThreshold = 70;  // Below this → Balanced, above → Turbo
    QString m_currentAutoMode = "Manual";
    int m_currentCpuTemp = 0;
    int m_lastPolicy = -1;         // Track last applied policy to avoid redundant writes
    
    // Timer for temperature polling
    QTimer *m_evalTimer;
    
    // Paths
    QString m_thermalPolicyPath;
    QString m_cpuTempPath;
    
    // Helper methods
    int readCpuTemp();
    void setThermalPolicy(int policy);  // 0=Balanced, 1=Turbo, 2=Silent
    QString policyToString(int policy);
    void findPaths();
    void loadSettings();
    void saveSettings();
};

#endif // FANCURVECONTROLLER_H
