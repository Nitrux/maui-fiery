#include "fierywebprofile.h"

#include <QQuickWindow>
#include <QWebEngineNotification>
#include <KNotification>
#include <KLocalizedString>

#include <QWebEngineUrlRequestInterceptor>
#include <QWebEngineDownloadRequest>
#include <QWebEngineCookieStore>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QDir>

#include "downloadsmanager.h"

// QQuickWebEngineDownloadRequest is not in public headers; forward-declare it
// as a DownloadItem subclass since that is what Qt's runtime type actually is.
class QQuickWebEngineDownloadRequest : public DownloadItem {};

FieryWebProfile::FieryWebProfile(QObject *parent)
    : QQuickWebEngineProfile{QStringLiteral("Fiery"), parent}
{
    // QStandardPaths::AppDataLocation includes the organization name on this
    // Linux/Qt build, producing ~/.local/share/Maui/fiery — but MauiKit
    // convention is ~/.local/share/<app> (no org prefix in the data dir).
    // Pin the path explicitly using GenericDataLocation (always XDG_DATA_HOME,
    // i.e. ~/.local/share) and append only the application name.
    const QString dataBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                             + QLatin1Char('/') + QCoreApplication::applicationName();
    setPersistentStoragePath(dataBase + QStringLiteral("/QtWebEngine/Fiery"));

    // The named-profile constructor derives a default path from AppDataLocation
    // (which includes the org name on some Linux/Qt builds) and creates that
    // directory tree before setPersistentStoragePath can redirect it.  Walk
    // back up and remove each empty directory so they do not linger.
    // QDir::rmdir() is a no-op on non-empty directories, so this is safe.
    const QString defaultBase = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (defaultBase != dataBase) {
        QDir stale(defaultBase + QStringLiteral("/QtWebEngine"));
        stale.rmdir(QStringLiteral("Fiery"));       // …/QtWebEngine/Fiery
        stale.cdUp();
        stale.rmdir(QStringLiteral("QtWebEngine")); // …/Maui/fiery/QtWebEngine
        QDir appDir(defaultBase);
        appDir.cdUp();
        const QString orgDir = appDir.absolutePath();
        QDir().rmdir(defaultBase);                  // …/Maui/fiery  (only if now empty)
        QDir().rmdir(orgDir);                       // …/Maui        (only if now empty)
    }
    connect(this, &QQuickWebEngineProfile::downloadRequested, this, &FieryWebProfile::handleDownload);
    connect(this, &QQuickWebEngineProfile::downloadFinished, this, &FieryWebProfile::handleDownloadFinished);
    connect(this, &QQuickWebEngineProfile::presentNotification, this, &FieryWebProfile::showNotification);

}

QWebEngineUrlRequestInterceptor *FieryWebProfile::urlInterceptor() const
{
    return m_urlInterceptor;
}

void FieryWebProfile::handleDownload(QQuickWebEngineDownloadRequest *downloadItem)
{
    DownloadItem *download = qobject_cast<DownloadItem *>(downloadItem);
    if (!download)
        return;

    // Rate limiting: reject requests beyond kMaxDownloadsPerSecond per second.
    // Not calling accept() is sufficient — Qt cancels the download automatically.
    if (!m_downloadRateTimer.isValid() || m_downloadRateTimer.elapsed() > 1000) {
        m_downloadRateTimer.start();
        m_downloadRateCount = 0;
    }
    if (++m_downloadRateCount > kMaxDownloadsPerSecond) {
        qWarning() << "FieryWebProfile: download rate limit exceeded, rejecting request from"
                   << download->url().host();
        return;
    }

    download->accept();
    download->pause();

    DownloadsManager::instance().add(download);
}

void FieryWebProfile::handleDownloadFinished(DownloadItem *downloadItem)
{
    Q_EMIT downloadFinished(downloadItem);
}

void FieryWebProfile::showNotification(QWebEngineNotification *webNotification)
{
    if (!webNotification)
        return;

    // Registers the notification with the browser engine (fires Notification.onshow).
    webNotification->show();
    m_pendingNotification = webNotification;

    // Forward the notification to the desktop notification system via KNotification
    // so it appears in the system tray / notification centre rather than as an
    // in-app popup inside the browser window.
    const QString origin = webNotification->origin().host();
    const QString title  = origin.isEmpty()
                               ? webNotification->title()
                               : origin + QStringLiteral(": ") + webNotification->title();

    auto *notif = new KNotification(QStringLiteral("webNotification"),
                                    KNotification::CloseOnTimeout, this);
    notif->setTitle(title);
    notif->setText(webNotification->message());
    notif->setIconName(QStringLiteral("fiery"));

    // Clicking the notification fires the page's Notification.onclick callback.
    auto *action = notif->addAction(i18n("Open"));
    connect(action, &KNotificationAction::activated,
            this,   &FieryWebProfile::acceptNotification);

    notif->sendEvent();
}

void FieryWebProfile::acceptNotification()
{
    if (m_pendingNotification)
        m_pendingNotification->click();
}

void FieryWebProfile::updateCookieFilter()
{
    if (!m_blockThirdPartyCookies) {
        cookieStore()->setCookieFilter(nullptr);
        return;
    }
    // Capture whitelist by value so the lambda stays valid after the property changes.
    const QStringList whitelist = m_thirdPartyCookiesWhitelist;
    cookieStore()->setCookieFilter([whitelist](const QWebEngineCookieStore::FilterRequest &req) -> bool {
        if (!req.thirdParty)
            return true;
        // Allow third-party cookies when the page's host matches a whitelisted domain.
        const QString host = req.firstPartyUrl.host();
        for (const QString &allowed : whitelist) {
            if (!allowed.isEmpty() && (host == allowed || host.endsWith(QLatin1Char('.') + allowed)))
                return true;
        }
        return false;
    });
}

bool FieryWebProfile::blockThirdPartyCookies() const { return m_blockThirdPartyCookies; }

void FieryWebProfile::setBlockThirdPartyCookies(bool block)
{
    if (m_blockThirdPartyCookies == block)
        return;
    m_blockThirdPartyCookies = block;
    updateCookieFilter();
    Q_EMIT blockThirdPartyCookiesChanged();
}

QStringList FieryWebProfile::thirdPartyCookiesWhitelist() const { return m_thirdPartyCookiesWhitelist; }

void FieryWebProfile::setThirdPartyCookiesWhitelist(const QStringList &whitelist)
{
    if (m_thirdPartyCookiesWhitelist == whitelist)
        return;
    m_thirdPartyCookiesWhitelist = whitelist;
    updateCookieFilter();   // reinstall filter with the new whitelist
    Q_EMIT thirdPartyCookiesWhitelistChanged();
}

void FieryWebProfile::setUrlInterceptor(QWebEngineUrlRequestInterceptor *newUrlInterceptor)
{
    if (m_urlInterceptor == newUrlInterceptor)
        return;
    m_urlInterceptor = newUrlInterceptor;
    setUrlRequestInterceptor(newUrlInterceptor);
    Q_EMIT urlInterceptorChanged();
}
