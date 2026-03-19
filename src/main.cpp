#include <QApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QQmlContext>
#include <QDate>
#include <QIcon>
#include <QThread>
#include <QSurfaceFormat>

#include <MauiKit4/Core/mauiapp.h>

#include <KLocalizedString>

#include "models/historymodel.h"
#include "models/bookmarksmodel.h"

#include "controllers/surf.h"
#include "controllers/fierywebprofile.h"
#include "controllers/downloadsmanager.h"
#include "controllers/requestinterceptor.h"

#include "../fiery_version.h"

#include <QtWebEngineQuick>

#define FIERY_URI "org.maui.fiery"

int main(int argc, char *argv[])
{
    // Enable compositor-level alpha channel for window transparency.
    // Must be set before QApplication is created.
    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    // Allow WebEngine and Qt Quick to share the same OpenGL context.
    // Without this, every composited WebEngine frame requires an extra
    // texture upload across context boundaries.
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    // Append performance flags to whatever the user may have set in the
    // environment. These must be set before QtWebEngineQuick::initialize().
    //
    // --ignore-gpu-blocklist          Force GPU rasterization even when
    //                                 Chromium's internal blocklist would
    //                                 fall back to software (common on Linux).
    // --enable-gpu-rasterization      Rasterize tiles on the GPU.
    // --enable-oop-rasterization      Rasterize in the GPU process, freeing
    // --canvas-oop-rasterization      the renderer thread for JS work.
    // --num-raster-threads=4          Parallelise tile rasterization.
    QByteArray chromiumFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    if (!chromiumFlags.isEmpty())
        chromiumFlags += ' ';
    // Use at least 2 raster threads, scaled to the number of logical cores.
    // Avoids unnecessary context switching on low-end devices while allowing
    // high-end hardware to fully utilise available cores.
    const int rasterThreads = qMax(2, QThread::idealThreadCount());
    chromiumFlags += "--ignore-gpu-blocklist "
                     "--enable-gpu-rasterization "
                     "--enable-oop-rasterization "
                     "--canvas-oop-rasterization "
                     "--ozone-platform-hint=auto "
                     "--disable-features=OverlayScrollbar "
                     "--num-raster-threads=" + QByteArray::number(rasterThreads);
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
