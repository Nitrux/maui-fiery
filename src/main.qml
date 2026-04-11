import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import QtCore

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

import "views"
import "views/widgets"
import "views/browser"

Maui.ApplicationWindow
{
    id: root
    title: browserView.currentTab ? browserView.currentTab.title : "Fiery"

    color: "transparent"
    background: null

    Maui.WindowBlur
    {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    Rectangle
    {
        anchors.fill: parent
        color: Maui.Theme.backgroundColor
        opacity: 0.76
        radius: Maui.Style.radiusV
        border.color: Qt.rgba(1, 1, 1, 0)
        border.width: 1
    }

    readonly property var views : ({browser: 0, tabs: 1, history: 2})

    readonly property alias currentBrowser : _appView.currentBrowser
    readonly property alias browserView : _appView.browserView

    onClosing: (close) =>
    {
        if (appSettings.restoreSession)
            appSettings.sessionUrlsJson = JSON.stringify(browserView.collectSessionUrls())
    }

    Settings
    {
        id: appSettings
        category: "Browser"

        property url homePage: "https://duckduckgo.com"
        property url searchEnginePage: "https://duckduckgo.com/?q="
        property color backgroundColor : root.Maui.Theme.backgroundColor

        property bool autoLoadIconsForPage : true
        property bool autoLoadImages : true
        property bool dnsPrefetchEnabled : false
        property bool errorPageEnabled : true
        property bool fullScreenSupportEnabled : false
        property bool javascriptCanAccessClipboard : false
        property bool javascriptCanOpenWindows : true
        property bool javascriptEnabled : true
        property bool localStorageEnabled : true
        property bool pdfViewerEnabled : true
        property bool playbackRequiresUserGesture : true
        property bool screenCaptureEnabled : true
        property bool showScrollBars : true
        property bool webGLEnabled : true
        property bool webRTCPublicInterfacesOnly : true

        property string downloadsPath : root.profile.downloadPath

        property bool forceDarkMode: false
        property bool restoreSession: true
        property bool switchToTab: false
        property double zoomFactor: 1.0

        property bool autoSave: false

        // Serialised JSON array of URLs from the last session, used when
        // restoreSession is true.  Written on window close; read on startup.
        property string sessionUrlsJson: ""

        // Permissions — global allow/deny for each browser capability request.
        // When disabled the permission is silently denied without prompting the user.
        property bool allowNotifications:   false
        property bool allowGeolocation:     false
        property bool allowMicrophone:      false
        property bool allowCamera:          false
        property bool allowDesktopCapture:  false
        property bool allowMouseLock:       false

        // Privacy
        property bool doNotTrack: false
        property bool adBlockEnabled: false
        property bool stripTrackingParams: false
        property bool globalPrivacyControl: false
        property bool blockAmpLinks: false
        property bool blockThirdPartyCookies: false
        // JSON array of hostnames exempt from third-party cookie blocking.
        // e.g. '["accounts.google.com","auth0.com"]'
        property string thirdPartyCookiesWhitelistJson: "[]"
        property bool cookieBannerBlocker: false
        property bool subscribeBlockerEnabled: false
        property bool adblockDetectionBlockerEnabled: false
        property string customUserAgent: ""

        // Security
        property bool httpsOnly: false

        // DNS-over-HTTPS (applied at startup via Chromium flags — requires restart)
        property bool dohEnabled: false
        property string dohUrl: "https://cloudflare-dns.com/dns-query"

        property bool widevineEnabled: false

        // Tab sleep — discard background tabs after tabSleepDelay minutes to free memory.
        property bool tabSleepEnabled: false
        property int  tabSleepDelay: 30
    }

    Fiery.RequestInterceptor
    {
        id: _requestInterceptor
        doNotTrack:          appSettings.doNotTrack
        adBlockEnabled:      appSettings.adBlockEnabled
        httpsOnly:           appSettings.httpsOnly
        stripTrackingParams: appSettings.stripTrackingParams
        globalPrivacyControl: appSettings.globalPrivacyControl
        blockAmpLinks:       appSettings.blockAmpLinks
    }

    Binding
    {
        target: root.profile
        property: "blockThirdPartyCookies"
        value: appSettings.blockThirdPartyCookies
    }

    Binding
    {
        target: root.profile
        property: "thirdPartyCookiesWhitelist"
        value:
        {
            try { return JSON.parse(appSettings.thirdPartyCookiesWhitelistJson) }
            catch(e) { return [] }
        }
    }

    Binding
    {
        target: root.profile
        property: "httpUserAgent"
        value: appSettings.customUserAgent
        when: appSettings.customUserAgent.length > 0
    }

    Fiery.Surf
    {
        id: _surf
    }

    SettingsDialog
    {
        id: _settingsDialog
    }

    WidevinePrompt
    {
        id: _startupWidevinePrompt
    }

    Component.onCompleted:
    {
        if (appSettings.widevineEnabled && !Fiery.WidevineInstaller.isInstalled)
            Qt.callLater(function() { _startupWidevinePrompt.open() })
    }

    AppView
    {
        id: _appView
        anchors.fill: parent
    }

    // Hidden WebEngineView used to re-request persisted download URLs after restart.
    WebEngineView
    {
        id: _downloadRetryView
        visible: false
        width: 0
        height: 0
        profile: root.profile
    }

    Action
    {
        id: _acceptDownloadAction
        property var download
        text: i18n("Accept")
        onTriggered: () => { _acceptDownloadAction.download.resume() }
    }

    Action
    {
        id: _cancelDownloadAction
        property var download
        text: i18n("Cancel")
        onTriggered: () => { Fiery.DownloadsManager.cancelDownload(_cancelDownloadAction.download) }
    }

    Action
    {
        id: _savePasswordAction
        property string host
        property string username
        property string password
        text: i18n("Save")
        onTriggered: () => { Fiery.PasswordManager.save(_savePasswordAction.host, _savePasswordAction.username, _savePasswordAction.password) }
    }

    Action
    {
        id: _dismissPasswordAction
        text: i18n("Not Now")
    }

    Connections
    {
        target: Fiery.PasswordManager
        function onSaveRequested(host, username, password)
        {
            _savePasswordAction.host     = host
            _savePasswordAction.username = username
            _savePasswordAction.password = password
            root.notify("dialog-password", i18n("Save Password?"),
                        i18n("Save credentials for %1?", host),
                        [_savePasswordAction, _dismissPasswordAction])
        }
    }

    property WebEngineProfile profile: Fiery.FieryWebProfile
    {
        downloadPath: appSettings.downloadsPath
        // Only register the interceptor when at least one feature needs it.
        // A registered interceptor adds an IPC round-trip for every network request
        // even when interceptRequest() returns immediately — suspending the request,
        // crossing to the browser process, and resuming it.  With all features off
        // (the default) the overhead is pure waste; setting null unregisters it entirely.
        urlInterceptor: (_requestInterceptor.doNotTrack
                         || _requestInterceptor.adBlockEnabled
                         || _requestInterceptor.httpsOnly
                         || _requestInterceptor.stripTrackingParams
                         || _requestInterceptor.globalPrivacyControl
                         || _requestInterceptor.blockAmpLinks)
                        ? _requestInterceptor : null

        onDownloadFinished: (download) =>
        {
            if (download.state === WebEngineDownloadRequest.DownloadCompleted)
                Fiery.DownloadsManager.notifyComplete(download.downloadFileName)
        }

    }

    Connections
    {
        target: Fiery.DownloadsManager

        function onNewDownload(download)
        {
            _acceptDownloadAction.download = download
            _cancelDownloadAction.download = download
            root.notify("dialog-question", download.downloadFileName, i18n("Do you want to download and save this file?"), [_acceptDownloadAction, _cancelDownloadAction])
        }

        function onRetryRequested(url)
        {
            if (!url || url.toString().length === 0)
                return

            _downloadRetryView.url = "about:blank"
            Qt.callLater(function() { _downloadRetryView.url = url })
        }
    }

    property Component windowComponent: Maui.BaseWindow
    {
        // Destroy on close to release the Window's QML resources.
        // Because it was created with a parent, it won't be garbage-collected.
        onClosing: destroy()

        visible: true

        // Set before the component completes so BrowserView.Component.onCompleted
        // sees the correct mode and never touches the persistent profile.
        property bool privateMode: false

        property WebEngineView webView: _delegate.currentBrowser
        readonly property alias appView : _delegate

        AppView
        {
            id: _delegate
            anchors.fill: parent
            privateMode: parent.privateMode
        }
    }

    // urls: array of 1 or 2 URLs (the second is the split-view partner).
    // incognito: when true the new window opens in private-browsing mode so the
    // detached URLs are never written to disk with the persistent profile.
    function newWindow(urls, incognito)
    {
        var win = windowComponent.createObject(root, { "privateMode": !!incognito })
        // privateMode is passed at construction time, so Component.onCompleted
        // in BrowserView opens the initial tab in the correct view (private or
        // not) from the start.  Simply navigate that tab to the requested URL.
        win.webView.url = urls[0]
        if (urls[1])
            win.appView.browserView.openSplit(urls[1])
    }
}
