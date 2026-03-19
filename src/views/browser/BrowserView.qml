import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

import "../widgets"

Maui.Page
{
    id: control
    property bool privateMode: false
    readonly property var activeView: privateMode ? _privateTabView : _browserListView

    property var currentTab: activeView.currentItem
    readonly property WebEngineView currentBrowser: currentTab && currentTab.currentItem ? currentTab.currentItem.webView : null
    readonly property var listView: activeView
    property int count: activeView.count
    readonly property var model: activeView.contentModel
    property alias searchFieldVisible: control.footBar.visible
    onSearchFieldVisibleChanged:
    {
        if(!searchFieldVisible && control.currentBrowser)
            control.currentBrowser.findText("")
    }


    headBar.visible: !root.isWide
    altHeader: true
    headBar.rightContent: Loader
    {
        asynchronous: true
        active: !root.isWide
        visible: active
        sourceComponent: _browserMenuComponent
    }

    headBar.leftContent: Loader
    {
        asynchronous: true
        active: !root.isWide
        visible: active
        sourceComponent: _navigationControlsComponent
    }

    footBar.visible: false
    footBar.middleContent: Maui.SearchField
    {
        id: _searchField

        Layout.maximumWidth: 500
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        onAccepted: control.currentBrowser.findText(text)
        onCleared: control.currentBrowser.findText("")
        actions: [

            Action
            {
                icon.name: "go-up"
                onTriggered:
                {
                    console.log("Find previous")
                    control.currentBrowser.findText(_searchField.text, WebEngineView.FindBackward)
                }
            },

            Action
            {
                icon.name: "go-down"
                onTriggered:
                {

                    console.log("Find next")

                    control.currentBrowser.findText(_searchField.text)
                }
            }
        ]
    }

    Shortcut
    {
        sequence: "Ctrl+K"
        onActivated: _navigationPopup.open()
    }

    Maui.PopupPage
    {
        id: _navigationPopup

        maxHeight: 900
        maxWidth: 500
        hint: 1
        persistent: true
        headBar.visible: true
        page.altHeader: _browserListView.altTabBar

        onOpened:
        {
            _entryField.text = currentBrowser ? currentBrowser.url : ""
            _entryField.forceActiveFocus()
            _entryField.selectAll()
        }

        headBar.forceCenterMiddleContent: false
        headBar.middleContent: Maui.SearchField
        {
            id: _entryField
            Layout.fillWidth: true
            placeholderText: i18n("Search or enter URL")

            activeFocusOnPress : true
            inputMethodHints: Qt.ImhUrlCharactersOnly  | Qt.ImhNoAutoUppercase

            onAccepted:
            {
                if(text.length > 0)
                    control.openUrl(text)
                else if(_historyListView.currentItem)
                {
                    control.openUrl(_historyListView.currentItem.url)
                }

                _navigationPopup.close()
            }

            Keys.forwardTo: _historyListView
        }


        stack: Maui.ListBrowser
        {
            id: _historyListView
            clip: true

            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: -1

            orientation: ListView.Vertical
            spacing: Maui.Style.space.medium

            flickable.header: ColumnLayout
            {
                width: parent.width
                spacing: _historyListView.spacing

                Maui.ListBrowserDelegate
                {
                    Layout.fillWidth: true
                    label1.text: _entryField.text
                    label2.text: i18n("Search on default search engine")

                    iconSource: "edit-find"
                    iconSizeHint: Maui.Style.iconSizes.medium

                    onClicked:
                    {
                        control.openUrl(_entryField.text)
                        _navigationPopup.close()
                    }
                }

            }

            Keys.onEnterPressed:
            {
                if(_historyListView.currentItem)
                    control.openUrl(_historyListView.currentItem.url)
            }

            model: Maui.BaseModel
            {
                list: Fiery.History
                filter: _entryField.text
                sort: "adddate"
                sortOrder: Qt.AscendingOrder
                recursiveFilteringEnabled: true
                sortCaseSensitivity: Qt.CaseInsensitive
                filterCaseSensitivity: Qt.CaseInsensitive
            }

            delegate: Maui.ListBrowserDelegate
            {
                width: ListView.view.width
                property string url : model.url
                label1.text: model.title
                label2.text: model.url
                imageSource: model.icon.replace("image://favicon/", "")
                template.imageSizeHint: Maui.Style.iconSizes.medium
                onClicked:
                {
                    control.openUrl(model.url)
                    _navigationPopup.close()
                }
            }
        }
    }

    Maui.TabView
    {
        id: _browserListView
        anchors.fill: parent
        visible: !privateMode
        holder.emoji: "qrc:/internet.svg"

        holder.title: i18n("Start Browsing")
        holder.body: i18n("Enter a new URL or open a recent site.")

        onNewTabClicked: openTab("")
        onCloseTabClicked: (index) => _browserListView.closeTab(index)

        menuActions: [
            Action
            {
                text: i18n("Detach")
                onTriggered:
                {
                    let index = _browserListView.menu.index
                    var urls = _browserListView.tabAt(index).urls
                    newWindow(urls)
                    _browserListView.closeTab(index)
                }
            },
            Action
            {
                text: i18n("Pin")
                onTriggered:
                {
                    let index = _browserListView.menu.index
                    var tab = _browserListView.tabAt(index)
                    tab.pinned = !tab.pinned
                }
            }
        ]

        tabViewButton : NavigationBar
        {
            tabView: _browserListView
        }

        tabBar.showNewTabButton: false
        tabBar.visible: root.visibility !== Window.FullScreen
        altTabBar: Maui.Handy.isMobile
        tabBar.rightContent: [
            Loader
            {
                asynchronous: true
                active: root.isWide
                visible: active
                sourceComponent: _browserMenuComponent
            },

            Maui.WindowControls {}
        ]

        tabBar.leftContent: Loader
        {
            asynchronous: true
            active: root.isWide
            visible: active
            sourceComponent: _navigationControlsComponent
        }
    }

    Item
    {
        id: _privateModeView
        anchors.fill: parent
        visible: privateMode

        Maui.Holder
        {
            z: 1
            anchors.fill: parent
            visible: _privateTabView.count === 0
            emoji: "face-glasses"
            title: i18n("Private Browsing")
            body: i18n("Fiery won't save your browsing history, cookies, or site data in Private Browsing mode. Downloads will still be saved.\n\nYour activity may still be visible to your network or device administrator.")

            actions: Action
            {
                text: i18n("New Private Tab")
                onTriggered: openTab("")
            }
        }

        Maui.TabView
        {
            id: _privateTabView
            anchors.fill: parent
            visible: count > 0
            holder.emoji: "qrc:/internet.svg"
            holder.title: i18n("Start Browsing Privately")
            holder.body: i18n("Enter a new URL or open a recent site.")

            onNewTabClicked: openTab("")
            onCloseTabClicked: (index) => _privateTabView.closeTab(index)

            menuActions: [
                Action
                {
                    text: i18n("Detach")
                    onTriggered:
                    {
                        let index = _privateTabView.menu.index
                        var urls = _privateTabView.tabAt(index).urls
                        newWindow(urls)
                        _privateTabView.closeTab(index)
                    }
                },
                Action
                {
                    text: i18n("Pin")
                    onTriggered:
                    {
                        let index = _privateTabView.menu.index
                        var tab = _privateTabView.tabAt(index)
                        tab.pinned = !tab.pinned
                    }
                }
            ]

            tabViewButton: NavigationBar
            {
                tabView: _privateTabView
            }

            tabBar.showNewTabButton: false
            tabBar.visible: root.visibility !== Window.FullScreen
            altTabBar: Maui.Handy.isMobile
            tabBar.rightContent: [
                Loader
                {
                    asynchronous: true
                    active: root.isWide
                    visible: active
                    sourceComponent: _browserMenuComponent
                },
                Maui.WindowControls {}
            ]

            tabBar.leftContent: Loader
            {
                asynchronous: true
                active: root.isWide
                visible: active
                sourceComponent: _navigationControlsComponent
            }
        }
    }

    WebEngineProfile
    {
        id: _incognitoProfile
        offTheRecord: true
    }

    Component.onCompleted: openTab(appSettings.homePage)

    Component
    {
        id: _browserComponent

        BrowserLayout {}
    }

    Component
    {
        id: _navigationControlsComponent

        Row
        {
            spacing: control.headBar.spacing

            ToolButton
            {
                icon.name: _sideBarView.sideBar.visible ? "sidebar-collapse" : "sidebar-expand"
                onClicked: _sideBarView.sideBar.toggle()
                checked: _sideBarView.sideBar.visible
                visible: _sideBarView.sideBar.visible && !_sideBarView.sideBar.collapsed
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: i18n("Toggle sidebar")
            }

            Maui.ToolActions
            {
                display: ToolButton.IconOnly
                Action
                {
                    enabled: currentBrowser.canGoBack
                    onTriggered: currentBrowser.goBack()
                    text: i18n("Previous")

                    icon.name: "go-previous"
                }

                Action
                {
                    text: i18n("Next")
                    enabled: currentBrowser.canGoForward
                    icon.name: "go-next"
                    onTriggered: currentBrowser.goForward()
                }
            }

            ToolButton
            {
                icon.name: "view-refresh"
                onClicked: currentBrowser.reload()
            }

            ToolButton
            {
                text: activeView.count
                visible: activeView.count > 1
                onClicked: activeView.openOverview()
                icon.name: "view-list-icons"
            }
        }
    }

    Component
    {
        id: _browserMenuComponent

        Row
        {
            spacing: control.headBar.spacing

            ToolButton
            {
                icon.name: "list-add"
                onClicked: control.openTab("")
            }

            ToolButton
            {
                icon.name: currentTab && currentTab.count === 2 ? "view-right-close" : "view-split-left-right"
                onClicked: currentTab && currentTab.count === 2 ? currentTab.pop() : control.openSplit("")
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: currentTab && currentTab.count === 2 ? i18n("Close Split View") : i18n("Split View")
            }

            Maui.ToolButtonMenu
            {
                icon.name: "overflow-menu"

                Maui.MenuItemActionRow
                {
                    Action
                    {
                        icon.name: "love"
                        checked: Fiery.Bookmarks.isBookmark(currentBrowser.url)
                        checkable: true
                        onTriggered: Fiery.Bookmarks.insertBookmark(currentBrowser.url, currentBrowser.title)
                    }

                    Action
                    {
                        icon.name: "zoom-out"
                        onTriggered: appSettings.zoomFactor = Math.max(appSettings.zoomFactor - 0.25, 0.25)
                    }

                    Action
                    {
                        icon.name: "zoom-fit-page"
                        onTriggered: appSettings.zoomFactor = 1.0
                    }

                    Action
                    {
                        icon.name: "zoom-in"
                        onTriggered: appSettings.zoomFactor = Math.min(appSettings.zoomFactor + 0.25, 5.0)
                    }
                }

                MenuItem
                {
                    text: privateMode ? i18n("Exit Private Browsing") : i18n("Private Browsing")
                    checked: privateMode
                    onTriggered:
                    {
                        privateMode = !privateMode
                        if(privateMode && _privateTabView.count === 0)
                            Qt.callLater(openEditMode)
                    }
                }

                MenuSeparator {}


                MenuItem
                {
                    text: i18n("Bookmarks")
                    onTriggered: openBookmarks()
                }

                MenuItem
                {
                    text: i18n("History")
                    onTriggered: openHistory()
                }

                MenuItem
                {
                    text: i18n("Downloads")
                    onTriggered: openDownloads()
                }

                MenuSeparator {}

                MenuItem
                {
                    text: i18n("Find In Page")
                    checked: control.searchFieldVisible
                    onTriggered: control.searchFieldVisible = !control.searchFieldVisible
                }

                MenuSeparator {}

                MenuItem
                {
                    text: i18n("Settings")
                    onTriggered: _settingsDialog.open()
                }

                MenuItem
                {
                    text: i18n("About")
                    onTriggered: Maui.App.aboutDialog()
                }
            }
        }
    }

    function openEditMode()
    {
        _navigationPopup.open()
    }

    function findTab(path)
    {
        var index = browserIndex(path)

        if(index[0] >= 0 && index[1] >= 0)
        {
            activeView.currentIndex = index[0]

            var tab = control.model.get(index[0])
            tab.currentIndex = index[1]
            return true;
        }

        return false;
    }

    function browserIndex(path) //find the [tab, split] index for a path
    {
        if(path.length === 0)
        {
            return [-1, -1]
        }

        for(var i = 0; i < control.count; i++)
        {
            const tab =  control.model.get(i)
            for(var j = 0; j < tab.count; j++)
            {
                const browser = tab.model.get(j)
                if(browser.url.toString() === path)
                {
                    return [i, j]
                }
            }
        }
        return [-1,-1]
    }

    function openTab(path, profile)
    {
        if(findTab(path))
            return;

        if(privateMode && !profile)
            profile = _incognitoProfile

        var props = {"url": _surf.formatUrl(path)}
        if(profile)
            props["browserProfile"] = profile

        activeView.addTab(_browserComponent, props, !appSettings.switchToTab && path.length > 0);

        if(path.length === 0)
            Qt.callLater(openEditMode)
    }

    function openSplit(path)
    {
        console.log(currentTab.count)
        if(currentTab.count === 1)
        {
            currentTab.split(path)
            return
        }

        openTab(path)
    }

    function openUrl(path)
    {
        if(!control.currentBrowser)
            return

        if(_surf.isValidUrl(path))
        {
            if(_surf.hasProtocol(path))
                control.currentBrowser.url = path
            else
                control.currentBrowser.url = 'http://' + path
        } else
        {
            control.currentBrowser.url = appSettings.searchEnginePage + path
        }

        control.currentTab.forceActiveFocus()
    }

}
