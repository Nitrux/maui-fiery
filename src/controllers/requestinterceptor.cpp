#include "requestinterceptor.h"

#include <QWebEngineUrlRequestInfo>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QDebug>

// Built-in block list — common ad networks and trackers.
// To use a custom list, place a hosts-format file at:
//   ~/.config/fiery/blocklist.txt
// Lines starting with '#' are comments. Entries can be plain hostnames
// ("example.com") or hosts-file format ("0.0.0.0 example.com").
static const QStringList s_builtinBlockList = {
    // Google advertising & analytics
    "doubleclick.net",
    "googleadservices.com",
    "googlesyndication.com",
    "pagead2.googlesyndication.com",
    "adservice.google.com",
    "google-analytics.com",
    "analytics.google.com",
    "stats.g.doubleclick.net",
    "imasdk.googleapis.com",
    // Amazon ads
    "adsystem.amazon.com",
    "aax.amazon-adsystem.com",
    // AppNexus / Xandr
    "adnxs.com",
    // Comscore
    "scorecardresearch.com",
    "beacon.scorecardresearch.com",
    // Outbrain / Taboola
    "outbrain.com",
    "taboola.com",
    "trc.taboola.com",
    // Oath / Yahoo ads
    "advertising.com",
    "adtech.de",
    // Twitter ads
    "ads.twitter.com",
    "t.co",
    // Meta / Facebook tracking
    "connect.facebook.net",
    "pixel.facebook.com",
    "an.facebook.com",
    // TikTok analytics
    "tracking.tiktok.com",
    "analytics.tiktok.com",
    // Microsoft / Bing ads & Clarity
    "bat.bing.com",
    "c.clarity.ms",
    "clarity.ms",
    // LinkedIn
    "snap.licdn.com",
    "px.ads.linkedin.com",
    // Quantcast
    "quantserve.com",
    "pixel.quantserve.com",
    // Criteo
    "criteo.com",
    "static.criteo.net",
    // TradeDesk
    "adsrvr.org",
    // Hotjar
    "hotjar.com",
    "script.hotjar.com",
    // New Relic
    "nr-data.net",
    // Sentry (error tracking, not ads, but can be noisy)
    // "sentry.io",  -- intentionally excluded; used for crash reporting
};

RequestInterceptor::RequestInterceptor(QObject *parent)
    : QWebEngineUrlRequestInterceptor(parent)
{
    loadBlockList();
}

void RequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    if (m_doNotTrack)
        info.setHttpHeader("DNT", "1");

    if (m_adBlockEnabled) {
        const QString host = info.requestUrl().host();
        for (const QString &blocked : m_blockedHosts) {
            if (host == blocked || host.endsWith(QLatin1Char('.') + blocked)) {
                info.block(true);
                return;
            }
        }
    }
}

bool RequestInterceptor::doNotTrack() const { return m_doNotTrack; }

void RequestInterceptor::setDoNotTrack(bool enabled)
{
    if (m_doNotTrack == enabled)
        return;
    m_doNotTrack = enabled;
    Q_EMIT doNotTrackChanged();
}

bool RequestInterceptor::adBlockEnabled() const { return m_adBlockEnabled; }

void RequestInterceptor::setAdBlockEnabled(bool enabled)
{
    if (m_adBlockEnabled == enabled)
        return;
    m_adBlockEnabled = enabled;
    Q_EMIT adBlockEnabledChanged();
}

void RequestInterceptor::loadBlockList()
{
    m_blockedHosts.clear();

    const QString userList = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
                             + QStringLiteral("/blocklist.txt");
    QFile file(userList);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) {
            const QString line = in.readLine().trimmed();
            if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
                continue;
            // Support both "domain.com" and hosts-file "0.0.0.0 domain.com"
            const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
            m_blockedHosts.insert(parts.size() >= 2 ? parts.at(1) : parts.at(0));
        }
        qInfo() << "RequestInterceptor: loaded" << m_blockedHosts.size()
                << "blocked hosts from" << userList;
        return;
    }

    for (const QString &host : s_builtinBlockList)
        m_blockedHosts.insert(host);

    qInfo() << "RequestInterceptor: using built-in block list ("
            << m_blockedHosts.size() << "entries)";
}
