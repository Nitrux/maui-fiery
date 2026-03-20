#pragma once

#include <QObject>
#include <QSet>
#include <QWebEngineUrlRequestInterceptor>

class RequestInterceptor : public QWebEngineUrlRequestInterceptor
{
    Q_OBJECT
    Q_PROPERTY(bool doNotTrack READ doNotTrack WRITE setDoNotTrack NOTIFY doNotTrackChanged)
    Q_PROPERTY(bool adBlockEnabled READ adBlockEnabled WRITE setAdBlockEnabled NOTIFY adBlockEnabledChanged)
    Q_PROPERTY(bool httpsOnly READ httpsOnly WRITE setHttpsOnly NOTIFY httpsOnlyChanged)

public:
    explicit RequestInterceptor(QObject *parent = nullptr);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

    bool doNotTrack() const;
    void setDoNotTrack(bool enabled);

    bool adBlockEnabled() const;
    void setAdBlockEnabled(bool enabled);

    bool httpsOnly() const;
    void setHttpsOnly(bool enabled);

Q_SIGNALS:
    void doNotTrackChanged();
    void adBlockEnabledChanged();
    void httpsOnlyChanged();

private:
    void loadBlockList();

    bool m_doNotTrack = false;
    bool m_adBlockEnabled = false;
    bool m_httpsOnly = false;
    QSet<QString> m_blockedHosts;
};
