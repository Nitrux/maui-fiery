#include <QApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QQmlContext>
#include <QIcon>

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
    chromiumFlags += "--ignore-gpu-blocklist "
                     "--enable-gpu-rasterization "
                     "--enable-oop-rasterization "
                     "--canvas-oop-rasterization "
                     "--num-raster-threads=4";
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", chromiumFlags);

    QtWebEngineQuick::initialize();
    QApplication app(argc, argv);

    app.setOrganizationName("Maui");
    app.setWindowIcon(QIcon(":/fiery.svg"));
    
    KLocalizedString::setApplicationDomain("fiery");
    KAboutData about(QStringLiteral("fiery"),
                     QStringLiteral("Fiery"), 
                     FIERY_VERSION_STRING, 
                     i18n("Browse and organize the web."),
                     KAboutLicense::LGPL_V3, 
                     APP_COPYRIGHT_NOTICE, 
                     QString(GIT_BRANCH) + "/" + QString(GIT_COMMIT_HASH));
    
    about.addAuthor(QStringLiteral("Camilo Higuita"), i18n("Developer"), QStringLiteral("milo.h@aol.com"));
    about.setHomepage("https://mauikit.org");
    about.setProductName("maui/fiery");
    about.setBugAddress("https://invent.kde.org/maui/fiery/-/issues");
    about.setOrganizationDomain(FIERY_URI);
    about.setProgramLogo(app.windowIcon());

    KAboutData::setApplicationData(about);
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

        //           engine->setObjectOwnership(platform, QQmlEngine::CppOwnership);
        return new HistoryModel;
    });


    qmlRegisterSingletonType<BookMarksModel>(FIERY_URI, 1, 0, "Bookmarks", [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        Q_UNUSED(scriptEngine)
        Q_UNUSED(engine)

        //           engine->setObjectOwnership(platform, QQmlEngine::CppOwnership);
        return new BookMarksModel;
    });

    engine.load(url);

    return app.exec();
}
