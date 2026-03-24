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
    Q_PROPERTY(bool stripTrackingParams READ stripTrackingParams WRITE setStripTrackingParams NOTIFY stripTrackingParamsChanged)
    Q_PROPERTY(bool globalPrivacyControl READ globalPrivacyControl WRITE setGlobalPrivacyControl NOTIFY globalPrivacyControlChanged)
    Q_PROPERTY(bool blockAmpLinks READ blockAmpLinks WRITE setBlockAmpLinks NOTIFY blockAmpLinksChanged)

public:
    explicit RequestInterceptor(QObject *parent = nullptr);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

    bool doNotTrack() const;
    void setDoNotTrack(bool enabled);

    bool adBlockEnabled() const;
    void setAdBlockEnabled(bool enabled);

    bool httpsOnly() const;
    void setHttpsOnly(bool enabled);

    bool stripTrackingParams() const;
    void setStripTrackingParams(bool enabled);

    bool globalPrivacyControl() const;
    void setGlobalPrivacyControl(bool enabled);

    bool blockAmpLinks() const;
    void setBlockAmpLinks(bool enabled);

Q_SIGNALS:
    void doNotTrackChanged();
    void adBlockEnabledChanged();
    void httpsOnlyChanged();
    void stripTrackingParamsChanged();
    void globalPrivacyControlChanged();
    void blockAmpLinksChanged();

private:
    void loadBlockList();

    bool m_doNotTrack = false;
    bool m_adBlockEnabled = false;
    bool m_httpsOnly = false;
    bool m_stripTrackingParams = false;
    bool m_globalPrivacyControl = false;
    bool m_blockAmpLinks = false;
    QSet<QString> m_blockedHosts;
};
