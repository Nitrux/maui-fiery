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

    background: null
    headerMargins: Maui.Style.contentMargins
    readonly property var activeView: privateMode ? _privateTabView : _browserListView

    property var currentTab: activeView.currentItem
    readonly property WebEngineView currentBrowser: currentTab && currentTab.currentItem ? currentTab.currentItem.webView : null
    readonly property var listView: activeView
    property int count: activeView.count
    readonly property var model: activeView.contentModel
    property alias searchFieldVisible: control.footBar.visible
    property var _closedTabsStack: []   // stack of url arrays, most-recent last
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

    Shortcut
    {
        sequence: "Ctrl+T"
        onActivated: openTab("")
    }

    Shortcut
    {
        sequence: "Ctrl+W"
        enabled: activeView.count > 0
        onActivated:
        {
            if (currentTab)
            {
                var entry = currentTab.urls.map(function(u) { return u.toString() })
                control._closedTabsStack = control._closedTabsStack.concat([entry])
            }
            activeView.closeTab(activeView.currentIndex)
        }
    }

    Shortcut
    {
        sequence: "Ctrl+R"
        enabled: currentBrowser !== null
        onActivated: currentBrowser.reload()
    }

    Shortcut
    {
        sequence: "Ctrl+D"
        enabled: currentBrowser !== null
        onActivated: Fiery.Bookmarks.insertBookmark(currentBrowser.url, currentBrowser.title)
    }

    Shortcut
    {
        sequence: "Ctrl+J"
        onActivated: openDownloads()
    }

    // ── Core navigation ───────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+Shift+T"
        onActivated:
        {
            if (control._closedTabsStack.length > 0)
            {
                var stack = control._closedTabsStack.slice()
                var urls = stack.pop()
                control._closedTabsStack = stack
                openTab(urls[0])
                if (urls.length > 1)
                    Qt.callLater(function() { openSplit(urls[1]) })
            }
        }
    }

    Shortcut
    {
        sequence: "Ctrl+Tab"
        enabled: activeView.count > 1
        onActivated: activeView.currentIndex = (activeView.currentIndex + 1) % activeView.count
    }

    Shortcut
    {
        sequence: "Ctrl+Shift+Tab"
        enabled: activeView.count > 1
        onActivated: activeView.currentIndex = (activeView.currentIndex - 1 + activeView.count) % activeView.count
    }

    Shortcut { sequence: "Ctrl+1"; enabled: activeView.count >= 1; onActivated: activeView.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+2"; enabled: activeView.count >= 2; onActivated: activeView.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+3"; enabled: activeView.count >= 3; onActivated: activeView.currentIndex = 2 }
    Shortcut { sequence: "Ctrl+4"; enabled: activeView.count >= 4; onActivated: activeView.currentIndex = 3 }
    Shortcut { sequence: "Ctrl+5"; enabled: activeView.count >= 5; onActivated: activeView.currentIndex = 4 }
    Shortcut { sequence: "Ctrl+6"; enabled: activeView.count >= 6; onActivated: activeView.currentIndex = 5 }
    Shortcut { sequence: "Ctrl+7"; enabled: activeView.count >= 7; onActivated: activeView.currentIndex = 6 }
    Shortcut { sequence: "Ctrl+8"; enabled: activeView.count >= 8; onActivated: activeView.currentIndex = 7 }
    Shortcut { sequence: "Ctrl+9"; enabled: activeView.count > 0;  onActivated: activeView.currentIndex = activeView.count - 1 }

    // ── Window control ────────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+N"
        onActivated: newWindow([appSettings.homePage])
    }

    Shortcut
    {
        sequence: "Ctrl+Shift+N"
        onActivated:
        {
            privateMode = !privateMode
            if (privateMode && _privateTabView.count === 0)
                Qt.callLater(openEditMode)
        }
    }

    // ── Navigation & page control ─────────────────────────────────────────────

    Shortcut
    {
        sequence: "Alt+Left"
        enabled: currentBrowser !== null && currentBrowser.canGoBack
        onActivated: currentBrowser.goBack()
    }

    Shortcut
    {
        sequence: "Alt+Right"
        enabled: currentBrowser !== null && currentBrowser.canGoForward
        onActivated: currentBrowser.goForward()
    }

    Shortcut
    {
        sequence: "Ctrl+Shift+R"
        enabled: currentBrowser !== null
        onActivated: currentBrowser.triggerWebAction(WebEngineView.ReloadAndBypassCache)
    }

    Shortcut
    {
        sequence: "Escape"
        enabled: currentBrowser !== null
        onActivated: currentBrowser.stop()
    }

    // ── Address bar ───────────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+L"
        onActivated: _navigationPopup.open()
    }

    // ── Page interaction ──────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+F"
        onActivated: control.searchFieldVisible = !control.searchFieldVisible
    }

    Shortcut
    {
        // "Ctrl+=" covers the physical key (= / +) without requiring Shift.
        // "Ctrl++" is kept as an alias for keyboards that map it directly.
        sequences: ["Ctrl+=", "Ctrl++"]
        enabled: currentBrowser !== null
        onActivated: appSettings.zoomFactor = Math.min(appSettings.zoomFactor + 0.25, 5.0)
    }

    Shortcut
    {
        sequence: "Ctrl+-"
        enabled: currentBrowser !== null
        onActivated: appSettings.zoomFactor = Math.max(appSettings.zoomFactor - 0.25, 0.25)
    }

    Shortcut
    {
        sequence: "Ctrl+0"
        enabled: currentBrowser !== null
        onActivated: appSettings.zoomFactor = 1.0
    }

    Shortcut
    {
        sequence: "Ctrl+S"
        enabled: currentBrowser !== null
        onActivated: currentBrowser.triggerWebAction(WebEngineView.SavePage)
    }

    Shortcut
    {
        sequence: "F11"
        onActivated:
        {
            if (root.visibility === Window.FullScreen)
                root.showNormal()
            else
                root.showFullScreen()
        }
    }

    // ── History / downloads / dev tools ───────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+H"
        onActivated: openHistory()
    }


    Shortcut
    {
        sequence: "Ctrl+U"
        enabled: currentBrowser !== null
        onActivated: openTab("view-source:" + currentBrowser.url)
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
            // Display the URL with any IDN hostname converted to Punycode so
            // homograph spoofing is visible while the popup is open.
            _entryField.text = currentBrowser ? _surf.safeDisplayUrl(currentBrowser.url.toString()) : ""
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

            // Ctrl+Enter: append .com to the typed word and navigate.
            // Alt+Enter: open the typed URL / query in a new tab.
            Keys.onPressed: (event) =>
            {
                const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                if (!isReturn)
                    return

                if (event.modifiers & Qt.ControlModifier)
                {
                    var t = _entryField.text.trim()
                    if (t.length > 0)
                    {
                        control.openUrl(t.endsWith(".com") ? t : t + ".com")
                        _navigationPopup.close()
                    }
                    event.accepted = true
                }
                else if (event.modifiers & Qt.AltModifier)
                {
                    if (_entryField.text.length > 0)
                    {
                        openTab(_entryField.text)
                        _navigationPopup.close()
                    }
                    event.accepted = true
                }
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
        background: null
        tabBarMargins: Maui.Style.contentMargins
        holder.emoji: "qrc:/internet.svg"

        holder.title: i18n("Start Browsing")
        holder.body: i18n("Enter a new URL or open a recent site.")

        onNewTabClicked: openTab("")
        onCloseTabClicked: (index) =>
        {
            var tab = _browserListView.tabAt(index)
            if (tab)
            {
                var entry = tab.urls.map(function(u) { return u.toString() })
                control._closedTabsStack = control._closedTabsStack.concat([entry])
            }
            _browserListView.closeTab(index)
        }

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
            background: null
            tabBarMargins: Maui.Style.contentMargins
            holder.emoji: "qrc:/internet.svg"
            holder.title: i18n("Start Browsing Privately")
            holder.body: i18n("Enter a new URL or open a recent site.")

            onNewTabClicked: openTab("")
            onCloseTabClicked: (index) =>
            {
                var tab = _privateTabView.tabAt(index)
                if (tab)
                {
                    var entry = tab.urls.map(function(u) { return u.toString() })
                    control._closedTabsStack = control._closedTabsStack.concat([entry])
                }
                _privateTabView.closeTab(index)
            }

            menuActions: [
                Action
                {
                    text: i18n("Detach")
                    onTriggered:
                    {
                        let index = _privateTabView.menu.index
                        var urls = _privateTabView.tabAt(index).urls
                        newWindow(urls, true /* incognito */)
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

    // Full-width loading indicator at the edge of the tab bar, like Chrome on mobile.
    // Spans the window width; sits below the tab bar when it is at the top,
    // or above it when it is at the bottom (altTabBar / mobile layout).
    Rectangle
    {
        id: _loadingBar

        z: 99
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 3

        // activeView fills control, so its tabBar.y is in the same coordinate space.
        y: activeView.altTabBar
           ? activeView.tabBar.y                             // bar just above bottom tab bar
           : activeView.tabBar.y + activeView.tabBar.height  // bar just below top tab bar

        visible: currentBrowser !== null && currentBrowser.loading && activeView.tabBar.visible

        // No background track — thin accent line only, Chrome mobile style.
        color: "transparent"

        Rectangle
        {
            id: _loadFill

            readonly property bool _indeterminate: currentBrowser
                && currentBrowser.loading
                && (currentBrowser.loadProgress <= 0 || currentBrowser.loadProgress >= 100)

            readonly property real _ratio: currentBrowser
                ? currentBrowser.loadProgress / 100.0
                : 0

            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            color:  Maui.Theme.highlightColor
            width:  _indeterminate ? parent.width * 0.30 : parent.width * _ratio

            SequentialAnimation on x
            {
                loops: Animation.Infinite
                running: _loadFill._indeterminate

                NumberAnimation { from: 0;                                             to: _loadingBar.width - _loadFill.width; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { from: _loadingBar.width - _loadFill.width; to: 0;   duration: 800; easing.type: Easing.InOutQuad }
            }
        }
    }

    WebEngineProfile
    {
        id: _incognitoProfile
        offTheRecord: true
    }

    Component.onCompleted:
    {
        if (appSettings.restoreSession && appSettings.sessionUrlsJson.length > 0)
        {
            try
            {
                var urls = JSON.parse(appSettings.sessionUrlsJson)
                if (urls && urls.length > 0)
                {
                    urls.forEach(url => openTab(url))
                    return
                }
            }
            catch (e) {}
        }

        openTab(appSettings.homePage)
    }

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

    // Inline article extraction script for Reader Mode.
    // Searches semantic landmarks for the main content, then overlays the page
    // with a clean, distraction-free reading view.  A close button restores
    // the original page.  Subsequent calls toggle the overlay off.
    //
    // Fixes applied vs. first version:
    //   - body overflow hidden while active (eliminates the double scrollbar)
    //   - scoped CSS resets element colors, backgrounds, and image sizing
    //   - column uses min(90vw, 1200px) so it fills wider viewports too
    readonly property string _readerScript: "(function(){" +
        "var ex=document.getElementById('fiery-reader');" +
        "if(ex){" +
            "ex.remove();" +
            "document.documentElement.style.overflow='';" +
            "document.body.style.overflow='';" +
            "return;" +
        "}" +
        "var sel=['article','[role=\"main\"]','main','.post-content','.article-content'," +
            "'.entry-content','.post-body','.article-body','.content-body','#content','#main'];" +
        "var el=null;" +
        "for(var i=0;i<sel.length;i++){el=document.querySelector(sel[i]);if(el)break;}" +
        "if(!el)el=document.body;" +
        "var dark=window.matchMedia&&window.matchMedia('(prefers-color-scheme:dark)').matches;" +
        "var bg=dark?'#1a1a1a':'#f8f6f1';" +
        "var fg=dark?'#e0e0e0':'#1e1e1e';" +
        "var link=dark?'#7ab8ff':'#0055cc';" +
        "var ov=document.createElement('div');" +
        "ov.id='fiery-reader';" +
        "ov.style.cssText='position:fixed;inset:0;z-index:2147483647;overflow-y:scroll;" +
            "background:'+bg+';color:'+fg+';';" +
        "var css=document.createElement('style');" +
        // Base typography and scrollbar
        "css.textContent=" +
            "'#fiery-reader{font-family:Georgia,\"Times New Roman\",serif;line-height:1.8;font-size:18px;}'" +
            // Constrain and centre the inner column with generous padding
            "+'#fiery-reader-body{" +
                "max-width:min(92vw,1200px);width:100%;margin:0 auto;" +
                "padding:56px 40px 100px;box-sizing:border-box;}'" +
            // Force all text to reader colours — defeats inherited site stylesheets
            "+'#fiery-reader *{color:'+fg+'!important;background:transparent!important;" +
                "border-color:rgba(128,128,128,0.3)!important;}'" +
            // Headings: reset size, weight, and spacing so site CSS can't interfere
            "+'#fiery-reader h1{font-size:1.9em;line-height:1.25;margin:0 0 0.75em;}'" +
            "+'#fiery-reader h2{font-size:1.45em;line-height:1.3;margin:1.8em 0 0.5em;}'" +
            "+'#fiery-reader h3{font-size:1.2em;line-height:1.35;margin:1.5em 0 0.4em;}'" +
            "+'#fiery-reader h4,#fiery-reader h5,#fiery-reader h6{font-size:1em;margin:1.2em 0 0.4em;}'" +
            // Paragraph and list spacing
            "+'#fiery-reader p{margin:0 0 1.1em;}'" +
            "+'#fiery-reader ul,#fiery-reader ol{margin:0 0 1.1em;padding-left:1.8em;}'" +
            "+'#fiery-reader li{margin-bottom:0.3em;}'" +
            // Images: fill the column, never overflow
            "+'#fiery-reader img{max-width:100%!important;width:auto!important;" +
                "height:auto!important;display:block;margin:1.4em auto;}'" +
            // Links
            "+'#fiery-reader a{color:'+link+'!important;text-decoration:underline;}'" +
            // Blockquote
            "+'#fiery-reader blockquote{margin:1.2em 0;padding:0.6em 1.2em;" +
                "border-left:3px solid rgba(128,128,128,0.4);font-style:italic;}'" +
            // Tables
            "+'#fiery-reader table{width:100%;border-collapse:collapse;margin:1em 0;}'" +
            "+'#fiery-reader td,#fiery-reader th{padding:0.5em;text-align:left;" +
                "border:1px solid rgba(128,128,128,0.3);}'; " +
        "ov.appendChild(css);" +
        "var body=document.createElement('div');" +
        "body.id='fiery-reader-body';" +
        "body.innerHTML='<h1>'+document.title+'</h1>'+el.innerHTML;" +
        "var btn=document.createElement('button');" +
        "btn.textContent='\u2715  Exit Reader View';" +
        "btn.style.cssText='display:block;margin:40px auto 0;padding:10px 24px;" +
            "background:transparent!important;border:1px solid rgba(128,128,128,0.5)!important;" +
            "border-radius:6px;font:inherit;cursor:pointer;opacity:0.65;';" +
        "btn.onclick=function(){" +
            "ov.remove();" +
            "document.documentElement.style.overflow='';" +
            "document.body.style.overflow='';" +
        "};" +
        "body.appendChild(btn);" +
        "ov.appendChild(body);" +
        "document.body.appendChild(ov);" +
        // Hide scrollbar on BOTH html and body — Chromium uses <html> for the
        // browser-chrome-level scrollbar; hiding only <body> leaves one behind.
        "document.documentElement.style.overflow='hidden';" +
        "document.body.style.overflow='hidden';" +
        "ov.scrollTo(0,0);" +
        "})();"

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
                    text: i18n("Reader View")
                    icon.name: "view-readermode"
                    enabled: currentBrowser !== null && currentBrowser.url.toString() !== "" && currentBrowser.url.toString() !== "about:blank"
                    onTriggered: currentBrowser.runJavaScript(_readerScript)
                }

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
        if(currentTab.count === 1)
        {
            currentTab.split(path)
            return
        }

        // Split already open — load into the inactive pane instead of a new tab.
        var inactiveIndex = currentTab.currentIndex === 0 ? 1 : 0
        currentTab.model.get(inactiveIndex).url = path
    }

    function collectSessionUrls()
    {
        var urls = []
        for (var i = 0; i < _browserListView.count; i++)
        {
            const tab = _browserListView.contentModel.get(i)
            if (!tab) continue

            for (var j = 0; j < tab.count; j++)
            {
                const browser = tab.model.get(j)
                if (browser && browser.url)
                {
                    const u = browser.url.toString()
                    if (u.length > 0 && u !== "about:blank")
                        urls.push(u)
                }
            }
        }
        return urls
    }

    function openUrl(path)
    {
        if(!control.currentBrowser)
            return

        // Block javascript: pseudo-protocol to prevent Self-XSS via the address bar.
        if(path.toString().trim().toLowerCase().startsWith("javascript:"))
            return

        if(_surf.isValidUrl(path))
        {
            if(_surf.hasProtocol(path))
                control.currentBrowser.url = path
            else
                control.currentBrowser.url = 'https://' + path
        } else
        {
            control.currentBrowser.url = appSettings.searchEnginePage + encodeURIComponent(path)
        }

        control.currentTab.forceActiveFocus()
    }

}
