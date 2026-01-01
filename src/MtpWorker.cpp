#include "MtpWorker.h"

MtpWorker::MtpWorker(QObject *parent) : QObject(parent)
{
    // Timer will be initialized in start() to ensure it belongs to the correct thread
}

void MtpWorker::start()
{
    m_timer = new QTimer(this);
    m_timer->setInterval(1000); // Scan every 1 second (Faster mobile detection)
    connect(m_timer, &QTimer::timeout, this, &MtpWorker::scan);
    m_timer->start();
    
    // Initial scan
    scan();
}

void MtpWorker::scan()
{
    QVariantList newMtpDevices;
    
    QString user = qgetenv("SUDO_USER");
    if (user.isEmpty()) user = qgetenv("USER");
    


    if (!user.isEmpty() && user != "root") {
        // Get UID for the user
        QProcess idProc;
        idProc.start("id", QStringList() << "-u" << user);
        
        if (idProc.waitForFinished(1000)) {
             QString uid = idProc.readAllStandardOutput().trimmed();

            if (!uid.isEmpty()) {
                QString busEnv = QString("DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%1/bus").arg(uid);
                QString runtimeEnv = QString("XDG_RUNTIME_DIR=/run/user/%1").arg(uid);
                
                QProcess gioProc;
                gioProc.start("runuser", QStringList() << "-u" << user << "--" << "env" << busEnv << runtimeEnv << "gio" << "mount" << "-l");
                
                if (gioProc.waitForFinished(3000)) {
                    QString output = gioProc.readAllStandardOutput();

                    
                    QRegularExpression reMount("Mount\\(\\d+\\):\\s+(.+?)\\s+->\\s+((?:mtp|afc|gphoto2)://\\S+)");
                    QRegularExpressionMatchIterator i = reMount.globalMatch(output);
                    
                    QSet<QString> seenUris;

                    while (i.hasNext()) {
                        QRegularExpressionMatch match = i.next();
                        QString deviceName = match.captured(1).trimmed();
                        QString deviceUri = match.captured(2).trimmed();
                        


                        if (seenUris.contains(deviceUri)) continue;
                        seenUris.insert(deviceUri);
                        
                        QProcess infoProc;
                        // Log the exact command for debugging
                        // qDebug() << "MtpWorker: Running info on:" << deviceUri;
                        infoProc.start("runuser", QStringList() << "-u" << user << "--" << "env" << busEnv << runtimeEnv << "gio" << "info" << "-a" << "filesystem::*" << deviceUri);
                        
                        if (infoProc.waitForFinished(5000)) { // Increased to 5000ms
                            QString infoOut = infoProc.readAllStandardOutput();
                            QRegularExpression reSize("filesystem::size:\\s+(\\d+)");
                            QRegularExpression reFree("filesystem::free:\\s+(\\d+)");
                            
                            QRegularExpressionMatch mSize = reSize.match(infoOut);
                            QRegularExpressionMatch mFree = reFree.match(infoOut);
                            
                            if (mSize.hasMatch()) {
                                double sizeBytes = mSize.captured(1).toDouble();
                                double freeBytes = mFree.hasMatch() ? mFree.captured(1).toDouble() : 0;
                                double usedBytes = sizeBytes - freeBytes;
                                
                                if (sizeBytes < 100.0 * 1000.0 * 1000.0) continue; 
                                
                                double sizeGB = sizeBytes / (1000.0 * 1000.0 * 1000.0);
                                double usedGB = usedBytes / (1000.0 * 1000.0 * 1000.0);
                                double freeGB = freeBytes / (1000.0 * 1000.0 * 1000.0);
                                double usagePercent = (sizeBytes > 0) ? (usedBytes / sizeBytes) * 100.0 : 0;
                                double freePercent = (sizeBytes > 0) ? (freeBytes / sizeBytes) * 100.0 : 0;
                                
                                QVariantMap p;
                                p["name"] = deviceName; 
                                p["mount"] = deviceUri;
                                p["fsType"] = "MTP";
                                p["total"] = QString::number(sizeGB, 'f', 1);
                                p["used"] = QString::number(usedGB, 'f', 1);
                                p["free"] = QString::number(freeGB, 'f', 1);
                                p["usage"] = usagePercent;
                                p["freePercent"] = freePercent;
                                p["isMounted"] = true;
                                p["hasUsage"] = true;
                                
                                newMtpDevices.append(p);
                            } else {
                                // Root has no size? It might be a container (e.g. "SAMSUNG Android" -> "Internal Storage")
                                
                                bool childrenAdded = false;
                                
                                QProcess listProc;
                                listProc.start("runuser", QStringList() << "-u" << user << "--" << "env" << busEnv << runtimeEnv << "gio" << "list" << "-u" << deviceUri);
                                
                                if (listProc.waitForFinished(3000)) {
                                    QString listOut = listProc.readAllStandardOutput().trimmed();
                                    if (!listOut.isEmpty()) {
                                        QStringList children = listOut.split('\n');
                                        for (const QString &childUri : children) {
                                            QString cleanUri = childUri.trimmed();
                                            if (cleanUri.isEmpty()) continue;
                                            
                                            QProcess childInfo;
                                            childInfo.start("runuser", QStringList() << "-u" << user << "--" << "env" << busEnv << runtimeEnv << "gio" << "info" << "-a" << "filesystem::*,standard::display-name" << cleanUri);
                                            
                                            if (childInfo.waitForFinished(3000)) {
                                                QString cInfo = childInfo.readAllStandardOutput();
                                                QRegularExpression cSize("filesystem::size:\\s+(\\d+)");
                                                QRegularExpression cFree("filesystem::free:\\s+(\\d+)");
                                                QRegularExpression cName("standard::display-name:\\s+(.+)");
                                                
                                                QRegularExpressionMatch mcSize = cSize.match(cInfo);
                                                QRegularExpressionMatch mcFree = cFree.match(cInfo);
                                                QRegularExpressionMatch mcName = cName.match(cInfo);
                                                
                                                if (mcSize.hasMatch()) {
                                                    double sizeBytes = mcSize.captured(1).toDouble();
                                                    double freeBytes = mcFree.hasMatch() ? mcFree.captured(1).toDouble() : 0;
                                                    double usedBytes = sizeBytes - freeBytes;
                                                    
                                                    if (sizeBytes < 100.0 * 1000.0 * 1000.0) continue;
                                                    
                                                    double sizeGB = sizeBytes / (1000.0 * 1000.0 * 1000.0);
                                                    double usedGB = usedBytes / (1000.0 * 1000.0 * 1000.0);
                                                    double freeGB = freeBytes / (1000.0 * 1000.0 * 1000.0);
                                                    
                                                    QString childName = mcName.hasMatch() ? mcName.captured(1).trimmed() : deviceName;
                                                    // Make it clear: "SAMSUNG Android - Internal Storage"
                                                    if (childName != deviceName) {
                                                        childName = deviceName + " - " + childName;
                                                    }
                                                    
                                                    QVariantMap p;
                                                    p["name"] = childName; 
                                                    p["mount"] = cleanUri;
                                                    p["fsType"] = "MTP";
                                                    p["total"] = QString::number(sizeGB, 'f', 1);
                                                    p["used"] = QString::number(usedGB, 'f', 1);
                                                    p["free"] = QString::number(freeGB, 'f', 1);
                                                    p["usage"] = (sizeBytes > 0) ? (usedBytes / sizeBytes) * 100.0 : 0;
                                                    p["freePercent"] = (sizeBytes > 0) ? (freeBytes / sizeBytes) * 100.0 : 0;
                                                    p["isMounted"] = true;
                                                    p["hasUsage"] = true;
                                                    
                                                    newMtpDevices.append(p);
                                                    childrenAdded = true;
                                                }
                                            } else {
                                                childInfo.kill();
                                            }
                                        }
                                    }
                                } else {
                                    listProc.kill();
                                }
                                
                                // Fallback: If no children added, add the root device with unknown usage
                                if (!childrenAdded) {
                                     QVariantMap p;
                                     p["name"] = deviceName; 
                                     p["mount"] = deviceUri;
                                     p["fsType"] = "MTP";
                                     p["total"] = "-- GB"; 
                                     p["used"] = "-- GB";
                                     p["free"] = "--";
                                     p["usage"] = 0;
                                     p["freePercent"] = 0;
                                     p["isMounted"] = true;
                                     p["hasUsage"] = false; // Hide usage bar
                                     
                                     newMtpDevices.append(p);
                                }
                            }
                        } else {
                            // Info process failed or timed out for ROOT device
                            infoProc.terminate();
                            infoProc.waitForFinished(100);
                        }
                    }
                } else {
                     gioProc.kill();
                }
            }
        } else {
            idProc.kill();
        }
    }
    
    emit devicesFound(newMtpDevices);
}
