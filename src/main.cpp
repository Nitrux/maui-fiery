#include <QApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QQmlContext>
#include <QDate>
#include <QIcon>
#include <QThread>
#include <QSurfaceFormat>
#include <QSettings>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <sys/sysinfo.h>

#include <MauiKit4/Core/mauiapp.h>

#include <KLocalizedString>

#include "models/historymodel.h"
#include "models/bookmarksmodel.h"

#include "controllers/surf.h"
#include "controllers/fierywebprofile.h"
#include "controllers/downloadsmanager.h"
#include "controllers/requestinterceptor.h"
#include "controllers/passwordmanager.h"
#include "controllers/dbactions.h"
#include "controllers/widevineinstaller.h"

#include "../fiery_version.h"

#include <QtWebEngineQuick>

#define FIERY_URI "org.maui.fiery"

int main(int argc, char *argv[])
{
    // Alpha channel for window transparency — must precede QApplication.
    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    // Share GL context between WebEngine and Qt Quick to avoid cross-context texture uploads.
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    // Performance/GPU flags appended to any user-set QTWEBENGINE_CHROMIUM_FLAGS.
    // Must be set before QtWebEngineQuick::initialize().
    QByteArray chromiumFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    if (!chromiumFlags.isEmpty())
        chromiumFlags += ' ';
    // Raster threads: at least 2, scaled to logical core count.
    const int rasterThreads = qMax(2, QThread::idealThreadCount());
    // GPU tile budget: 1/8 of total RAM, clamped to [256, 2048] MB.
    // Chromium's Linux default (~64 MB) is often too low and causes GPU stalls.
    {
        struct sysinfo si{};
        sysinfo(&si);
        const long long totalMb = static_cast<long long>(si.totalram) * si.mem_unit / (1024 * 1024);
        const int gpuBudgetMb   = static_cast<int>(qBound(256LL, totalMb / 8, 2048LL));
        chromiumFlags += "--force-gpu-mem-available-mb=" + QByteArray::number(gpuBudgetMb) + ' ';
    }

    chromiumFlags += "--ignore-gpu-blocklist "
                     "--enable-gpu-rasterization "
                     "--enable-oop-rasterization "
                     "--enable-accelerated-2d-canvas "
                     "--enable-checker-imaging "
                     "--ozone-platform-hint=auto "
                     "--disable-features=OverlayScrollbar "
                     "--enable-features=VaapiVideoDecoder,"
                                        "VaapiVideoEncoder,"
                                        "AcceleratedVideoDecodeLinuxGL "
                     "--num-raster-threads=" + QByteArray::number(rasterThreads);

    // DNS-over-HTTPS: must be read from settings before engine init.
    {
        QSettings s(QStringLiteral("Maui"), QStringLiteral("fiery"));
        s.beginGroup(QStringLiteral("Browser"));
        if (s.value(QStringLiteral("dohEnabled"), false).toBool()) {
            const QString dohUrl = s.value(
                QStringLiteral("dohUrl"),
                QStringLiteral("https://cloudflare-dns.com/dns-query")).toString();
            const QUrl parsedDoh(dohUrl);
            if (parsedDoh.isValid()
                    && parsedDoh.scheme() == QStringLiteral("https")
                    && !dohUrl.contains(QLatin1Char(' '))) {
                chromiumFlags += " --dns-over-https-mode=secure"
                                 " --dns-over-https-templates=" + dohUrl.toUtf8();
            } else {
                qWarning() << "DoH URL rejected (invalid, non-HTTPS, or contains spaces):" << dohUrl;
            }
        }
        s.endGroup();
    }
    {
        QSettings s(QStringLiteral("Maui"), QStringLiteral("fiery"));
        s.beginGroup(QStringLiteral("Browser"));
        const bool widevineEnabled = s.value(QStringLiteral("widevineEnabled"), false).toBool();
        s.endGroup();

        if (widevineEnabled) {
            const QString userCdmDir =
                QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + QStringLiteral("/fiery/WidevineCdm");

            const QStringList candidates = {
                userCdmDir,
                QStringLiteral("/opt/google/chrome/WidevineCdm"),
                QStringLiteral("/opt/google/chrome-beta/WidevineCdm"),
                QStringLiteral("/opt/google/chrome-unstable/WidevineCdm"),
                QStringLiteral("/usr/lib/chromium-browser/WidevineCdm"),
                QStringLiteral("/usr/lib/chromium/WidevineCdm"),
                QStringLiteral("/usr/lib64/chromium/WidevineCdm"),
            };

            QString cdmSo;
            for (const QString &dir : candidates) {
                const QString so = dir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
                if (QFile::exists(dir + QStringLiteral("/manifest.json")) && QFile::exists(so)) {
                    cdmSo = so;
                    break;
                }
            }

            if (cdmSo.isEmpty()) {
                qWarning() << "Widevine: enabled but WidevineCdm not found."
                              " Open Settings → Features and click Install to download it.";
            } else if (cdmSo.contains(QLatin1Char(' '))) {
                qWarning() << "Widevine CDM path contains spaces — cannot load:" << cdmSo;
            } else {
                chromiumFlags += " --widevine-path=" + cdmSo.toLocal8Bit();
                qInfo() << "Widevine CDM:" << cdmSo;
            }
        }
    }

    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", chromiumFlags);

    QtWebEngineQuick::initialize();
    QApplication app(argc, argv);

    app.setWindowIcon(QIcon(":/fiery.svg"));

    KLocalizedString::setApplicationDomain("fiery");
    KAboutData about(QStringLiteral("fiery"),
                     i18n("Fiery"),
                     FIERY_VERSION_STRING,
                     i18n("Browse and organize the web."),
                     KAboutLicense::LGPL_V3,
                     i18n("© %1 Made by Nitrux | Built with MauiKit", QString::number(QDate::currentDate().year())),
                     QString(GIT_BRANCH) + "/" + QString(GIT_COMMIT_HASH));

    about.addAuthor(QStringLiteral("Camilo Higuita"), i18n("Developer"), QStringLiteral("milo.h@aol.com"));
    about.addAuthor(QStringLiteral("Uri Herrera"), i18n("Developer"), QStringLiteral("uri_herrera@nxos.org"));
    about.setHomepage("https://nxos.org");
    about.setProductName("nitrux/fiery");
    about.setOrganizationDomain(FIERY_URI);
    about.setDesktopFileName("org.maui.fiery");
    about.setProgramLogo(app.windowIcon());

    KAboutData::setApplicationData(about);
    // KAboutData::setApplicationData resets the Qt organization name to whatever
    // KAboutData has stored (empty by default). Re-apply it afterwards so that
    // QSettings and QStandardPaths use the correct "Maui" organization prefix,
    // matching the convention used by all other MauiKit applications:
    //   config  → ~/.config/Maui/fiery.conf
    //   cache   → ~/.cache/Maui/fiery/
    app.setOrganizationName(QStringLiteral("Maui"));
    MauiApp::instance()->setIconName("qrc:/fiery.png");

    QCommandLineParser parser;

    about.setupCommandLine(&parser);
    parser.process(app);

    about.processCommandLine(&parser);

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/app/maui/fiery/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl)
    {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);

        //		if(!args.isEmpty())
        //			Sol::getInstance()->requestUrls(args);

    }, Qt::QueuedConnection);


    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));

    qmlRegisterType<surf>(FIERY_URI, 1, 0, "Surf");

    qmlRegisterSingletonInstance<DownloadsManager>(FIERY_URI, 1, 0, "DownloadsManager", &DownloadsManager::instance());
    qmlRegisterSingletonInstance<PasswordManager>(FIERY_URI, 1, 0, "PasswordManager", &PasswordManager::instance());

    qmlRegisterSingletonInstance<DBActions>(FIERY_URI, 1, 0, "DBActions", DBActions::getInstance());
    qmlRegisterSingletonInstance<WidevineInstaller>(FIERY_URI, 1, 0, "WidevineInstaller", &WidevineInstaller::instance());

    qmlRegisterType<FieryWebProfile>(FIERY_URI, 1, 0, "FieryWebProfile");
    qmlRegisterType<RequestInterceptor>(FIERY_URI, 1, 0, "RequestInterceptor");
    qmlRegisterSingletonType<HistoryModel>(FIERY_URI, 1, 0, "History", [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        Q_UNUSED(scriptEngine)
        Q_UNUSED(engine)
        static HistoryModel *instance = new HistoryModel;
        return instance;
    });

    qmlRegisterSingletonType<BookMarksModel>(FIERY_URI, 1, 0, "Bookmarks", [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        Q_UNUSED(scriptEngine)
        Q_UNUSED(engine)
        static BookMarksModel *instance = new BookMarksModel;
        return instance;
    });

    engine.load(url);

    return app.exec();
}
