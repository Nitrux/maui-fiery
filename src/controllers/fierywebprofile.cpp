#include "fierywebprofile.h"


#include <QQuickWindow>
#include <QWebEngineNotification>

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

    download->accept();
    download->pause();

    DownloadsManager::instance().add(downloadItem);
}

void FieryWebProfile::handleDownloadFinished(DownloadItem *downloadItem)
{
    Q_EMIT downloadFinished(downloadItem);
}

void FieryWebProfile::showNotification(QWebEngineNotification *webNotification)
{
    if (!webNotification)
        return;

    // show() registers the notification as displayed and fires the web page's
    // Notification.onshow callback.
    webNotification->show();

    m_pendingNotification = webNotification;
    Q_EMIT notificationReceived(webNotification->title(), webNotification->message());
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
