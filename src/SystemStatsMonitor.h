#ifndef SYSTEMSTATSMONITOR_H
#define SYSTEMSTATSMONITOR_H

#include <QObject>
#include <QTimer>
#include <QFile>
#include <QSettings>
#include <QTextStream>
#include <QDebug>
#include <QProcess>
#include <QRegularExpression>
#include <QStorageInfo>
#include <QVariantList>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QThread>
#include "MtpWorker.h"

class SystemStatsMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double cpuFreq READ cpuFreq NOTIFY statsChanged)
    Q_PROPERTY(double memoryUsage READ memoryUsage NOTIFY statsChanged)
    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY statsChanged)
    Q_PROPERTY(double gpuFreq READ gpuFreq NOTIFY statsChanged)
    Q_PROPERTY(double gpuUsage READ gpuUsage NOTIFY statsChanged)
    Q_PROPERTY(double diskUsage READ diskUsage NOTIFY statsChanged)
    Q_PROPERTY(double netDown READ netDown NOTIFY statsChanged)
    Q_PROPERTY(double netUp READ netUp NOTIFY statsChanged)
    Q_PROPERTY(QString diskText READ diskText NOTIFY statsChanged)
    Q_PROPERTY(QVariantList diskPartitions READ diskPartitions NOTIFY statsChanged)

    // System Info
    Q_PROPERTY(QString cpuModel READ cpuModel CONSTANT)
    Q_PROPERTY(QStringList gpuModels READ gpuModels NOTIFY statsChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY statsChanged)
    Q_PROPERTY(bool isCharging READ isCharging NOTIFY statsChanged)
    Q_PROPERTY(QString batteryState READ batteryState NOTIFY statsChanged)
    Q_PROPERTY(QString osVersion READ osVersion CONSTANT)
    Q_PROPERTY(QString laptopModel READ laptopModel CONSTANT)
    Q_PROPERTY(int chargeLimit READ chargeLimit WRITE setChargeLimit NOTIFY chargeLimitChanged)

public:
    explicit SystemStatsMonitor(QObject *parent = nullptr);
    ~SystemStatsMonitor();
    
    double cpuFreq() const { return m_cpuFreq; }
    double memoryUsage() const { return m_memoryUsage; }
    double cpuUsage() const { return m_cpuUsage; }
    double gpuFreq() const { return m_gpuFreq; }
    double gpuUsage() const { return m_gpuUsage; }
    double diskUsage() const { return m_diskUsage; }
    double netDown() const { return m_netDown; }
    double netUp() const { return m_netUp; }
    QString diskText() const { return QString("%1/%2 GB").arg(m_diskUsed, 0, 'f', 0).arg(m_diskTotal, 0, 'f', 0); }
    QVariantList diskPartitions() const { return m_diskPartitions; }

    // System Info Getters
    QString cpuModel() const { return m_cpuModel; }
    QStringList gpuModels() const { return m_gpuModels; }
    int batteryPercent() const { return m_batteryPercent; }
    bool isCharging() const { return m_isCharging; }
    QString batteryState() const { return m_batteryState; }
    QString osVersion() const { return m_osVersion; }
    QString laptopModel() const { return m_laptopModel; }
    int chargeLimit() const { return m_chargeLimit; }

public slots:
    void updateStats();
    void setChargeLimit(int limit);
    void openFileManager(const QString &mountPoint, const QString &deviceNode = QString());
    void onMtpDevicesFound(QVariantList devices);

signals:
    void statsChanged();
    void chargeLimitChanged();

private:
    double m_cpuFreq = 0;
    double m_memoryUsage = 0;
    double m_cpuUsage = 0;
    double m_gpuFreq = 0;
    double m_gpuUsage = 0;
    double m_diskUsage = 0;
    double m_diskUsed = 0;
    double m_diskTotal = 0;
    double m_netDown = 0;
    double m_netUp = 0;
    QVariantList m_diskPartitions;

    // System Info Members
    QString m_cpuModel;
    QStringList m_gpuModels;
    int m_batteryPercent = 0;
    bool m_isCharging = false;
    QString m_batteryState;
    QString m_osVersion;
    QString m_laptopModel;
    int m_chargeLimit = 100;

    void updateAsusdChargeLimit(int limit);
    int readChargeLimit();

    void readSystemInfo();
    void readBattery();
    
    QTimer *m_timer;
    
    long long m_prevIdle = 0;
    long long m_prevTotal = 0;
    long long m_prevRx = 0;
    long long m_prevTx = 0;

    void readCpuFreq();
    void readMemoryUsage();
    void readCpuUsage();
    void readGpuStats();
    void readDiskUsage();
    
    QThread *m_mtpThread;
    MtpWorker *m_mtpWorker;
    QVariantList m_cachedMtpDevices;

    void readNetworkUsage();

    QTimer *m_enforcementTimer;
    void enforceChargeLimit();

    // Fix: Persist processes to avoid "Destroyed while running" warnings
    QProcess *m_gpuProcess;
    
    // Fix: Debounce battery limit to prevent crashes during sliding
    QTimer *m_limitDebounceTimer;
    int m_pendingChargeLimit = -1;
    
private slots:
    void applyPendingChargeLimit();
};

#endif // SYSTEMSTATSMONITOR_H
