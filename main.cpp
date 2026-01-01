#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTranslator>
#include <QDir>
#include <QIcon>
#include <QPixmap>
#include <QDebug>
#include <QFont>
#include <QSurfaceFormat>
#include "src/FanController.h"
#include "src/SystemStatsMonitor.h"
#include "src/AuraController.h"
#include "src/FanCurveController.h"

#include <stdio.h>

// Security Fix: Custom Message Handler
// Protects against Information Disclosure by suppressing debug logs in Release builds
void secureMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    // Suppress noisy font warnings that cause false alarms
    if (msg.contains("OpenType support missing")) {
        return;  // These are harmless Qt font rendering hints, not errors
    }
    
    // In Release builds (when QT_DEBUG is NOT defined), suppress Debug and Info messages
    // This prevents leaking system paths, arguments, and hardware details to stdout
#ifndef QT_DEBUG
    if (type == QtDebugMsg || type == QtInfoMsg) {
        return;
    }
#endif

    // Default formatting for allowed messages
    QByteArray localMsg = msg.toLocal8Bit();
    const char *file = context.file ? context.file : "";
    
    switch (type) {
    case QtDebugMsg:
        fprintf(stderr, "Debug: %s\n", localMsg.constData());
        break;
    case QtInfoMsg:
        fprintf(stderr, "Info: %s\n", localMsg.constData());
        break;
    case QtWarningMsg:
        fprintf(stderr, "Warning: %s\n", localMsg.constData());
        break;
    case QtCriticalMsg:
        fprintf(stderr, "Critical: %s (%s:%u)\n", localMsg.constData(), file, context.line);
        break;
    case QtFatalMsg:
        fprintf(stderr, "Fatal: %s (%s:%u)\n", localMsg.constData(), file, context.line);
        abort();
    }
}

int main(int argc, char *argv[])
{
    // Performance: Force hardware OpenGL rendering (prevents software fallback)
    qputenv("QSG_RENDER_LOOP", "basic");  // Use basic render loop for stability
    qputenv("QT_QUICK_BACKEND", "");  // Use default (OpenGL) not software
    
    // Install Security Handler
    qInstallMessageHandler(secureMessageHandler);
    
    // Performance: Set OpenGL surface format before app creation
    QSurfaceFormat format;
    format.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    format.setSwapInterval(1);  // VSync on
    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);
    
    // Fix: Set fonts with proper multi-script support (Tamil, Hindi, Arabic, etc.)
    // Using font families that include all script variants reduces fallback lag
    QFont defaultFont;
    defaultFont.setFamilies({"Noto Sans", "Noto Sans Tamil", "Noto Sans Tamil UI", 
                             "Noto Sans Devanagari", "Noto Sans Arabic", "Noto Color Emoji"});
    defaultFont.setPointSize(10);
    defaultFont.setStyleHint(QFont::SansSerif);
    app.setFont(defaultFont);
    
    // Fix: Set Identity for consistent QSettings location
    app.setOrganizationName("AsusTuf");
    app.setApplicationName("FanControl");

    // i18n Fix: Load Translations
    QTranslator translator;
    const QStringList uiLanguages = QLocale::system().uiLanguages();
    
    qInfo() << "System Locale:" << QLocale::system().name();
    qInfo() << "UI Languages:" << uiLanguages;
    
    // DEBUG: List available resources
    QDir resDir(":/translations");
    qInfo() << "Available Translations in binary:" << resDir.entryList();

    for (const QString &locale : uiLanguages) {
        // Try precise match first
        QString baseName = "AsusTufFanControl_" + QLocale(locale).name();
        qInfo() << "Attempting to load translation:" << baseName;
        
        if (translator.load(":/translations/" + baseName) || translator.load(":/translations/" + baseName + ".qm")) {
            qInfo() << "Successfully loaded:" << baseName;
            app.installTranslator(&translator);
            break;
        } else {
            // Try fallback to just the language code (e.g. "es" from "es_ES")
            QString langCode = QLocale(locale).name().split('_').first();
            if (langCode != QLocale(locale).name()) {
                 QString fallbackName = "AsusTufFanControl_" + langCode;
                 qInfo() << "Attempting fallback:" << fallbackName;
                 if (translator.load(":/translations/" + fallbackName) || translator.load(":/translations/" + fallbackName + ".qm")) {
                     qInfo() << "Successfully loaded fallback:" << fallbackName;
                     app.installTranslator(&translator);
                     break;
                 }
            }
        }
    }

    // --- DEBUG CHECK ---
    QPixmap testLoad(":/ui/app_icon.png");
    if (testLoad.isNull()) {
        qCritical() << "ERROR: Image failed to load! Check file path and re-run cmake.";
    } else {
        qInfo() << "SUCCESS: Image loaded. Size:" << testLoad.size();
        app.setWindowIcon(QIcon(testLoad));
    }
    // -------------------

    qmlRegisterType<FanController>("AsusTufFanControl", 1, 0, "FanController");
    qmlRegisterType<SystemStatsMonitor>("AsusTufFanControl", 1, 0, "SystemStatsMonitor");
    qmlRegisterType<AuraController>("AsusTufFanControl", 1, 0, "AuraController");
    qmlRegisterType<FanCurveController>("AsusTufFanControl", 1, 0, "FanCurveController");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/ui/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    
    engine.load(url);

    return app.exec();
}