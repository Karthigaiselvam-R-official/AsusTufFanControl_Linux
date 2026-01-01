#ifndef AURACONTROLLER_H
#define AURACONTROLLER_H

#include <QObject>
#include <QProcess>
#include <QFile>
#include <QDebug>
#include <QTimer>
#include <QThread>
#include <QMutex>

class AuraController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isAvailable READ isAvailable NOTIFY isAvailableChanged)

public:
    explicit AuraController(QObject *parent = nullptr);
    ~AuraController() override;

    bool isAvailable() const { return m_isAvailable; }

    Q_INVOKABLE void initializeController();
    Q_INVOKABLE void restoreServices(const QString &mode, const QString &color);
    Q_INVOKABLE void setStatic(const QString &colorHex);
    Q_INVOKABLE void setBreathing(const QString &colorHex, int speed);
    Q_INVOKABLE void setRainbow(int speed);
    Q_INVOKABLE void setPulsing(const QString &colorHex, int speed);
    Q_INVOKABLE void setBrightness(int level);
    Q_INVOKABLE int getSystemBrightness();
    
    // Persistence
    Q_INVOKABLE void saveState(const QString &mode, const QString &color);
    Q_INVOKABLE QString getLastMode();
    Q_INVOKABLE QString getLastColor();

signals:
    void isAvailableChanged();

private:
    QString formatColor(const QString &hex);
    void runCommand(const QStringList &args);
    bool runCommandBlocking(const QStringList &args);
    
    // Async Init Helper
    void initializeControllerImpl();
    
private slots:
    void onStrobeTimeout();

private:
    void updateAsusdConfig(const QString &mode, const QString &color);

    // Sysfs + Asusctl Helpers
    bool m_useSysfs = false;
    bool m_useAsusCtl = false;
    QString m_asusCtlPath;

    void writeSysfs(const QString &path, const QString &val);
    void setSysfsColor(int mode, const QString &hex, int speed);

    QString m_rogauraPath;
    bool m_isAvailable;
    
    // Software Strobe
    QTimer *m_strobeTimer;
    bool m_strobeToggle;
    QString m_strobeColor;

    // Async Threading
    QThread *m_initThread;
    QMutex m_mutex;
};

#endif // AURACONTROLLER_H
