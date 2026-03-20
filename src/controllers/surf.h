#pragma once
#include <QObject>
#include <QUrl>

class surf : public QObject
{
    Q_OBJECT
public:
    explicit surf(QObject *parent = nullptr);

public Q_SLOTS:
    static QUrl formatUrl(const QUrl &url);
    static bool isValidUrl(const QString &input);
    static bool hasProtocol(const QString &input);
    static QString safeDisplayUrl(const QString &urlStr);
    static bool isDangerousFile(const QString &path);
    Q_INVOKABLE static QString formatBytes(qint64 bytes);

};
