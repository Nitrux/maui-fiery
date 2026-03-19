#include "requestinterceptor.h"

#include <QWebEngineUrlRequestInfo>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QDebug>

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
    if (m_doNotTrack)
        info.setHttpHeader("DNT", "1");

    if (m_adBlockEnabled) {
        // Walk from the full hostname up to the registrable domain, performing
        // an O(1) QSet lookup at each level.  This supports both exact matches
        // ("ads.example.com") and wildcard subdomain blocking ("example.com")
        // without an O(N) loop over the entire block list.
        QString h = info.requestUrl().host();
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
        out.insert(parts.size() >= 2 ? parts.at(1) : parts.at(0));
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
