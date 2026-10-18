#pragma once
#include <QMetaObject>
#include <QObject>
#include <QPointer>
#include <QQuickWebEngineProfile>
#include <QUrl>

class QSslCertificate;
class QSslSocket;

class surf : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool certificateLoading READ certificateLoading NOTIFY certificateChanged)
    Q_PROPERTY(bool certificateAvailable READ certificateAvailable NOTIFY certificateChanged)
    Q_PROPERTY(bool certificateValid READ certificateValid NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateSubject READ certificateSubject NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateIssuer READ certificateIssuer NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateSerialNumber READ certificateSerialNumber NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateEffectiveDate READ certificateEffectiveDate NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateExpiryDate READ certificateExpiryDate NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateFingerprint READ certificateFingerprint NOTIFY certificateChanged)
    Q_PROPERTY(QString certificateError READ certificateError NOTIFY certificateChanged)
public:
    explicit surf(QObject *parent = nullptr);

    bool certificateLoading() const;
    bool certificateAvailable() const;
    bool certificateValid() const;
    QString certificateSubject() const;
    QString certificateIssuer() const;
    QString certificateSerialNumber() const;
    QString certificateEffectiveDate() const;
    QString certificateExpiryDate() const;
    QString certificateFingerprint() const;
    QString certificateError() const;

public Q_SLOTS:
    static QUrl formatUrl(const QUrl &url);
    static bool isValidUrl(const QString &input);
    static bool hasProtocol(const QString &input);
    static QString safeDisplayUrl(const QString &urlStr);
    static bool isDangerousFile(const QString &path);
    Q_INVOKABLE static QString formatBytes(qint64 bytes);
    Q_INVOKABLE static bool isX11OnWayland();
    Q_INVOKABLE void inspectCertificate(const QUrl &url);
    Q_INVOKABLE void clearSiteCookies(QQuickWebEngineProfile *profile, const QUrl &origin);

Q_SIGNALS:
    void certificateChanged();

private:
    void publishCertificate(const QSslCertificate &certificate, const QString &error = QString());

    bool m_certificateLoading = false;
    bool m_certificateAvailable = false;
    QString m_certificateSubject;
    QString m_certificateIssuer;
    QString m_certificateSerialNumber;
    QString m_certificateEffectiveDate;
    QString m_certificateExpiryDate;
    QString m_certificateFingerprint;
    QString m_certificateError;
    QPointer<QSslSocket> m_certificateSocket;
    QMetaObject::Connection m_cookieConnection;
};
