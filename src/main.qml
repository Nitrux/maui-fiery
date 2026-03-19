import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import QtCore

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

import "views"
import "views/widgets"

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

        property bool allowRunningInsecureContent : false
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
        property bool cookieBannerBlocker: false
        property string customUserAgent: ""
    }

    Fiery.RequestInterceptor
    {
        id: _requestInterceptor
        doNotTrack: appSettings.doNotTrack
        adBlockEnabled: appSettings.adBlockEnabled
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

    AppView
    {
        id: _appView
        anchors.fill: parent
    }

    Dialog
    {
        id: _openDownloadDialog
        property url pendingUrl

        title: i18n("Open Downloaded File?")
        standardButtons: Dialog.Open | Dialog.Cancel
        anchors.centerIn: parent

        Label
        {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18n("This file may be executable. Opening it could run code on your system. Are you sure you want to open it?")
        }

        onAccepted: Qt.openUrlExternally(pendingUrl)
    }

    Action
    {
        id: _openDownloadAction
        property url url
        text: i18n("Open")
        onTriggered: () =>
        {
            var dangerous = [".sh", ".bash", ".zsh", ".desktop", ".AppImage",
                             ".run", ".bin", ".exe", ".py", ".pl", ".rb", ".command"]
            var path = url.toString().toLowerCase()
            if (dangerous.some(function(ext) { return path.endsWith(ext) }))
            {
                _openDownloadDialog.pendingUrl = url
                _openDownloadDialog.open()
            }
            else
                Qt.openUrlExternally(url)
        }
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

    property WebEngineProfile profile: Fiery.FieryWebProfile
    {
        downloadPath: appSettings.downloadsPath
        urlInterceptor: _requestInterceptor

        onDownloadFinished: (download) =>
        {
            switch(download.state)
            {
                case WebEngineDownloadRequest.DownloadCompleted:
            {
                _openDownloadAction.url = "file://"+download.downloadDirectory+"/"+download.downloadFileName
                notify("dialog-warning", i18n("Download Finished"), i18n("File has been saved."), [_openDownloadAction])
            }
            }
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
    }

    property Component windowComponent: Maui.BaseWindow
    {
        // Destroy on close to release the Window's QML resources.
        // Because it was created with a parent, it won't be garbage-collected.
        onClosing:
        {
            console.log("Closing new window")
            destroy()
        }

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

        if (incognito)
        {
            var bv = win.appView.browserView
            // Close the initial tab that Component.onCompleted opened with the
            // default (persistent) profile before we switch to private mode.
            if (bv.activeView.count > 0)
                bv.activeView.closeTab(0)
            bv.privateMode = true
            bv.openTab(urls[0])
            if (urls[1])
                bv.openSplit(urls[1])
        }
        else
        {
            win.webView.url = urls[0]
            if (urls[1])
                win.appView.browserView.openSplit(urls[1])
        }
    }
}
