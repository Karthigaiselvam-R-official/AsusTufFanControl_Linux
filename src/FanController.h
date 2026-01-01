#ifndef FANCONTROLLER_H
#define FANCONTROLLER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QProcess>
#include <QProcess>

class FanController : public QObject
{
    Q_OBJECT
    // Properties readable by QML UI
    Q_PROPERTY(int cpuFanRpm READ getCpuFanRpm NOTIFY statsUpdated)
    Q_PROPERTY(int gpuFanRpm READ getGpuFanRpm NOTIFY statsUpdated)
    Q_PROPERTY(int cpuTemp READ getCpuTemp NOTIFY statsUpdated)
    Q_PROPERTY(int gpuTemp READ getGpuTemp NOTIFY statsUpdated)
    Q_PROPERTY(QString statusMessage READ getStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool isManualModeActive READ isManualModeActive NOTIFY manualModeChanged)

public:
    explicit FanController(QObject *parent = nullptr);
    ~FanController();

    // Main Control Functions (Callable from QML)
    Q_INVOKABLE bool initializeController();
    Q_INVOKABLE void setFanSpeed(int percentage);
    Q_INVOKABLE void enableAutoMode();
    Q_INVOKABLE void testECAccess(); // For debugging
    
    // Getters for Properties
    Q_INVOKABLE int getCpuFanRpm();
    Q_INVOKABLE int getGpuFanRpm();
    Q_INVOKABLE int getCpuTemp();
    Q_INVOKABLE int getGpuTemp();
    
    Q_INVOKABLE QString getStatusMessage() const { return m_statusMessage; }
    Q_INVOKABLE bool isManualModeActive() const { return m_manualMode; }

signals:
    void statsUpdated();
    void statusMessageChanged();
    void manualModeChanged();

private:
    // --- State Variables ---
    bool m_manualMode;
    int m_currentFanSpeed;
    QString m_statusMessage;
    QTimer *m_enforcementTimer;

    // --- Control Method Flags ---
    bool m_useACPICalls;
    bool m_hasPWMControl;
    bool m_hasThermalPolicy;
    bool m_useDirectEC;

    // --- Paths ---
    QString m_tempPath;      // Path to CPU temp (coretemp)
    QString m_rpmPath;       // Path to fan RPM (asus-wmi)
    QString m_gpuTempPath;   // Path to GPU temp
    
    QString m_wmiBasePath;   // Base path for WMI thermal policy
    QString m_wmiHwmonPath;  // Path for WMI PWM control
    
    QString m_acpiMethod; // The specific ACPI method found for fan control
    QStringList m_acpiPaths; // List of detected valid ACPI methods

    // --- Private Helper Methods ---
    void findPaths();
    bool findWMIPaths();
    void detectACPIMethods();
    
    // ACPI Interaction
    QString callACPI(const QString &command);
    bool setFanSpeedACPI(int percentage);
    
    // File I/O Helpers
    int readIntFromFile(QString path);
    bool writeToSysfs(const QString &path, int value);
    bool writeECRegister(int reg, int value);
    
    // Internal Logic
    // Internal Logic
    void setStatusMessage(const QString &msg);
    void enforceManualMode(); // Called by timer to fight BIOS auto-control
    
    // Cached Stats (Async Updates)
    int m_cachedCpuFanRpm = 0;
    int m_cachedGpuFanRpm = 0;
    int m_cachedCpuTemp = 0;
    int m_cachedGpuTemp = 0;
    
    QTimer *m_statsTimer;
    QProcess *m_gpuProcess;

private slots:
    void updateStats();
    void onGpuProcessFinished(int exitCode, QProcess::ExitStatus status);
};

#endif // FANCONTROLLER_H