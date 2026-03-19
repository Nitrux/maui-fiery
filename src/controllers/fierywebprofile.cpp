#include "fierywebprofile.h"

#include <QQuickWindow>
#include <QWebEngineNotification>
#include <KNotification>
#include <KLocalizedString>

#include <QWebEngineUrlRequestInterceptor>
#include <QWebEngineDownloadRequest>

#include "downloadsmanager.h"

// QQuickWebEngineDownloadRequest is not in public headers; forward-declare it
// as a DownloadItem subclass since that is what Qt's runtime type actually is.
class QQuickWebEngineDownloadRequest : public DownloadItem {};

FieryWebProfile::FieryWebProfile(QObject *parent)
    : QQuickWebEngineProfile{QStringLiteral("Fiery"), parent}
{
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

void FieryWebProfile::setUrlInterceptor(QWebEngineUrlRequestInterceptor *newUrlInterceptor)
{
    if (m_urlInterceptor == newUrlInterceptor)
        return;
    m_urlInterceptor = newUrlInterceptor;
    setUrlRequestInterceptor(newUrlInterceptor);
    Q_EMIT urlInterceptorChanged();
}
