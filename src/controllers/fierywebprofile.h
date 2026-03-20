#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QQuickWebEngineProfile>
#include <QWebEngineUrlRequestInterceptor>
#include <QWebEngineDownloadRequest>
#include <QElapsedTimer>

using DownloadItem = QWebEngineDownloadRequest;

class QWebEngineNotification;
class QQuickItem;
class QWebEngineUrlRequestInterceptor;

class FieryWebProfile : public QQuickWebEngineProfile
{
    Q_OBJECT
    Q_PROPERTY(QWebEngineUrlRequestInterceptor *urlInterceptor WRITE setUrlInterceptor READ urlInterceptor NOTIFY urlInterceptorChanged)
    Q_PROPERTY(bool blockThirdPartyCookies READ blockThirdPartyCookies WRITE setBlockThirdPartyCookies NOTIFY blockThirdPartyCookiesChanged)
    Q_PROPERTY(QStringList thirdPartyCookiesWhitelist READ thirdPartyCookiesWhitelist WRITE setThirdPartyCookiesWhitelist NOTIFY thirdPartyCookiesWhitelistChanged)

public:
    explicit FieryWebProfile(QObject *parent = nullptr);

    QWebEngineUrlRequestInterceptor *urlInterceptor() const;
    void setUrlInterceptor(QWebEngineUrlRequestInterceptor *newUrlInterceptor);

    bool blockThirdPartyCookies() const;
    void setBlockThirdPartyCookies(bool block);

    QStringList thirdPartyCookiesWhitelist() const;
    void setThirdPartyCookiesWhitelist(const QStringList &whitelist);

    Q_INVOKABLE void acceptNotification();

Q_SIGNALS:
    void urlInterceptorChanged();
    void blockThirdPartyCookiesChanged();
    void thirdPartyCookiesWhitelistChanged();
    void downloadFinished(DownloadItem *download);

private:

    void handleDownload(QQuickWebEngineDownloadRequest *downloadItem);
    void handleDownloadFinished(DownloadItem *downloadItem);
    void showNotification(QWebEngineNotification *webNotification);

         // A valid property needs a read function, and there is no getter in QQuickWebEngineProfile
         // so store a pointer ourselves
    QWebEngineUrlRequestInterceptor *m_urlInterceptor = nullptr;
    bool        m_blockThirdPartyCookies = false;
    QStringList m_thirdPartyCookiesWhitelist;

    void updateCookieFilter();

    // QPointer self-nulls if the engine destroys the notification before
    // the user acts on the desktop KNotification, preventing a use-after-free.
    QPointer<QWebEngineNotification> m_pendingNotification;

    // Rate limiting for download requests: max 5 per second.
    QElapsedTimer m_downloadRateTimer;
    int           m_downloadRateCount = 0;
    static constexpr int kMaxDownloadsPerSecond = 5;

};

