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
                        property url currentFilePath
                        property var currentDownload: null

                        readonly property bool _isActive: currentDownload !== null
                            && currentDownload.state === WebEngineDownloadRequest.DownloadInProgress
                            && !currentDownload.isPaused
                        readonly property bool _isPaused: currentDownload !== null
                            && currentDownload.state === WebEngineDownloadRequest.DownloadInProgress
                            && currentDownload.isPaused

                        MenuItem
                        {
                            text: i18n("Open")
                            icon.name: "document-open"
                            enabled: _downloadMenu.currentDownload !== null
                                     && _downloadMenu.currentDownload.state === WebEngineDownloadRequest.DownloadCompleted
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
                                    _downloadMenu.currentDownload.resume()
                                else
                                    _downloadMenu.currentDownload.pause()
                            }
                        }

                        MenuItem
                        {
                            text: i18n("Copy Download URL")
                            icon.name: "edit-copy"
                            enabled: _downloadMenu.currentDownload !== null
                            onTriggered: Maui.Handy.copyTextToClipboard(_downloadMenu.currentDownload.url.toString())
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
                            height: _del.implicitHeight + (_dlItem._inProgress || _dlItem._isPaused ? 6 + Maui.Style.space.small * 2 : 0)

                            property var download: model.download
                            readonly property bool _inProgress: download.state === WebEngineDownloadRequest.DownloadInProgress && !download.isPaused
                            readonly property bool _isPaused:   download.state === WebEngineDownloadRequest.DownloadInProgress && download.isPaused

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
                                    var bytes = _dlItem.download.receivedBytes
                                    var secs  = _dlItem._lastTime > 0 ? (now - _dlItem._lastTime) / 1000 : 1
                                    _dlItem._speedBps  = secs > 0 ? (bytes - _dlItem._lastBytes) / secs : 0
                                    _dlItem._lastBytes = bytes
                                    _dlItem._lastTime  = now
                                }

                                Component.onCompleted:
                                {
                                    _dlItem._lastBytes = _dlItem.download.receivedBytes
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
                                label1.wrapMode: Text.NoWrap
                                label1.clip: true

                                label2.wrapMode: Text.NoWrap
                                label2.clip: true

                                // Force ElideNone so contentWidth reflects the full
                                // text length — required for the marquee to work.
                                // restoreMode: RestoreNone prevents MauiKit's internal
                                // binding from reasserting ElideRight after us.
                                Binding
                                {
                                    target: _del.label1
                                    property: "elide"
                                    value: Text.ElideNone
                                    restoreMode: Binding.RestoreNone
                                }

                                Binding
                                {
                                    target: _del.label2
                                    property: "elide"
                                    value: Text.ElideNone
                                    restoreMode: Binding.RestoreNone
                                }

                                // Reset scroll position when the item is not hovered.
                                Binding { target: _del.label1; property: "contentX"; value: 0; when: !_del.hovered; restoreMode: Binding.RestoreNone }
                                Binding { target: _del.label2; property: "contentX"; value: 0; when: !_del.hovered; restoreMode: Binding.RestoreNone }

                                // Marquee scroll triggered by hovering the delegate.
                                SequentialAnimation
                                {
                                    loops: Animation.Infinite
                                    running: _del.hovered && _del.label1.contentWidth > _del.label1.width

                                    PauseAnimation  { duration: 500 }
                                    NumberAnimation { target: _del.label1; property: "contentX"; from: 0; to: _del.label1.contentWidth - _del.label1.width; duration: _del.label1.contentWidth * 18; easing.type: Easing.InOutQuad }
                                    PauseAnimation  { duration: 500 }
                                }

                                SequentialAnimation
                                {
                                    loops: Animation.Infinite
                                    running: _del.hovered && _del.label2.contentWidth > _del.label2.width

                                    PauseAnimation  { duration: 500 }
                                    NumberAnimation { target: _del.label2; property: "contentX"; from: 0; to: _del.label2.contentWidth - _del.label2.width; duration: _del.label2.contentWidth * 18; easing.type: Easing.InOutQuad }
                                    PauseAnimation  { duration: 500 }
                                }

                                label2.text:
                                {
                                    if (_dlItem._inProgress || _dlItem._isPaused)
                                    {
                                        var host = ""
                                        try { host = new URL(_dlItem.download.url.toString()).hostname } catch(e) {}
                                        var sizeStr = _surf.formatBytes(download.receivedBytes) + " / " + _surf.formatBytes(download.totalBytes)
                                        var suffix  = _dlItem._isPaused
                                            ? i18n("Paused")
                                            : (_dlItem._speedBps > 0 ? _surf.formatBytes(_dlItem._speedBps) + "/s" : "")
                                        return (host.length > 0 ? host + " \u2022 " : "") + sizeStr + (suffix.length > 0 ? " \u2022 " + suffix : "")
                                    }
                                    return model.url
                                }

                                iconSource: download.state === WebEngineDownloadRequest.DownloadCompleted
                                            ? model.filePath
                                            : model.icon

                                onClicked:
                                {
                                    if (!_dlItem._inProgress && !_dlItem._isPaused)
                                        openDownloadedFile(model.filePath)
                                }

                                onRightClicked:
                                {
                                    _downloadMenu.rowIndex = index
                                    _downloadMenu.currentFilePath = model.filePath
                                    _downloadMenu.currentDownload = _dlItem.download
                                    _downloadMenu.popup()
                                }

                                onPressAndHold:
                                {
                                    _downloadMenu.rowIndex = index
                                    _downloadMenu.currentFilePath = model.filePath
                                    _downloadMenu.currentDownload = _dlItem.download
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

                                visible: _dlItem._inProgress || _dlItem._isPaused
                                height: 6
                                radius: height / 2
                                color: Maui.Theme.alternateBackgroundColor
                                border.color: Maui.Theme.separatorColor
                                border.width: 1

                                clip: true

                                Rectangle
                                {
                                    id: _progressFill

                                    readonly property bool _indeterminate: _dlItem._inProgress && _dlItem.download.totalBytes <= 0
                                    readonly property real _ratio: _dlItem.download.totalBytes > 0
                                                                   ? _dlItem.download.receivedBytes / _dlItem.download.totalBytes
                                                                   : 0

                                    height: parent.height
                                    radius: parent.radius
                                    color: _dlItem._isPaused
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


