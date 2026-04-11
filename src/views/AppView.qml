import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

import "browser"
import "widgets"
import "history"
import "home"

Maui.SideBarView
{
    id: _sideBarView
    background: null

    readonly property alias currentBrowser : _browserView.currentBrowser
    readonly property alias browserView : _browserView
    property alias privateMode: _browserView.privateMode

    sideBar.autoShow: false
    sideBar.autoHide: true
    // Scale with the window up to a comfortable maximum so long filenames
    // are not clipped; on narrow/portrait layouts give it most of the width.
    sideBar.preferredWidth: Math.min(root.width * (root.isWide ? 0.38 : 0.88), 520)

    sideBar.content: Maui.Page
    {
        anchors.fill: parent
        background: null
        headerMargins: Maui.Style.contentMargins
        Maui.Theme.colorSet: Maui.Theme.Window
        Maui.Theme.inherit: false

        headBar.middleContent: Maui.ToolActions
        {
            id: _sidebarActions
            autoExclusive: true

            display: ToolButton.IconOnly
            Layout.alignment: Qt.AlignHCenter

            Action
            {
                text: i18n("Bookmarks")
                icon.name: "bookmark-new"
                checked: _sidebarSwipeView.currentIndex === 0
                onTriggered: _sidebarSwipeView.currentIndex = 0
            }

            Action
            {
                text: i18n("Recent")
                icon.name: "view-calendar"
                checked: _sidebarSwipeView.currentIndex === 1
                onTriggered: _sidebarSwipeView.currentIndex = 1
            }

            Action
            {
                text: i18n("Downloads")
                icon.name: "folder-download"
                checked: _sidebarSwipeView.currentIndex === 2
                onTriggered: _sidebarSwipeView.currentIndex = 2
            }
        }

        SwipeView
        {
            anchors.fill: parent
            id: _sidebarSwipeView

            Loader
            {
                active: visible
                asynchronous: true
                sourceComponent: HomeView {}
            }

            Loader
            {
                active: visible
                asynchronous: true
                sourceComponent: HistoryView {}
            }


            Loader
            {
                active: visible
                asynchronous: true
                sourceComponent: Maui.Page
                {
                    headBar.rightContent: ToolButton
                    {
                        text: i18n("Clear Finished")
                        icon.name: "edit-clear"
                        onClicked: Fiery.DownloadsManager.clearFinished()
                    }

                    background: null

                    // Warn before handing executable file types to the OS handler.
                    Dialog
                    {
                        id: _execWarningDialog
                        property url pendingPath

                        title: i18n("Open Downloaded File?")
                        standardButtons: Dialog.Open | Dialog.Cancel

                        anchors.centerIn: parent

                        Label
                        {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: i18n("This file may be executable. Opening it could run code on your system. Are you sure you want to open it?")
                        }

                        onAccepted: Qt.openUrlExternally(pendingPath)
                    }

                    function openDownloadedFile(filePath)
                    {
                        if (filePath === undefined || filePath === null || filePath.toString().length === 0)
                            return

                        if (_surf.isDangerousFile(filePath.toString()))
                        {
                            _execWarningDialog.pendingPath = filePath
                            _execWarningDialog.open()
                        }
                        else
                            Qt.openUrlExternally(filePath)
                    }

                    // Shared context menu — populated with the tapped row's data
                    // before popup() is called, matching the pattern used in HomeView.
                    Maui.ContextualMenu
                    {
                        id: _downloadMenu

                        property int rowIndex: -1
                        property url currentFilePath: ""
                        property url currentUrl: ""
                        property int currentState: WebEngineDownloadRequest.DownloadRequested
                        property bool currentPaused: false
                        readonly property bool _hasFilePath: currentFilePath.toString().length > 0

                        readonly property bool _isActive: currentState === WebEngineDownloadRequest.DownloadInProgress
                            && currentPaused === false
                        readonly property bool _isPaused: currentState === WebEngineDownloadRequest.DownloadInProgress
                            && currentPaused
                        readonly property bool _isInterrupted: currentState === WebEngineDownloadRequest.DownloadInterrupted

                        MenuItem
                        {
                            text: i18n("Open")
                            icon.name: "document-open"
                            enabled: _downloadMenu._hasFilePath
                                     && _downloadMenu.currentState === WebEngineDownloadRequest.DownloadCompleted
                            onTriggered: openDownloadedFile(_downloadMenu.currentFilePath)
                        }

                        MenuItem
                        {
                            text: _downloadMenu._isPaused ? i18n("Resume") : i18n("Pause")
                            icon.name: _downloadMenu._isPaused ? "media-playback-start" : "media-playback-pause"
                            enabled: _downloadMenu._isActive || _downloadMenu._isPaused
                            onTriggered:
                            {
                                if (_downloadMenu._isPaused)
                                    Fiery.DownloadsManager.resume(_downloadMenu.rowIndex)
                                else
                                    Fiery.DownloadsManager.pause(_downloadMenu.rowIndex)
                            }
                        }

                        MenuItem
                        {
                            text: i18n("Retry")
                            icon.name: "view-refresh"
                            visible: _downloadMenu._isInterrupted
                            height: visible ? implicitHeight : 0
                            onTriggered: Fiery.DownloadsManager.resume(_downloadMenu.rowIndex)
                        }

                        MenuItem
                        {
                            text: i18n("Copy Download URL")
                            icon.name: "edit-copy"
                            enabled: _downloadMenu.currentUrl.toString().length > 0
                            onTriggered: Maui.Handy.copyTextToClipboard(_downloadMenu.currentUrl.toString())
                        }

                        MenuSeparator {}

                        MenuItem
                        {
                            text: i18n("Remove from Downloads")
                            icon.name: "list-remove"
                            onTriggered: Fiery.DownloadsManager.remove(_downloadMenu.rowIndex)
                        }

                        MenuItem
                        {
                            text: i18n("Delete File")
                            icon.name: "edit-delete"
                            onTriggered: Fiery.DownloadsManager.removeAndDeleteFile(_downloadMenu.rowIndex)
                        }
                    }

                    Maui.ListBrowser
                    {
                        anchors.fill: parent
                        spacing: Maui.Style.space.medium
                        model: Fiery.DownloadsManager.model

                        holder.title: i18n("Downloads")
                        holder.body: i18n("Your downloads will be listed in here.")
                        holder.emoji: "download"
                        holder.visible: count === 0

                        delegate: Item
                        {
                            id: _dlItem

                            width: ListView.view.width
                            height: _del.implicitHeight + (_dlItem._inProgress || _dlItem._isPaused || _dlItem._isInterrupted ? 6 + Maui.Style.space.small * 2 : 0)

                            readonly property url _url: model.url
                            readonly property int _state: model.state
                            readonly property real _receivedBytes: model.receivedBytes
                            readonly property real _totalBytes: model.totalBytes
                            readonly property bool _paused: model.isPaused
                            readonly property var _filePath: model.filePath ? model.filePath : ""
                            readonly property bool _hasFilePath: _filePath.toString().length > 0
                            readonly property bool _inProgress: _state === WebEngineDownloadRequest.DownloadInProgress
                                && _paused === false
                            readonly property bool _isPaused: _state === WebEngineDownloadRequest.DownloadInProgress
                                && _paused
                            readonly property bool _isInterrupted: _state === WebEngineDownloadRequest.DownloadInterrupted

                            property real _speedBps: 0
                            property real _lastBytes: 0
                            property real _lastTime:  0

                            Timer
                            {
                                interval: 1000
                                running:  _dlItem._inProgress
                                repeat:   true

                                onTriggered:
                                {
                                    var now   = Date.now()
                                    var bytes = _dlItem._receivedBytes
                                    var secs  = _dlItem._lastTime > 0 ? (now - _dlItem._lastTime) / 1000 : 1
                                    _dlItem._speedBps  = secs > 0 ? (bytes - _dlItem._lastBytes) / secs : 0
                                    _dlItem._lastBytes = bytes
                                    _dlItem._lastTime  = now
                                }

                                Component.onCompleted:
                                {
                                    _dlItem._lastBytes = _dlItem._receivedBytes
                                    _dlItem._lastTime  = Date.now()
                                }
                            }

                            Maui.ListBrowserDelegate
                            {
                                id: _del
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right

                                label1.text: model.name
                                label1.elide: Text.ElideMiddle

                                Binding
                                {
                                    target: _del.label2
                                    property: "elide"
                                    value: Text.ElideRight
                                    restoreMode: Binding.RestoreNone
                                }

                                label2.text:
                                {
                                    if (_dlItem._inProgress || _dlItem._isPaused || _dlItem._isInterrupted)
                                    {
                                        var host = ""
                                        try { host = new URL(_dlItem._url.toString()).hostname } catch(e) {}
                                        var sizeStr = _surf.formatBytes(_dlItem._receivedBytes) + " / " + _surf.formatBytes(_dlItem._totalBytes)
                                        var suffix
                                        if (_dlItem._isInterrupted)
                                            suffix = i18n("Interrupted")
                                        else if (_dlItem._isPaused)
                                            suffix = i18n("Paused")
                                        else
                                            suffix = _dlItem._speedBps > 0 ? _surf.formatBytes(_dlItem._speedBps) + "/s" : "--.-- /s"
                                        return host + "\n" + sizeStr + (suffix.length > 0 ? "\n" + suffix : "")
                                    }
                                    return model.url.toString()
                                }

                                iconSource: _dlItem._state === WebEngineDownloadRequest.DownloadCompleted && _dlItem._hasFilePath
                                            ? _dlItem._filePath
                                            : model.icon

                                onClicked:
                                {
                                    if (_dlItem._state === WebEngineDownloadRequest.DownloadCompleted && _dlItem._hasFilePath)
                                        openDownloadedFile(_dlItem._filePath)
                                }

                                onRightClicked:
                                {
                                    _downloadMenu.rowIndex = index
                                    _downloadMenu.currentFilePath = _dlItem._filePath
                                    _downloadMenu.currentUrl = _dlItem._url
                                    _downloadMenu.currentState = _dlItem._state
                                    _downloadMenu.currentPaused = _dlItem._paused
                                    _downloadMenu.popup()
                                }

                                onPressAndHold:
                                {
                                    _downloadMenu.rowIndex = index
                                    _downloadMenu.currentFilePath = _dlItem._filePath
                                    _downloadMenu.currentUrl = _dlItem._url
                                    _downloadMenu.currentState = _dlItem._state
                                    _downloadMenu.currentPaused = _dlItem._paused
                                    _downloadMenu.popup()
                                }
                            }

                            // Progress bar with background track and fill.
                            // Indeterminate (no Content-Length): animated sliding
                            // block. Determinate: fill proportional to bytes received.
                            // Frozen at current position when paused.
                            Rectangle
                            {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Maui.Style.space.small

                                visible: _dlItem._inProgress || _dlItem._isPaused || _dlItem._isInterrupted
                                height: 6
                                radius: height / 2
                                color: Maui.Theme.alternateBackgroundColor
                                border.color: Maui.Theme.separatorColor
                                border.width: 1

                                clip: true

                                Rectangle
                                {
                                    id: _progressFill

                                    readonly property bool _indeterminate: _dlItem._inProgress && _dlItem._totalBytes <= 0
                                    readonly property real _ratio: _dlItem._totalBytes > 0
                                                                   ? _dlItem._receivedBytes / _dlItem._totalBytes
                                                                   : 0

                                    height: parent.height
                                    radius: parent.radius
                                    color: _dlItem._isInterrupted
                                           ? Maui.Theme.negativeTextColor
                                           : _dlItem._isPaused
                                             ? Maui.Theme.disabledTextColor
                                             : Maui.Theme.highlightColor

                                    width: _indeterminate ? parent.width * 0.25 : parent.width * _ratio

                                    SequentialAnimation on x
                                    {
                                        loops: Animation.Infinite
                                        running: _progressFill._indeterminate

                                        NumberAnimation
                                        {
                                            from: 0
                                            to: _progressFill.parent.width - _progressFill.width
                                            duration: 900
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation
                                        {
                                            from: _progressFill.parent.width - _progressFill.width
                                            to: 0
                                            duration: 900
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    BrowserView
    {
        id: _browserView
        anchors.fill: parent
    }

    function openHistory()
    {
        _sideBarView.sideBar.open()
        _sidebarSwipeView.setCurrentIndex(1)
    }

    function openBookmarks()
    {
        _sideBarView.sideBar.open()
        _sidebarSwipeView.setCurrentIndex(0)
    }

    function openDownloads()
    {
        _sideBarView.sideBar.open()
        _sidebarSwipeView.setCurrentIndex(2)
    }
}


