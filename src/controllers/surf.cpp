#include "surf.h"

#include <KFormat>
#include <QAbstractSocket>
#include <QCryptographicHash>
#include <QGuiApplication>
#include <QNetworkCookie>
#include <QQuickWebEngineProfile>
#include <QSslCertificate>
#include <QSslError>
#include <QSslSocket>
#include <QTimer>
#include <QWebEngineCookieStore>

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

QString surf::safeDisplayUrl(const QString &urlStr)
{
    // Fast path: if the entire URL string contains only ASCII characters there
    // can be no IDN homograph attack — skip QUrl construction entirely and
    // return the input as-is.  The vast majority of links on English-language
    // pages take this path, avoiding a QUrl parse + toString per hover event.
    bool hasNonAscii = false;
    for (const QChar &c : urlStr) {
        if (c.unicode() > 127) {
            hasNonAscii = true;
            break;
        }
    }
    if (!hasNonAscii)
        return urlStr;

    // Slow path: non-ASCII present — check if the hostname specifically is the
    // culprit and convert it to Punycode so the spoofed characters are visible.
    QUrl url(urlStr);
    const QString host = url.host();

    bool hostHasNonAscii = false;
    for (const QChar &c : host) {
        if (c.unicode() > 127) {
            hostHasNonAscii = true;
            break;
        }
    }

    if (hostHasNonAscii) {
        const QByteArray ace = QUrl::toAce(host);
        if (!ace.isEmpty())
            url.setHost(QString::fromLatin1(ace));
    }

    return url.toString();
}

bool surf::isDangerousFile(const QString &path)
{
    static const QLatin1StringView extensions[] = {
        // Shell / scripting
        QLatin1StringView(".sh"),      QLatin1StringView(".bash"),
        QLatin1StringView(".zsh"),     QLatin1StringView(".fish"),
        QLatin1StringView(".ksh"),     QLatin1StringView(".csh"),
        QLatin1StringView(".command"),
        // Interpreted languages
        QLatin1StringView(".py"),      QLatin1StringView(".pl"),
        QLatin1StringView(".rb"),      QLatin1StringView(".lua"),
        QLatin1StringView(".tcl"),     QLatin1StringView(".php"),
        // JVM / managed runtimes
        QLatin1StringView(".jar"),     QLatin1StringView(".class"),
        // Native executables / libraries
        QLatin1StringView(".exe"),     QLatin1StringView(".dll"),
        QLatin1StringView(".so"),      QLatin1StringView(".bin"),
        QLatin1StringView(".run"),
        // Linux packaging / desktop integration
        QLatin1StringView(".appimage"),QLatin1StringView(".deb"),
        QLatin1StringView(".rpm"),
        // Desktop entry (can exec arbitrary commands)
        QLatin1StringView(".desktop"),
        // Windows packaging
        QLatin1StringView(".msi"),     QLatin1StringView(".bat"),
        QLatin1StringView(".cmd"),     QLatin1StringView(".ps1"),
        QLatin1StringView(".vbs"),     QLatin1StringView(".wsf"),
        // macOS
        QLatin1StringView(".pkg"),     QLatin1StringView(".dmg"),
    };
    // toLower() is called once here; all extension literals above are already
    // lowercase so the comparison is inherently case-insensitive.
    const QString lower = path.toLower();
    for (const auto &ext : extensions)
        if (lower.endsWith(ext))
            return true;
    return false;
}

bool surf::certificateLoading() const
{
    return m_certificateLoading;
}

bool surf::certificateAvailable() const
{
    return m_certificateAvailable;
}

bool surf::certificateValid() const
{
    return m_certificateAvailable && m_certificateError.isEmpty();
}

QString surf::certificateSubject() const
{
    return m_certificateSubject;
}

QString surf::certificateIssuer() const
{
    return m_certificateIssuer;
}

QString surf::certificateSerialNumber() const
{
    return m_certificateSerialNumber;
}

QString surf::certificateEffectiveDate() const
{
    return m_certificateEffectiveDate;
}

QString surf::certificateExpiryDate() const
{
    return m_certificateExpiryDate;
}

QString surf::certificateFingerprint() const
{
    return m_certificateFingerprint;
}

QString surf::certificateError() const
{
    return m_certificateError;
}

