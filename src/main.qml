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

    readonly property var views : ({browser: 0, tabs: 1, history: 2})

    readonly property alias currentBrowser : _appView.currentBrowser
    readonly property alias browserView : _appView.browserView

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
        property bool javascriptCanAccessClipboard : true
        property bool javascriptCanOpenWindows : true
        property bool javascriptEnabled : true
        property bool localStorageEnabled : true
        property bool pdfViewerEnabled : true
        property bool playbackRequiresUserGesture : true
        property bool screenCaptureEnabled : true
        property bool showScrollBars : true
        property bool webGLEnabled : true
        property bool webRTCPublicInterfacesOnly : false

        property string downloadsPath : root.profile.downloadPath

        property bool restoreSession: true
        property bool switchToTab: false
        property double zoomFactor: 1.0

        property bool autoSave: false

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

    Action
    {
        id: _openDownloadAction
        property url url
        text: i18n("Open")
        onTriggered: ()=> { Qt.openUrlExternally(url)}
    }

    Action
    {
        id: _acceptDownloadAction
        property var download
        text: i18n("Accept")
        onTriggered: () =>{ _acceptDownloadAction.download.resume() }

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

        //        onPresentNotification:
        //        {
        //            root.notify("dialog-question", notification.title, notification.message,  () =>{ notification.click() }, i18n("Accept"))
        //            notification.show()
        //        }
    }

    Connections
    {
        target: Fiery.DownloadsManager
        function onNewDownload(download)
        {
            _acceptDownloadAction.download = download
            root.notify("dialog-question", download.downloadFileName, i18n("Do you want to download and save this file?"), [_acceptDownloadAction])
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

        property WebEngineView webView: _delegate.currentBrowser
        readonly property alias appView : _delegate

        AppView
        {
            id: _delegate
            anchors.fill: parent
        }
    }

    //The urls represent the split view, so it might be one or two.
    function newWindow(urls)
    {
        console.log("GOT", urls, urls[0])
        var newWindow = windowComponent.createObject(root)
        newWindow.webView.url = urls[0]

        if(urls[1])
        {
            newWindow.appView.browserView.openSplit(urls[1])
        }
    }
}
