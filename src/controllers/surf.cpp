#include "surf.h"

surf::surf(QObject *parent) : QObject(parent)
{

}

QUrl surf::formatUrl(const QUrl &url)
{
    return QUrl::fromUserInput(url.toString());
}

bool surf::isValidUrl(const QString &input)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty())
        return false;
    // A string with spaces cannot be a URL.
    if (trimmed.contains(QLatin1Char(' ')))
        return false;
    // If the user typed an explicit scheme (http://, https://, ftp://, …) treat
    // it as a URL unconditionally.  scheme().length() > 1 excludes Windows
    // drive letters (single character) from being mistaken for a scheme.
    if (QUrl(trimmed).scheme().length() > 1)
        return true;
    // A bare word without a dot is almost certainly a search term, not a
    // hostname.  Real public hostnames always contain at least one dot.
    // Allow "localhost" as the only dotless exception.
    const QUrl url = QUrl::fromUserInput(trimmed);
    if (!url.isValid() || url.host().isEmpty())
        return false;

    const QString host = url.host();

    // Public hostnames always contain a dot; localhost is the lone exception.
    if (host.contains(QLatin1Char('.')) || host == QLatin1String("localhost"))
        return true;

    // Bare local-network hostnames (e.g. "pihole", "nas", "myrouter") look
    // identical to single-word search terms, so we require an additional
    // signal before treating them as URLs:
    //   • a trailing slash:   "pihole/"     — unambiguous URL intent
    //   • a non-root path:    "nas/admin"   — contains a URL path component
    //   • an explicit port:   "myrouter:8080" — host:port notation
    if (trimmed.endsWith(QLatin1Char('/')))
        return true;

    const QString path = url.path();
    if (!path.isEmpty() && path != QLatin1String("/"))
        return true;

    if (url.port() != -1)
        return true;

    return false;
}

bool surf::hasProtocol(const QString &input)
{
    return input.startsWith(QLatin1String("http://"),  Qt::CaseInsensitive)
        || input.startsWith(QLatin1String("https://"), Qt::CaseInsensitive);
}
