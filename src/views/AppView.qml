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
    sideBar.preferredWidth: 400

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
                icon.name: "bookmarks"
                checked: _sidebarSwipeView.currentIndex === 0
                onTriggered: _sidebarSwipeView.currentIndex = 0
            }

            Action
            {
                text: i18n("Recent")
                icon.name: "shallow-history"
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
                        var dangerous = [".sh", ".bash", ".zsh", ".desktop", ".AppImage",
                                         ".run", ".bin", ".exe", ".py", ".pl", ".rb", ".command"]
                        var path = filePath.toString().toLowerCase()
                        if (dangerous.some(function(ext) { return path.endsWith(ext) }))
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

                        MenuItem
                        {
                            text: i18n("Open")
                            enabled: _downloadMenu.currentDownload !== null
                                     && _downloadMenu.currentDownload.state === WebEngineDownloadRequest.DownloadCompleted
                            onTriggered: openDownloadedFile(_downloadMenu.currentFilePath)
                        }

                        MenuSeparator {}

                        MenuItem
                        {
                            text: i18n("Remove from Downloads")
                            onTriggered: Fiery.DownloadsManager.remove(_downloadMenu.rowIndex)
                        }

                        MenuItem
                        {
                            text: i18n("Delete File")
                            onTriggered: Fiery.DownloadsManager.removeAndDeleteFile(_downloadMenu.rowIndex)
                        }
                    }

                    Maui.ListBrowser
                    {
                        anchors.fill: parent
                        model: Fiery.DownloadsManager.model

                        holder.title: i18n("Downloads")
                        holder.body: i18n("Your downloads will be listed in here.")
                        holder.emoji: "download"
                        holder.visible: count === 0

                        delegate: Item
                        {
                            id: _dlItem

                            width: ListView.view.width
                            height: _del.implicitHeight

                            property var download: model.download
                            readonly property bool _inProgress: download.state === WebEngineDownloadRequest.DownloadInProgress

                            // Format a byte count into a human-readable string.
                            function formatBytes(bytes)
                            {
                                if (bytes < 0)            return "?"
                                if (bytes < 1024)         return bytes + " B"
                                if (bytes < 1048576)      return (bytes / 1024).toFixed(1) + " KB"
                                if (bytes < 1073741824)   return (bytes / 1048576).toFixed(1) + " MB"
                                return (bytes / 1073741824).toFixed(2) + " GB"
                            }

                            Maui.ListBrowserDelegate
                            {
                                id: _del
                                anchors.fill: parent

                                label1.text: model.name
                                label2.text: _dlItem._inProgress
                                             ? _dlItem.formatBytes(download.receivedBytes) + " / " + _dlItem.formatBytes(download.totalBytes)
                                             : model.url

                                iconSource: download.state === WebEngineDownloadRequest.DownloadCompleted
                                            ? model.filePath
                                            : model.icon

                                onClicked:
                                {
                                    if (!_dlItem._inProgress)
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

                            // Thin progress strip anchored to the bottom of the
                            // delegate, visible only while the download is running.
                            // Matches the indeterminate style used in NavigationBar
                            // for page-load progress, but shows real byte progress
                            // when the server reports a Content-Length.
                            Maui.ProgressIndicator
                            {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                visible: _dlItem._inProgress
                                indeterminate: _dlItem.download.totalBytes <= 0
                                value: _dlItem.download.totalBytes > 0
                                       ? _dlItem.download.receivedBytes / _dlItem.download.totalBytes
                                       : 0
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


