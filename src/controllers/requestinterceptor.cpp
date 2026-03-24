#include "requestinterceptor.h"

#include <QWebEngineUrlRequestInfo>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

static const QSet<QString> TRACKING_PARAMS = {
    // Google Analytics / UTM
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
    // Google Ads
    "gclid", "gclsrc", "dclid",
    // Google Analytics client ID (appended by gtag.js)
    "_ga", "_gl",
    // Facebook
    "fbclid", "fb_action_ids", "fb_action_types",
    // Instagram
    "igshid",
    // Microsoft Ads
    "msclkid",
    // Yandex
    "yclid",
    // Twitter / X
    "twclid",
    // LinkedIn
    "li_fat_id",
    // Mailchimp
    "mc_eid",
    // Marketo
    "mkt_tok",
    // HubSpot
    "hsa_acc", "hsa_cam", "hsa_grp", "hsa_ad", "hsa_src", "hsa_tgt", "hsa_kw",
    "hsa_mt", "hsa_net", "hsa_ver",
};

// Built-in block list is embedded as a Qt resource (:/blocklist.txt).
// To override it, place a hosts-format file at:
//   ~/.config/fiery/blocklist.txt
// Lines starting with '#' are comments. Entries can be plain hostnames
// ("example.com") or hosts-file format ("0.0.0.0 example.com").

RequestInterceptor::RequestInterceptor(QObject *parent)
    : QWebEngineUrlRequestInterceptor(parent)
{
    loadBlockList();
}

void RequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    if (!m_doNotTrack && !m_httpsOnly && !m_adBlockEnabled
            && !m_stripTrackingParams && !m_globalPrivacyControl && !m_blockAmpLinks)
        return;

    if (m_doNotTrack)
        info.setHttpHeader("DNT", "1");

    if (m_globalPrivacyControl)
        info.setHttpHeader("Sec-GPC", "1");

    QUrl url = info.requestUrl();

    if (m_blockAmpLinks
            && info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeMainFrame) {
        const QString host = url.host();
        const QString path = url.path();
        // Google AMP proxy: google.com/amp/s/<canonical-url>
        if ((host == QLatin1String("www.google.com") || host == QLatin1String("google.com"))
                && path.startsWith(QLatin1String("/amp/s/"))) {
            info.redirect(QUrl(QStringLiteral("https://") + path.mid(7)));
            return;
        }
        // AMP subdomain: amp.example.com → example.com
        if (host.startsWith(QLatin1String("amp."))) {
            QUrl canonical = url;
            canonical.setHost(host.mid(4));
            info.redirect(canonical);
            return;
        }
    }

    if (m_httpsOnly && url.scheme() == QLatin1String("http")) {
        url.setScheme(QStringLiteral("https"));
        info.redirect(url);
        return;
    }

    if (m_stripTrackingParams && url.hasQuery()) {
        QUrlQuery query(url);
        bool changed = false;
        for (const QString &param : TRACKING_PARAMS) {
            if (query.hasQueryItem(param)) {
                query.removeQueryItem(param);
                changed = true;
            }
        }
        if (changed) {
            url.setQuery(query);
            info.redirect(url);
            return;
        }
    }

    if (m_adBlockEnabled) {
        QString h = url.host().toLower();
        while (!h.isEmpty()) {
            if (m_blockedHosts.contains(h)) {
                info.block(true);
                return;
            }
            const int dot = h.indexOf(QLatin1Char('.'));
            if (dot < 0)
                break;
            h = h.mid(dot + 1);
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

bool RequestInterceptor::httpsOnly() const { return m_httpsOnly; }

void RequestInterceptor::setHttpsOnly(bool enabled)
{
    if (m_httpsOnly == enabled) return;
    m_httpsOnly = enabled;
    Q_EMIT httpsOnlyChanged();
}

bool RequestInterceptor::stripTrackingParams() const { return m_stripTrackingParams; }

void RequestInterceptor::setStripTrackingParams(bool enabled)
{
    if (m_stripTrackingParams == enabled) return;
    m_stripTrackingParams = enabled;
    Q_EMIT stripTrackingParamsChanged();
}

bool RequestInterceptor::globalPrivacyControl() const { return m_globalPrivacyControl; }

void RequestInterceptor::setGlobalPrivacyControl(bool enabled)
{
    if (m_globalPrivacyControl == enabled) return;
    m_globalPrivacyControl = enabled;
    Q_EMIT globalPrivacyControlChanged();
}

bool RequestInterceptor::blockAmpLinks() const { return m_blockAmpLinks; }

void RequestInterceptor::setBlockAmpLinks(bool enabled)
{
    if (m_blockAmpLinks == enabled) return;
    m_blockAmpLinks = enabled;
    Q_EMIT blockAmpLinksChanged();
}

static void loadHostsFile(const QString &path, QSet<QString> &out)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream in(&file);
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        // Support both "domain.com" and hosts-file "0.0.0.0 domain.com"
        const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        out.insert((parts.size() >= 2 ? parts.at(1) : parts.at(0)).toLower());
    }
}

void RequestInterceptor::loadBlockList()
{
    m_blockedHosts.clear();

    // User-supplied list takes precedence over the built-in resource.
    const QString userList = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
                             + QStringLiteral("/blocklist.txt");
    if (QFile::exists(userList)) {
        loadHostsFile(userList, m_blockedHosts);
        qInfo() << "RequestInterceptor: loaded" << m_blockedHosts.size()
                << "blocked hosts from" << userList;
        return;
    }

    // Fall back to the comprehensive list embedded in the application bundle.
    loadHostsFile(QStringLiteral(":/blocklist.txt"), m_blockedHosts);
    qInfo() << "RequestInterceptor: loaded" << m_blockedHosts.size()
            << "blocked hosts from built-in list";
}
