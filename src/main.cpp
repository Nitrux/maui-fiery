#include <QApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QQmlContext>
#include <QDate>
#include <QIcon>
#include <QThread>
#include <QSurfaceFormat>
#include <QSettings>
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
    // --enable-accelerated-2d-canvas  GPU-accelerated HTML5 canvas (critical for
    //                                 canvas-based benchmarks and games).
    // --num-raster-threads=N          Parallelise tile rasterization.
    // --enable-checker-imaging        Decode images asynchronously on a worker
    //                                 thread; the main/compositor thread gets a
    //                                 checkerboard placeholder until decoding
    //                                 completes, keeping scrolling smooth even on
    //                                 image-heavy pages.
    // VaapiVideoDecoder               VA-API hardware video decoding.
    // VaapiVideoEncoder               VA-API hardware video encoding (WebRTC etc).
    // AcceleratedVideoDecodeLinuxGL   OpenGL-based hardware decode fallback for
    //                                 GPUs that expose GL but not DMA-BUF.
    QByteArray chromiumFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    if (!chromiumFlags.isEmpty())
        chromiumFlags += ' ';
    // Use at least 2 raster threads, scaled to the number of logical cores.
    // Avoids unnecessary context switching on low-end devices while allowing
    // high-end hardware to fully utilise available cores.
    const int rasterThreads = qMax(2, QThread::idealThreadCount());
    // Compute a GPU tile-memory budget from system RAM.
    // Chromium's default on Linux is often as low as 64 MB (GPU VRAM detection
    // fails under Wayland), which causes the tile manager to exhaust its budget
    // on complex pages, stall the GPU process, and — because Qt Quick shares the
    // same GL context via AA_ShareOpenGLContexts — freeze the entire UI.
    // Budget: 1/8 of total RAM, clamped to [256, 2048] MB.
    // The upper bound was previously 1024 MB, which under-allocated on ≥16 GB
    // systems and caused Chromium's tile manager to evict GPU tiles on complex
    // pages, stalling the GPU process and hurting rendering benchmarks.
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

    // DNS-over-HTTPS: read user preference from persistent settings before
    // initialising the engine — Chromium only picks up these flags at startup.
    {
        QSettings s(QStringLiteral("Maui"), QStringLiteral("fiery"));
        s.beginGroup(QStringLiteral("Browser"));
        if (s.value(QStringLiteral("dohEnabled"), false).toBool()) {
            const QString dohUrl = s.value(
                QStringLiteral("dohUrl"),
                QStringLiteral("https://cloudflare-dns.com/dns-query")).toString();
            chromiumFlags += " --dns-over-https-mode=secure"
                             " --dns-over-https-templates=" + dohUrl.toUtf8();
        }
        s.endGroup();
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