void surf::publishCertificate(const QSslCertificate &certificate, const QString &error)
{
    m_certificateLoading = false;
    m_certificateAvailable = !certificate.isNull();
    m_certificateError = error;

    if (certificate.isNull()) {
        m_certificateSubject.clear();
        m_certificateIssuer.clear();
        m_certificateSerialNumber.clear();
        m_certificateEffectiveDate.clear();
        m_certificateExpiryDate.clear();
        m_certificateFingerprint.clear();
    } else {
        m_certificateSubject = certificate.subjectInfo(QSslCertificate::CommonName).value(0);
        if (m_certificateSubject.isEmpty())
            m_certificateSubject = certificate.subjectInfo(QSslCertificate::Organization).value(0);
        m_certificateIssuer = certificate.issuerInfo(QSslCertificate::CommonName).value(0);
        if (m_certificateIssuer.isEmpty())
            m_certificateIssuer = certificate.issuerInfo(QSslCertificate::Organization).value(0);
        m_certificateSerialNumber = QString::fromLatin1(certificate.serialNumber());
        m_certificateEffectiveDate = certificate.effectiveDate().toString(Qt::ISODate);
        m_certificateExpiryDate = certificate.expiryDate().toString(Qt::ISODate);
        m_certificateFingerprint = QString::fromLatin1(certificate.digest(QCryptographicHash::Sha256).toHex().toUpper());
    }

    Q_EMIT certificateChanged();
}

void surf::inspectCertificate(const QUrl &url)
{
    if (m_certificateSocket) {
        m_certificateSocket->abort();
        m_certificateSocket->deleteLater();
        m_certificateSocket.clear();
    }

    m_certificateLoading = false;
    m_certificateAvailable = false;
    m_certificateSubject.clear();
    m_certificateIssuer.clear();
    m_certificateSerialNumber.clear();
    m_certificateEffectiveDate.clear();
    m_certificateExpiryDate.clear();
    m_certificateFingerprint.clear();
    m_certificateError.clear();

    if (url.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) != 0) {
        m_certificateError = QStringLiteral("The current page does not use HTTPS.");
        Q_EMIT certificateChanged();
        return;
    }

    m_certificateLoading = true;
    Q_EMIT certificateChanged();

    auto *socket = new QSslSocket(this);
    socket->setPeerVerifyMode(QSslSocket::VerifyPeer);
    m_certificateSocket = socket;

    connect(socket, &QSslSocket::encrypted, this, [this, socket]() {
        if (m_certificateSocket != socket)
            return;

        publishCertificate(socket->peerCertificate());
        m_certificateSocket.clear();
        socket->deleteLater();
    });

    connect(socket, &QSslSocket::sslErrors, this, [this, socket](const QList<QSslError> &errors) {
        if (m_certificateSocket != socket)
            return;

        const QString error = errors.isEmpty()
                                  ? QStringLiteral("The TLS certificate could not be verified.")
                                  : errors.first().errorString();
        publishCertificate(socket->peerCertificate(), error);
        m_certificateSocket.clear();
        socket->abort();
        socket->deleteLater();
    });

    connect(socket, &QSslSocket::errorOccurred, this, [this, socket](QAbstractSocket::SocketError) {
        if (m_certificateSocket != socket)
            return;

        const QString error = socket->errorString().isEmpty()
                                   ? QStringLiteral("The TLS connection could not be verified.")
                                   : socket->errorString();
        publishCertificate(socket->peerCertificate(), error);
        m_certificateSocket.clear();
        socket->deleteLater();
    });

    socket->connectToHostEncrypted(url.host(), url.port(443), url.host());
}

void surf::clearSiteCookies(QQuickWebEngineProfile *profile, const QUrl &origin)
{
    if (!profile || origin.host().isEmpty())
        return;

    auto *store = profile->cookieStore();
    if (!store)
        return;

    QObject::disconnect(m_cookieConnection);

    const QString host = origin.host().toLower();
    m_cookieConnection = connect(store, &QWebEngineCookieStore::cookieAdded, this,
                                  [this, store, host, origin](const QNetworkCookie &cookie) {
        QString domain = cookie.domain().toLower();
        while (domain.startsWith(QLatin1Char(46)))
            domain.remove(0, 1);
        if (domain.isEmpty())
            domain = host;

        if (!domain.isEmpty() && (host == domain || host.endsWith(QLatin1Char(46) + domain)))
            store->deleteCookie(cookie, origin);
    });

    store->loadAllCookies();

    QTimer::singleShot(1000, this, [this]() {
        QObject::disconnect(m_cookieConnection);
        m_cookieConnection = QMetaObject::Connection();
    });
}

QString surf::formatBytes(qint64 bytes)
{
    if (bytes < 0)
        return QStringLiteral("?");
    return KFormat().formatByteSize(bytes);
}

bool surf::hasProtocol(const QString &input)
{
    // scheme().length() > 1 reuses the same guard as isValidUrl: it accepts any
    // explicit URI scheme (http, https, ftp, file, about, data, …) while
    // excluding single-letter Windows drive letters.
    return QUrl(input).scheme().length() > 1;
}

bool surf::isX11OnWayland()
{
    const QString platformName = QGuiApplication::platformName().toLower();
    const bool isX11Platform = platformName.contains(QStringLiteral("xcb"));

    const QByteArray sessionType = qgetenv("XDG_SESSION_TYPE").trimmed().toLower();
    const bool isWaylandSession = qEnvironmentVariableIsSet("WAYLAND_DISPLAY")
                                  || sessionType == "wayland";

    return isX11Platform && isWaylandSession;
}
