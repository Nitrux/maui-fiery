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
    readonly property string currentPageUrl: currentBrowser ? currentBrowser.url.toString() : ""
    readonly property bool currentSiteAvailable: {
        const url = currentPageUrl.toLowerCase()
        return url.startsWith("http://") || url.startsWith("https://")
    }
    readonly property bool currentSiteHttps: currentPageUrl.toLowerCase().startsWith("https://")
    readonly property bool currentSiteSecure: currentSiteHttps && _surf.certificateValid
    readonly property string currentSiteName: {
        const separator = currentPageUrl.indexOf("://")
        const withoutScheme = separator >= 0 ? currentPageUrl.slice(separator + 3) : currentPageUrl
        const authority = withoutScheme.split("/")[0].split("?")[0].split("#")[0]
        return authority.split("@").pop().split(":")[0]
    }
    readonly property string currentSiteDomain: {
        const siteName = currentSiteName
        return siteName.toLowerCase().startsWith("www.") ? siteName.slice(4) : siteName
    }
    readonly property var listView: activeView
    property int count: activeView.count
    readonly property var model: activeView.contentModel
    property alias searchFieldVisible: control.footBar.visible
    property int _popupGeometryNudge: 0
    readonly property real _headerFootprint: root.visibility !== Window.FullScreen
                                           ? headBar.preferredHeight + headBar.topPadding + headBar.bottomPadding + headerMargins * 2
                                           : 0
    readonly property bool _uiDebug: fieryUiDiagnostics

    function _uiLog(event, details)
    {
        if (_uiDebug)
            console.log("[Fiery UI][BrowserView]", event, details === undefined ? "" : details)
    }

    function _uiGeometry(item)
    {
        if (!item)
            return "null"

        return "x=" + item.x + ",y=" + item.y + ",w=" + item.width + ",h=" + item.height
                + ",iw=" + item.implicitWidth + ",ih=" + item.implicitHeight
                + ",visible=" + item.visible
    }

    function _uiTabGeometry(item, tabBar)
    {
        if (!item || !tabBar)
            return "item=" + control._uiGeometry(item) + ",tabBar=null"

        const position = item.mapToItem(tabBar, 0, 0)
        return control._uiGeometry(item) + ",tabBarX=" + position.x + ",tabBarY=" + position.y + ",tabBarW=" + tabBar.width + ",tabBarH=" + tabBar.height
    }
    // Closed-tabs stack is now persisted in RECENTLY_CLOSED via Fiery.DBActions.
    onSearchFieldVisibleChanged:
    {
        if(!searchFieldVisible && control.currentBrowser)
            control.currentBrowser.findText("")
    }
    onCurrentTabChanged:
    {
        _uiLog("currentTabChanged", "index=" + activeView.currentIndex + ", count=" + activeView.count)
        _schedulePopupGeometryRefresh()
    }
    onCurrentBrowserChanged:
    {
        _syncAddressField()
        if (currentBrowser && currentSiteAvailable)
            _surf.inspectCertificate(currentBrowser.url)
    }
    onPrivateModeChanged:
    {
        _schedulePopupGeometryRefresh()
    }


    function _schedulePopupGeometryRefresh()
    {
        if (!control.visible || control.currentBrowser === null)
            return

        // Workaround for detached/mispositioned HTML <select> popups observed
        // in XWayland-on-Wayland sessions.
        if (!_surf.isX11OnWayland())
            return

        _popupGeometryNudge = 0
        _popupNudgeOnTimer.restart()
    }

    Timer
    {
        id: _popupNudgeOnTimer
        interval: 0
        repeat: false
        onTriggered:
        {
            control._popupGeometryNudge = 1
            _popupNudgeOffTimer.restart()
        }
    }

    Timer
    {
        id: _popupNudgeOffTimer
        interval: 16
        repeat: false
        onTriggered: control._popupGeometryNudge = 0
    }

    function _syncAddressField()
    {
        _uiLog("syncAddressField requested", "hasBar=" + !!_addressBar + " hasEntry=" + !!_addressEntry + " activeFocus=" + (_addressEntry ? _addressEntry.activeFocus : false) + " currentUrl=" + currentPageUrl)
        if (!_addressBar || !_addressEntry || _addressEntry.activeFocus)
        {
            _uiLog("syncAddressField skipped", !_addressBar || !_addressEntry ? "address controls unavailable" : "address entry has focus")
            return
        }

        const displayUrl = currentBrowser ? _surf.safeDisplayUrl(currentBrowser.url.toString()) : ""
        _addressBar.displayText = displayUrl
        _addressEntry.text = displayUrl
        _uiLog("syncAddressField applied", "textLength=" + displayUrl.length)
    }

    function _beginAddressEditing()
    {
        if (!_addressBar || !root.isWide)
            return

        _addressBar.editing = true
        Qt.callLater(function()
        {
            if (!_addressBar.editing)
                return

            _addressEntry.forceActiveFocus()
            _addressEntry.selectAll()
        })
    }

    function _finishAddressEditing()
    {
        if (!_addressBar)
            return

        _addressBar.editing = false
        _syncAddressField()
    }

    Connections
    {
        target: control.currentBrowser

        function onUrlChanged()
        {
            control._uiLog("currentBrowser urlChanged", "url=" + control.currentBrowser.url + " overview=" + control.activeView.overviewMode)
            control._syncAddressField()
            if (control.currentBrowser && control.currentSiteAvailable)
                _surf.inspectCertificate(control.currentBrowser.url)
        }
    }

    // Hyprland emits workspace and workspacev2 as one workspace switch.
    // Recover only the active browser instead of making every tab observe the
    // compositor-wide signal.
    Connections
    {
        target: Fiery.HyprlandWorkspace

        function onWorkspaceChanged()
        {
            const browser = control.currentTab && control.currentTab.currentItem
            if (browser && typeof browser.recoverFromWorkspaceChange === "function")
                browser.recoverFromWorkspaceChange()
        }
    }

    Image
    {
        id: _faviconImage
        source: currentTab ? currentTab.faviconSource : ""
        sourceSize: Qt.size(Maui.Style.iconSizes.medium, Maui.Style.iconSizes.medium)
        visible: false
        asynchronous: true

        onStatusChanged:
        {
            if (status === Image.Ready && control.Window.window && control.Window.window.visible)
                _faviconColors.update()
        }
    }

    Maui.ImageColors
    {
        id: _faviconColors
        source: control.Window.window && control.Window.window.visible ? _faviconImage : null
    }

    floatingHeader: true
    headBar.visible: root.visibility !== Window.FullScreen
    headBar.background: Rectangle
    {
        radius: control.headerMargins > 0 ? Maui.Style.radiusV : 0
        antialiasing: true
        property color tintedBackground: currentSiteAvailable && _faviconColors.dominant.valid
                                         ? Maui.ColorUtils.tintWithAlpha(Maui.Theme.backgroundColor, _faviconColors.dominant, 0.12)
                                         : Maui.Theme.backgroundColor

        color: tintedBackground
        border.color: control.headerMargins > 0
                      ? (currentSiteAvailable && _faviconColors.dominant.valid
                         ? Maui.ColorUtils.linearInterpolation(tintedBackground, Maui.Theme.textColor, 0.12)
                         : Maui.Theme.alternateBackgroundColor)
                      : "transparent"

        Behavior on color
        {
            ColorAnimation
            {
                duration: Maui.Style.units.shortDuration
            }
        }

        Behavior on border.color
        {
            ColorAnimation
            {
                duration: Maui.Style.units.shortDuration
            }
        }
    }

    Behavior on headBar.opacity
    {
        NumberAnimation
        {
            duration: Maui.Style.units.shortDuration
        }
    }

    function _syncOverviewHeadBar()
    {
        const inOverview = activeView.overviewMode
        headBar.visible = root.visibility !== Window.FullScreen
        headBar.enabled = !inOverview
        headBar.opacity = inOverview ? 0 : 1
        _uiLog("headBar overview state", "overview=" + inOverview + " opacity=" + headBar.opacity + " visible=" + headBar.visible + " enabled=" + headBar.enabled)
    }
    headBar.preferredHeight: Maui.Style.rowHeightAlt
    altHeader: !root.isWide
    headBar.forceCenterMiddleContent: false

    Connections
    {
        target: control.activeView

        function onOverviewModeChanged()
        {
            control._uiLog("overviewModeChanged", "overview=" + control.activeView.overviewMode + " index=" + control.activeView.currentIndex + " count=" + control.activeView.count)

            control._syncOverviewHeadBar()
        }
    }

    Connections
    {
        target: control.headBar

        function onVisibleChanged()
        {
            control._uiLog("headBar visibleChanged", control._uiGeometry(control.headBar))
        }

        function onWidthChanged()
        {
            control._uiLog("headBar widthChanged", control._uiGeometry(control.headBar))
        }

        function onHeightChanged()
        {
            control._uiLog("headBar heightChanged", control._uiGeometry(control.headBar))
        }

        function onImplicitHeightChanged()
        {
            control._uiLog("headBar implicitHeightChanged", control._uiGeometry(control.headBar))
        }

        function onOpacityChanged()
        {
            control._uiLog("headBar opacityChanged", "opacity=" + opacity + " overview=" + control.activeView.overviewMode)
        }

        function onEnabledChanged()
        {
            control._uiLog("headBar enabledChanged", "enabled=" + enabled + " overview=" + control.activeView.overviewMode)
        }
    }

    headBar.middleContent: Item
    {
        id: _addressBar
        visible: root.isWide
        Layout.fillWidth: true

        property bool editing: false
        property string displayText: ""

        onWidthChanged: control._uiLog("addressBar widthChanged", control._uiGeometry(_addressBar))
        onHeightChanged: control._uiLog("addressBar heightChanged", control._uiGeometry(_addressBar))
        onXChanged: control._uiLog("addressBar xChanged", control._uiGeometry(_addressBar))
        onYChanged: control._uiLog("addressBar yChanged", control._uiGeometry(_addressBar))
        onEditingChanged: control._uiLog("addressBar editingChanged", "editing=" + editing + " " + control._uiGeometry(_addressBar))
        onDisplayTextChanged: control._uiLog("addressBar displayTextChanged", "length=" + displayText.length)
        Component.onCompleted:
        {
            control._uiLog("addressBar completed", control._uiGeometry(_addressBar) + " editing=" + editing)
            control._syncAddressField()
        }

        implicitWidth: Math.max(_addressDisplay.implicitWidth, _addressEntry.implicitWidth)
        implicitHeight: Math.max(_addressDisplay.implicitHeight, _addressEntry.implicitHeight)

        onVisibleChanged:
        {
            control._uiLog("addressBar visibleChanged", control._uiGeometry(_addressBar) + " editing=" + editing)
            if (!visible)
                control._finishAddressEditing()
        }

        Item
        {
            id: _addressDisplay
            anchors.fill: parent
            visible: !_addressBar.editing
            onVisibleChanged: control._uiLog("addressDisplay visibleChanged", control._uiGeometry(_addressDisplay))
            implicitWidth: _addressEntry.implicitWidth
            implicitHeight: _addressEntry.implicitHeight

            Rectangle
            {
                anchors.fill: parent
                color: _addressDisplayMouse.containsMouse ? Maui.Theme.hoverColor : Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Qt.rgba(Maui.Theme.textColor.r, Maui.Theme.textColor.g, Maui.Theme.textColor.b, 0.15)
                border.width: 1
            }

            Label
            {
                anchors.fill: parent
                anchors.leftMargin: Maui.Style.space.medium
                anchors.rightMargin: _siteControlsButton.implicitWidth + Maui.Style.space.small
                text: _addressBar.displayText.length > 0 ? _addressBar.displayText : i18n("Search or enter URL")
                color: Maui.Theme.textColor
                font: Maui.Style.defaultFont
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            TapHandler
            {
                id: _addressDisplayTapHandler
                onTapped:
                {
                    control._uiLog("addressDisplay tapped", control._uiGeometry(_addressDisplay))
                    control._beginAddressEditing()
                }
            }

            HoverHandler
            {
                id: _addressDisplayMouse
            }
        }

        Maui.SearchField
        {
            id: _addressEntry
            anchors.fill: parent
            anchors.rightMargin: _siteControlsButton.implicitWidth + Maui.Style.space.small
            visible: _addressBar.editing
            placeholderText: i18n("Search or enter URL")
            activeFocusOnPress: true
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase

            onWidthChanged: control._uiLog("addressEntry widthChanged", control._uiGeometry(_addressEntry))
            onHeightChanged: control._uiLog("addressEntry heightChanged", control._uiGeometry(_addressEntry))
            onXChanged: control._uiLog("addressEntry xChanged", control._uiGeometry(_addressEntry))
            onYChanged: control._uiLog("addressEntry yChanged", control._uiGeometry(_addressEntry))
            onVisibleChanged: control._uiLog("addressEntry visibleChanged", control._uiGeometry(_addressEntry))

            onActiveFocusChanged:
            {
                control._uiLog("addressEntry focusChanged", "activeFocus=" + activeFocus + " textLength=" + text.length + " " + control._uiGeometry(_addressEntry))
                if (!activeFocus)
                    control._finishAddressEditing()
            }

            onTextChanged: control._uiLog("addressEntry textChanged", "length=" + text.length)

            onAccepted:
            {
                control._uiLog("addressEntry accepted", "length=" + text.length)
                if (text.length > 0)
                    control.openUrl(text)

                control._finishAddressEditing()
            }

            Keys.onEscapePressed: (event) =>
            {
                control._finishAddressEditing()
                event.accepted = true
            }
        }

        Maui.ToolButtonMenu
        {
            id: _siteControlsButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "dialog-information"
            enabled: control.currentSiteAvailable
            onWidthChanged: control._uiLog("siteControlsButton widthChanged", control._uiGeometry(_siteControlsButton))
            onHeightChanged: control._uiLog("siteControlsButton heightChanged", control._uiGeometry(_siteControlsButton))
            onVisibleChanged: control._uiLog("siteControlsButton visibleChanged", control._uiGeometry(_siteControlsButton))
            onEnabledChanged: control._uiLog("siteControlsButton enabledChanged", "enabled=" + enabled + " " + control._uiGeometry(_siteControlsButton))
            Component.onCompleted: control._uiLog("siteControlsButton completed", control._uiGeometry(_siteControlsButton))

            ToolTip.visible: hovered
            ToolTip.text: i18n("Site controls")

            MenuItem
            {
                text: control.currentSiteName
                contentItem: RowLayout
                {
                    spacing: Maui.Style.space.small

                    Maui.Icon
                    {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Maui.Style.iconSize
                        Layout.preferredHeight: Maui.Style.iconSize
                        source: control.currentSiteSecure ? "lock" : "unlock"
                        color: control.currentSiteHttps && _surf.certificateError.length > 0
                            ? Maui.Theme.negativeBackgroundColor
                            : Maui.Theme.positiveBackgroundColor
                    }

                    Label
                    {
                        Layout.fillWidth: true
                        text: control.currentSiteName
                        elide: Text.ElideRight
                    }
                }
            }

            MenuSeparator {}

            MenuItem
            {
                enabled: false
                opacity: 1
                hoverEnabled: false
                flat: true
                background: null
                contentItem: ColumnLayout
                {
                    spacing: Maui.Style.space.small

                    Label
                    {
                        Layout.fillWidth: true
                        visible: _surf.certificateLoading || _surf.certificateError.length > 0 || !_surf.certificateAvailable
                        text: _surf.certificateLoading
                              ? i18n("Retrieving certificate information…")
                              : _surf.certificateError.length > 0
                                ? i18n("Certificate warning: %1", _surf.certificateError)
                                : i18n("No certificate information is available.")
                        color: Maui.Theme.textColor
                        wrapMode: Text.WordWrap
                    }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        visible: _surf.certificateAvailable
                        color: Maui.Theme.alternateBackgroundColor
                        radius: Maui.Style.radiusV
                        border.width: 1
                        border.color: Qt.alpha(Maui.Theme.textColor, 0.10)
                        implicitHeight: _certificateDetails.implicitHeight + Maui.Style.space.small * 2

                        ColumnLayout
                        {
                            id: _certificateDetails
                            anchors.fill: parent
                            anchors.topMargin: Maui.Style.space.small
                            anchors.leftMargin: Maui.Style.space.small
                            anchors.rightMargin: Maui.Style.space.small
                            anchors.bottomMargin: Maui.Style.space.small
                            spacing: Maui.Style.space.small

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("Subject: %1", _surf.certificateSubject)
                                wrapMode: Text.WrapAnywhere
                            }

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("Issuer: %1", _surf.certificateIssuer)
                                wrapMode: Text.WrapAnywhere
                            }

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("Valid from: %1", _surf.certificateEffectiveDate)
                                wrapMode: Text.WrapAnywhere
                            }

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("Valid until: %1", _surf.certificateExpiryDate)
                                wrapMode: Text.WrapAnywhere
                            }

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("Serial number: %1", _surf.certificateSerialNumber)
                                wrapMode: Text.WrapAnywhere
                            }

                            Label
                            {
                                Layout.fillWidth: true
                                text: i18n("SHA-256 fingerprint: %1", _surf.certificateFingerprint)
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }

            MenuItem
            {
                text: i18n("Clear cookies and site data")
                icon.name: "edit-clear"
                onTriggered:
                {
                    _clearSiteDataDialog.targetBrowser = control.currentBrowser
                    _clearSiteDataDialog.open()
                }
            }

            MenuSeparator {}

            MenuItem
            {
                text: i18n("Site settings")
                icon.name: "configure"
                onTriggered: _siteSettingsDialog.openForCurrentSite()
            }
        }
    }

    Connections
    {
        target: _siteControlsButton.menu

        function onOpened()
        {
            if (control.currentBrowser && control.currentSiteAvailable
                    && !_surf.certificateLoading
                    && !_surf.certificateAvailable
                    && _surf.certificateError.length === 0)
                _surf.inspectCertificate(control.currentBrowser.url)
        }
    }

    Maui.SettingsDialog
    {
        id: _siteSettingsDialog
        Maui.Controls.title: i18n("Site settings")

        property url siteOrigin: ""
        property string siteName: ""
        property var siteProfile: null
        property int permissionRevision: 0

        readonly property var permissionDefinitions: [
            { type: WebEnginePermission.Notifications, label: i18n("Notifications"), description: i18n("Allow this site to send notifications.") },
            { type: WebEnginePermission.Geolocation, label: i18n("Location"), description: i18n("Allow this site to access your location.") },
            { type: WebEnginePermission.ClipboardReadWrite, label: i18n("Clipboard"), description: i18n("Allow this site to read and write the clipboard.") },
            { type: WebEnginePermission.LocalFontsAccess, label: i18n("Local fonts"), description: i18n("Allow this site to use fonts installed on this device.") }
        ]

        function openForCurrentSite()
        {
            if (!control.currentBrowser || !control.currentSiteAvailable)
                return

            siteOrigin = control.currentBrowser.url
            siteName = control.currentSiteDomain
            siteProfile = control.currentBrowser.profile
            permissionRevision++
            open()
        }

        function permission(permissionType)
        {
            if (!siteProfile || siteOrigin.toString().length === 0)
                return null

            return siteProfile.queryPermission(siteOrigin, permissionType)
        }

        onClosed:
        {
            siteProfile = null
            siteOrigin = ""
            siteName = ""
        }

        Maui.SectionGroup
        {
            title: i18n("Permissions for this site.")
            description: _siteSettingsDialog.siteName

            Repeater
            {
                model: _siteSettingsDialog.permissionDefinitions

                delegate: Maui.FlexSectionItem
                {
                    required property var modelData

                    label1.text: modelData.label
                    label2.text: modelData.description

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        enabled: _siteSettingsDialog.siteProfile !== null
                        checked:
                        {
                            _siteSettingsDialog.permissionRevision
                            const sitePermission = _siteSettingsDialog.permission(modelData.type)
                            return sitePermission && sitePermission.isValid
                                   && sitePermission.state === WebEnginePermission.Granted
                        }
                        onToggled:
                        {
                            const sitePermission = _siteSettingsDialog.permission(modelData.type)
                            if (!sitePermission || !sitePermission.isValid)
                                return

                            if (checked)
                                sitePermission.grant()
                            else
                                sitePermission.deny()

                            _siteSettingsDialog.permissionRevision++
                        }
                    }
                }
            }
        }
    }

    Maui.InfoDialog
    {
        id: _clearSiteDataDialog
        property var targetBrowser: null
        title: i18n("Clear Site Data")
        message: targetBrowser ? i18n("Clear cookies and site data for %1?", targetBrowser.url.toString()) : ""
        standardButtons: Dialog.Cancel | Dialog.Ok

        onAccepted:
        {
            if (!targetBrowser)
                return

            _surf.clearSiteCookies(targetBrowser.profile, targetBrowser.url)
            targetBrowser.runJavaScript("(function(){try{localStorage.clear();sessionStorage.clear()}catch(e){}})()")
            targetBrowser.reload()
            targetBrowser = null
        }

        onRejected: targetBrowser = null
    }

    headBar.rightContent: [
        ToolSeparator
        {
            height: Maui.Style.space.medium
            topPadding: 0
            bottomPadding: 0
        },

        Loader
        {
            asynchronous: true
            active: true
            visible: active
            sourceComponent: _browserActionButtonsComponent
        },

        ToolSeparator
        {
            height: Maui.Style.space.medium
            topPadding: 0
            bottomPadding: 0
        },

        Loader
        {
            asynchronous: true
            active: true
            visible: active
            sourceComponent: _overflowMenuComponent
        },

        Maui.WindowControls {}
    ]

    headBar.leftContent: [
        Loader
        {
            asynchronous: true
            active: true
            visible: active
            sourceComponent: _navigationControlsComponent
        },

        ToolSeparator
        {
            height: Maui.Style.space.medium
            topPadding: 0
            bottomPadding: 0
        }
    ]

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
                onTriggered: control.currentBrowser.findText(_searchField.text, WebEngineView.FindBackward)
            },

            Action
            {
                icon.name: "go-down"
                onTriggered: control.currentBrowser.findText(_searchField.text)
            }
        ]
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
            // Don't persist private-mode URLs to the closed-tabs DB.
            if (currentTab && !privateMode)
                Fiery.DBActions.pushClosedTab(
                    currentTab.urls.map(function(u) { return u.toString() })
                                   .filter(function(s) { return s.length > 0 && s !== "about:blank" }))
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
            var urls = Fiery.DBActions.popClosedTab()
            if (urls.length > 0)
            {
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
        enabled: _sideBarView.sideBar.visible
        onActivated:
        {
            _sideBarView.sideBar.close()
        }
    }

    Shortcut
    {
        sequence: "Ctrl+."
        enabled: currentBrowser !== null
        onActivated: currentBrowser.stop()
    }

    // ── Address bar ───────────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+L"
        onActivated:
        {
            if (root.isWide)
            {
                _beginAddressEditing()
            }
            else
            {
                _navigationPopup.open()
            }
        }
    }

    // ── Page interaction ──────────────────────────────────────────────────────

    Shortcut
    {
        sequence: "Ctrl+F"
        onActivated: control.searchFieldVisible = !control.searchFieldVisible
    }

    Shortcut
    {
        sequence: "Ctrl+="
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
                // Fallback for environments where Keys.onPressed does not
                // intercept Return before TextField emits accepted().
                if(text.length > 0)
                    control.openUrl(text)
                else if(_historyListView.currentItem)
                {
                    control.openUrl(_historyListView.currentItem.url)
                }

                _navigationPopup.close()
            }

            // Handle all Enter variants and Up/Down history navigation here
            // so that the key events are never forwarded to _historyListView.
            // Qt Quick's default Keys.BeforeItem priority means Keys.onPressed
            // runs before the TextField's own handling; accepting the event
            // here prevents it from reaching the list view (which would consume
            // it silently when no history item is selected).
            Keys.onPressed: (event) =>
            {
                // Up/Down: navigate history suggestion list.
                if (event.key === Qt.Key_Down) {
                    if (_historyListView.currentIndex < _historyListView.count - 1)
                        _historyListView.currentIndex++
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Up) {
                    if (_historyListView.currentIndex > -1)
                        _historyListView.currentIndex--
                    event.accepted = true
                    return
                }

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
                else
                {
                    // Plain Enter — navigate and close before the event can
                    // be forwarded to _historyListView and silently consumed.
                    if (_entryField.text.length > 0)
                        control.openUrl(_entryField.text)
                    else if (_historyListView.currentItem)
                        control.openUrl(_historyListView.currentItem.url)
                    _navigationPopup.close()
                    event.accepted = true
                }
            }
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
        overviewDebug: fieryUiDiagnostics
        readonly property real tabBarContentHeight:
            Math.max(tabBar.count > 0 && tabBar.itemAt(0) ? tabBar.itemAt(0).implicitHeight : 0,
                     Maui.Style.rowHeightAlt,
                     Maui.Style.rowHeight,
                     Maui.Style.iconSize + Maui.Style.defaultPadding * 2)
        tabBar.implicitHeight: tabBarContentHeight + tabBar.topPadding + tabBar.bottomPadding
        tabBar.topMargin: Maui.Handy.isMobile ? 0 : control._headerFootprint
        tabBar.bottomMargin: (Maui.Handy.isMobile ? control._headerFootprint : 0) + 6
        onWidthChanged: control._uiLog("public TabView widthChanged", control._uiGeometry(_browserListView))
        onHeightChanged: control._uiLog("public TabView heightChanged", control._uiGeometry(_browserListView))
        onVisibleChanged: control._uiLog("public TabView visibleChanged", control._uiGeometry(_browserListView))
        Component.onCompleted: control._uiLog("public TabView completed", control._uiGeometry(_browserListView) + " tabBar=" + control._uiGeometry(_browserListView.tabBar))
        holder.visible: count === 0
        holder.emoji: "internet-web-browser"
        holder.title: i18n("Start Browsing")
        holder.body: i18n("Enter a new URL or open a recent site.")
        holder.emojiSize: Maui.Style.iconSizes.big

        onNewTabClicked: openTab("")
        onCurrentIndexChanged:
        {
            _schedulePopupGeometryRefresh()
            control._uiLog("public TabView currentIndexChanged", "index=" + currentIndex + ", count=" + count)
        }
        onCloseTabClicked: (index) =>
        {
            var tab = _browserListView.tabAt(index)
            if (tab)
                Fiery.DBActions.pushClosedTab(
                    tab.urls.map(function(u) { return u.toString() })
                              .filter(function(s) { return s.length > 0 && s !== "about:blank" }))
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
        tabBar.topPadding: 4
        tabBar.bottomPadding: 4
        tabBar.visible: root.visibility !== Window.FullScreen
        altTabBar: Maui.Handy.isMobile
        tabBar.background: Rectangle
        {
            radius: _browserListView.tabBarMargins > 0 ? Maui.Style.radiusV : 0
            color: Maui.Theme.backgroundColor
            border.color: _browserListView.tabBarMargins > 0 ? Maui.Theme.alternateBackgroundColor : "transparent"
        }
        tabBar.leftContent: [
            ToolButton
            {
                id: _publicOverviewButton
                visible: activeView.count > 1
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Maui.Style.rowHeight
                Layout.maximumHeight: Maui.Style.rowHeight
                Layout.topMargin: 0
                Layout.bottomMargin: 0
                display: ToolButton.IconOnly
                onClicked: activeView.openOverview()
                onXChanged: control._uiLog("public overview button xChanged", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                onYChanged: control._uiLog("public overview button yChanged", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                onWidthChanged: control._uiLog("public overview button widthChanged", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                onHeightChanged: control._uiLog("public overview button heightChanged", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                onImplicitHeightChanged: control._uiLog("public overview button implicitHeightChanged", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                Component.onCompleted: {
                    control._uiLog("public overview button completed", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar))
                    Qt.callLater(function() { control._uiLog("public overview button deferred", control._uiTabGeometry(_publicOverviewButton, _browserListView.tabBar)) })
                }
                leftPadding: 6
                rightPadding: 6
                topPadding: 0
                bottomPadding: 0

                contentItem: RowLayout
                {
                    id: _publicOverviewContent
                    onWidthChanged: control._uiLog("public overview content widthChanged", control._uiGeometry(_publicOverviewContent))
                    onHeightChanged: control._uiLog("public overview content heightChanged", control._uiGeometry(_publicOverviewContent))
                    Component.onCompleted: {
                        control._uiLog("public overview content completed", control._uiTabGeometry(_publicOverviewContent, _browserListView.tabBar))
                        Qt.callLater(function() { control._uiLog("public overview content deferred", control._uiTabGeometry(_publicOverviewContent, _browserListView.tabBar)) })
                    }

                    spacing: Maui.Style.space.small

                    Item
                    {
                        Layout.alignment: Qt.AlignVCenter
                        width: Maui.Style.iconSizes.small
                        height: Maui.Style.iconSizes.small

                        Maui.Icon
                        {
                            anchors.centerIn: parent
                            width: Maui.Style.iconSizes.small
                            height: Maui.Style.iconSizes.small
                            source: "view-grid"
                            color: Maui.Theme.textColor
                        }
                    }

                    Item
                    {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: _publicBadgeRow.implicitWidth
                        id: _publicBadgeContainer
                        onWidthChanged: control._uiLog("public badge container widthChanged", control._uiGeometry(_publicBadgeContainer))
                        onHeightChanged: control._uiLog("public badge container heightChanged", control._uiGeometry(_publicBadgeContainer))
                        Component.onCompleted: {
                            control._uiLog("public badge container completed", control._uiTabGeometry(_publicBadgeContainer, _browserListView.tabBar))
                            Qt.callLater(function() { control._uiLog("public badge container deferred", control._uiTabGeometry(_publicBadgeContainer, _browserListView.tabBar)) })
                        }
                        Layout.minimumWidth: implicitWidth
                        Layout.preferredWidth: implicitWidth
                        height: Maui.Style.rowHeight

                        RowLayout
                        {
                            id: _publicBadgeRow
                            anchors.centerIn: parent
                            spacing: 0

                            ToolButton
                            {
                                Layout.alignment: Qt.AlignVCenter
                                text: activeView.count
                                display: ToolButton.TextOnly
                                font.bold: true
                                font.pointSize: Maui.Style.fontSizes.small
                                ToolTip.visible: false
                                onClicked: {}

                                background: Rectangle
                                {
                                    color: Maui.Theme.alternateBackgroundColor
                                    radius: Maui.Style.radiusV
                                }
                            }
                        }
                    }
                }

                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: i18n("Show tabs")
            },

            ToolSeparator
            {
                visible: activeView.count > 1
                height: Maui.Style.space.medium
                topPadding: 0
                bottomPadding: 0
            }
        ]

        tabBar.rightContent: [
            ToolSeparator
            {
                visible: activeView.count > 1
                height: Maui.Style.space.medium
                topPadding: 0
                bottomPadding: 0
            },

            ToolButton
            {
                icon.name: "list-add"
                display: ToolButton.IconOnly
                onClicked: openTab("")

                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: i18n("New tab")
            }
        ]
    }

    Connections
    {
        target: _browserListView.tabBar

        function logPublicTabBar(event)
        {
            control._uiLog("public TabBar " + event, control._uiGeometry(_browserListView.tabBar) + " topMargin=" + _browserListView.tabBar.topMargin)
        }

        function onXChanged() { logPublicTabBar("xChanged") }
        function onYChanged() { logPublicTabBar("yChanged") }
        function onWidthChanged() { logPublicTabBar("widthChanged") }
        function onHeightChanged() { logPublicTabBar("heightChanged") }
        function onImplicitHeightChanged() { logPublicTabBar("implicitHeightChanged") }
        function onVisibleChanged() { logPublicTabBar("visibleChanged") }
        function onPositionChanged() { logPublicTabBar("positionChanged") }
        function onTopMarginChanged() { logPublicTabBar("topMarginChanged") }
    }

    Item
    {
        id: _privateModeView
        anchors.fill: parent
        visible: privateMode


        Maui.TabView
        {
            id: _privateTabView
            anchors.fill: parent
            visible: true
            background: null
            tabBarMargins: Maui.Style.contentMargins
            overviewDebug: fieryUiDiagnostics
            readonly property real tabBarContentHeight:
                Math.max(tabBar.count > 0 && tabBar.itemAt(0) ? tabBar.itemAt(0).implicitHeight : 0,
                         Maui.Style.rowHeightAlt,
                         Maui.Style.rowHeight,
                         Maui.Style.iconSize + Maui.Style.defaultPadding * 2)
            tabBar.implicitHeight: tabBarContentHeight + tabBar.topPadding + tabBar.bottomPadding
            tabBar.topMargin: Maui.Handy.isMobile ? 0 : control._headerFootprint
            tabBar.bottomMargin: (Maui.Handy.isMobile ? control._headerFootprint : 0) + 6
            onWidthChanged: control._uiLog("private TabView widthChanged", control._uiGeometry(_privateTabView))
            onHeightChanged: control._uiLog("private TabView heightChanged", control._uiGeometry(_privateTabView))
            onVisibleChanged: control._uiLog("private TabView visibleChanged", control._uiGeometry(_privateTabView))
            Component.onCompleted: control._uiLog("private TabView completed", control._uiGeometry(_privateTabView) + " tabBar=" + control._uiGeometry(_privateTabView.tabBar))
            holder.visible: count === 0
            holder.emoji: "internet-web-browser"
            holder.title: i18n("Start Browsing")
            holder.body: i18n("Enter a new URL or open a recent site.")
            holder.emojiSize: Maui.Style.iconSizes.big

            onNewTabClicked: openTab("")
            onCurrentIndexChanged:
            {
                _schedulePopupGeometryRefresh()
                control._uiLog("private TabView currentIndexChanged", "index=" + currentIndex + ", count=" + count)
            }
            onCloseTabClicked: (index) =>
            {
                // Private tab URLs must NOT be added to the restore stack:
                // restoring them via Ctrl+Shift+T would leak private browsing history.
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
            tabBar.topPadding: 4
            tabBar.bottomPadding: 4
            tabBar.visible: root.visibility !== Window.FullScreen
            altTabBar: Maui.Handy.isMobile
            tabBar.background: Rectangle
            {
                radius: _privateTabView.tabBarMargins > 0 ? Maui.Style.radiusV : 0
                color: Maui.Theme.backgroundColor
                border.color: _privateTabView.tabBarMargins > 0 ? Maui.Theme.alternateBackgroundColor : "transparent"
            }
            tabBar.leftContent: [
                ToolButton
                {
                    id: _privateOverviewButton
                    visible: activeView.count > 1
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: Maui.Style.rowHeight
                    Layout.maximumHeight: Maui.Style.rowHeight
                    Layout.topMargin: 0
                    Layout.bottomMargin: 0
                    display: ToolButton.IconOnly
                    onClicked: activeView.openOverview()
                    onXChanged: control._uiLog("private overview button xChanged", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                    onYChanged: control._uiLog("private overview button yChanged", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                    onWidthChanged: control._uiLog("private overview button widthChanged", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                    onHeightChanged: control._uiLog("private overview button heightChanged", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                    onImplicitHeightChanged: control._uiLog("private overview button implicitHeightChanged", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                    Component.onCompleted: {
                        control._uiLog("private overview button completed", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar))
                        Qt.callLater(function() { control._uiLog("private overview button deferred", control._uiTabGeometry(_privateOverviewButton, _privateTabView.tabBar)) })
                    }
                    leftPadding: 6
                    rightPadding: 6
                    topPadding: 0
                    bottomPadding: 0

                    contentItem: RowLayout
                    {
                        id: _privateOverviewContent
                        onWidthChanged: control._uiLog("private overview content widthChanged", control._uiGeometry(_privateOverviewContent))
                        onHeightChanged: control._uiLog("private overview content heightChanged", control._uiGeometry(_privateOverviewContent))
                        Component.onCompleted: {
                            control._uiLog("private overview content completed", control._uiTabGeometry(_privateOverviewContent, _privateTabView.tabBar))
                            Qt.callLater(function() { control._uiLog("private overview content deferred", control._uiTabGeometry(_privateOverviewContent, _privateTabView.tabBar)) })
                        }

                        spacing: Maui.Style.space.small

                        Item
                        {
                            Layout.alignment: Qt.AlignVCenter
                            width: Maui.Style.iconSizes.small
                            height: Maui.Style.iconSizes.small

                            Maui.Icon
                            {
                                anchors.centerIn: parent
                                width: Maui.Style.iconSizes.small
                                height: Maui.Style.iconSizes.small
                                source: "view-grid"
                                color: Maui.Theme.textColor
                            }
                        }

                        Item
                        {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: _privateBadgeRow.implicitWidth
                            id: _privateBadgeContainer
                            onWidthChanged: control._uiLog("private badge container widthChanged", control._uiGeometry(_privateBadgeContainer))
                            onHeightChanged: control._uiLog("private badge container heightChanged", control._uiGeometry(_privateBadgeContainer))
                            Component.onCompleted: {
                                control._uiLog("private badge container completed", control._uiTabGeometry(_privateBadgeContainer, _privateTabView.tabBar))
                                Qt.callLater(function() { control._uiLog("private badge container deferred", control._uiTabGeometry(_privateBadgeContainer, _privateTabView.tabBar)) })
                            }
                            Layout.minimumWidth: implicitWidth
                            Layout.preferredWidth: implicitWidth
                            height: Maui.Style.rowHeight

                            RowLayout
                            {
                                id: _privateBadgeRow
                                anchors.centerIn: parent
                                spacing: 0

                                ToolButton
                                {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: activeView.count
                                    display: ToolButton.TextOnly
                                    font.bold: true
                                    font.pointSize: Maui.Style.fontSizes.small
                                    ToolTip.visible: false
                                    onClicked: {}

                                    background: Rectangle
                                    {
                                        color: Maui.Theme.alternateBackgroundColor
                                        radius: Maui.Style.radiusV
                                    }
                                }
                            }
                        }
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: i18n("Show tabs")
                },

                ToolSeparator
                {
                    visible: activeView.count > 1
                    height: Maui.Style.space.medium
                    topPadding: 0
                    bottomPadding: 0
                }
            ]

            tabBar.rightContent: [
                ToolSeparator
                {
                    visible: activeView.count > 1
                    height: Maui.Style.space.medium
                    topPadding: 0
                    bottomPadding: 0
                },

                ToolButton
                {
                    icon.name: "list-add"
                    display: ToolButton.IconOnly
                    onClicked: openTab("")

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: i18n("New tab")
                }
            ]
        }
    }

    Connections
    {
        target: _privateTabView.tabBar

        function logPrivateTabBar(event)
        {
            control._uiLog("private TabBar " + event, control._uiGeometry(_privateTabView.tabBar) + " topMargin=" + _privateTabView.tabBar.topMargin)
        }

        function onXChanged() { logPrivateTabBar("xChanged") }
        function onYChanged() { logPrivateTabBar("yChanged") }
        function onWidthChanged() { logPrivateTabBar("widthChanged") }
        function onHeightChanged() { logPrivateTabBar("heightChanged") }
        function onImplicitHeightChanged() { logPrivateTabBar("implicitHeightChanged") }
        function onVisibleChanged() { logPrivateTabBar("visibleChanged") }
        function onPositionChanged() { logPrivateTabBar("positionChanged") }
        function onTopMarginChanged() { logPrivateTabBar("topMarginChanged") }
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

    WebEngineProfilePrototype
    {
        id: _incognitoProfilePrototype
    }

    readonly property WebEngineProfile _incognitoProfile: _incognitoProfilePrototype.instance()

    Component.onCompleted:
    {
        _syncOverviewHeadBar()

        if (appSettings.sessionUrlsJson.length > 0)
        {
            var entries = root.decodeSessionUrlsJson(appSettings.sessionUrlsJson)
            if (entries.length > 0)
            {
                // Cap at 50 tabs to prevent a crafted session from opening hundreds of tabs.
                var slice = entries.slice(0, 50)
                var opened = 0
                slice.forEach(function(entry) {
                    if (!entry) return
                    // Format v2: {urls: [...], pinned}  — one entry per tab, split included.
                    // Format v1: {url, pinned}          — one entry per pane (legacy).
                    // Format v0: plain string           — bare URL (oldest).
                    var urls, pinned
                    if (typeof entry === "string") {
                        urls   = [entry]
                        pinned = false
                    } else if (Array.isArray(entry.urls)) {
                        urls   = entry.urls
                        pinned = entry.pinned === true
                    } else {
                        urls   = [entry.url || ""]
                        pinned = entry.pinned === true
                    }
                    var primary = urls[0]
                    if (typeof primary !== "string" || primary.length === 0 || primary.length > 2048) return
                    if (!appSettings.restoreSession && !pinned)
                        return

                    openTab(primary)
                    opened++

                    if (pinned) {
                        var tab = _browserListView.contentModel.get(_browserListView.count - 1)
                        if (tab) tab.pinned = true
                    }
                    // Restore split-view pane if one was saved.
                    var secondary = urls[1]
                    if (typeof secondary === "string" && secondary.length > 0 && secondary.length <= 2048)
                        openSplit(secondary)
                })
                if (opened > 0)
                    return
            }
        }

        openTab(appSettings.homePage)
    }

    Component
    {
        id: _browserComponent

        BrowserLayout
        {
            popupGeometryNudge: control._popupGeometryNudge
            overviewMode: control.activeView.overviewMode
        }
    }

    Component
    {
        id: _navigationControlsComponent

        Row
        {
            id: _navigationControlsRow
            spacing: control.headBar.spacing

            onWidthChanged: control._uiLog("navigationControls widthChanged", control._uiGeometry(_navigationControlsRow))
            onHeightChanged: control._uiLog("navigationControls heightChanged", control._uiGeometry(_navigationControlsRow))
            Component.onCompleted: control._uiLog("navigationControls completed", control._uiGeometry(_navigationControlsRow))

            ToolButton
            {
                id: _sidebarButton
                icon.name: _sideBarView.sideBar.visible ? "sidebar-collapse" : "sidebar-expand"
                onWidthChanged: control._uiLog("sidebarButton widthChanged", control._uiGeometry(_sidebarButton))
                onHeightChanged: control._uiLog("sidebarButton heightChanged", control._uiGeometry(_sidebarButton))
                onVisibleChanged: control._uiLog("sidebarButton visibleChanged", control._uiGeometry(_sidebarButton))
                onEnabledChanged: control._uiLog("sidebarButton enabledChanged", "enabled=" + enabled + " " + control._uiGeometry(_sidebarButton))
                onClicked:
                {
                    control._uiLog("sidebarButton clicked", "checked=" + checked + " " + control._uiGeometry(_sidebarButton))
                    _sideBarView.sideBar.toggle()
                }
                checked: _sideBarView.sideBar.visible
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: i18n("Toggle sidebar")
            }

            ToolSeparator
            {
                orientation: Qt.Vertical
                height: Maui.Style.space.medium
                anchors.verticalCenter: parent.verticalCenter
                topPadding: 0
                bottomPadding: 0
            }

            Maui.ToolActions
            {
                id: _navigationActions
                onWidthChanged: control._uiLog("navigationActions widthChanged", control._uiGeometry(_navigationActions))
                onHeightChanged: control._uiLog("navigationActions heightChanged", control._uiGeometry(_navigationActions))
                onVisibleChanged: control._uiLog("navigationActions visibleChanged", control._uiGeometry(_navigationActions))
                Component.onCompleted: control._uiLog("navigationActions completed", control._uiGeometry(_navigationActions))
                autoExclusive: false
                checkable: false
                display: ToolButton.IconOnly

                Action
                {
                    text: i18n("Previous")
                    icon.name: "go-previous"
                    enabled: currentBrowser !== null && currentBrowser.canGoBack
                    onEnabledChanged: function(enabled) { control._uiLog("backButton enabledChanged", "enabled=" + enabled + " canGoBack=" + (currentBrowser ? currentBrowser.canGoBack : false)) }
                    onTriggered:
                    {
                        control._uiLog("backButton triggered", "canGoBack=" + (currentBrowser ? currentBrowser.canGoBack : false))
                        currentBrowser.goBack()
                    }
                }

                Action
                {
                    text: i18n("Next")
                    icon.name: "go-next"
                    enabled: currentBrowser !== null && currentBrowser.canGoForward
                    onEnabledChanged: function(enabled) { control._uiLog("forwardButton enabledChanged", "enabled=" + enabled + " canGoForward=" + (currentBrowser ? currentBrowser.canGoForward : false)) }
                    onTriggered:
                    {
                        control._uiLog("forwardButton triggered", "canGoForward=" + (currentBrowser ? currentBrowser.canGoForward : false))
                        currentBrowser.goForward()
                    }
                }
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
        id: _browserActionButtonsComponent

        Row
        {
            id: _browserActionsRow
            spacing: control.headBar.spacing

            onWidthChanged: control._uiLog("browserActions widthChanged", control._uiGeometry(_browserActionsRow))
            onHeightChanged: control._uiLog("browserActions heightChanged", control._uiGeometry(_browserActionsRow))
            Component.onCompleted: control._uiLog("browserActions completed", control._uiGeometry(_browserActionsRow))

            ToolButton
            {
                id: _reloadButton
                icon.name: "view-refresh"
                onWidthChanged: control._uiLog("reloadButton widthChanged", control._uiGeometry(_reloadButton))
                onHeightChanged: control._uiLog("reloadButton heightChanged", control._uiGeometry(_reloadButton))
                onVisibleChanged: control._uiLog("reloadButton visibleChanged", control._uiGeometry(_reloadButton))
                onClicked:
                {
                    control._uiLog("reloadButton clicked", control._uiGeometry(_reloadButton))
                    currentBrowser.reload()
                }
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: i18n("Reload Page")
            }

            ToolButton
            {
                id: _splitButton
                icon.name: currentTab && currentTab.count === 2
                            ? (currentTab.activeSplitIndex === 0 ? "view-right-close" : "view-split-right-left")
                            : "view-split-left-right"
                onWidthChanged: control._uiLog("splitButton widthChanged", control._uiGeometry(_splitButton))
                onHeightChanged: control._uiLog("splitButton heightChanged", control._uiGeometry(_splitButton))
                onVisibleChanged: control._uiLog("splitButton visibleChanged", control._uiGeometry(_splitButton))
                onClicked:
                {
                    control._uiLog("splitButton clicked", "split=" + (currentTab && currentTab.count === 2) + " " + control._uiGeometry(_splitButton))
                    currentTab && currentTab.count === 2 ? currentTab.pop() : control.openSplit("")
                }
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: currentTab && currentTab.count === 2
                              ? (currentTab.activeSplitIndex === 0 ? i18n("Close Right Split") : i18n("Close Left Split"))
                              : i18n("Split View")
            }
        }
    }

    Component
    {
        id: _overflowMenuComponent

        Maui.ToolButtonMenu
        {
                icon.name: "overflow-menu"

                MenuItem
                {
                    text: privateMode ? i18n("Exit Private Browsing") : i18n("Private Browsing")
                    checked: privateMode
                    onTriggered:
                    {
                        privateMode = !privateMode
                        if (privateMode && _privateTabView.count === 0)
                            openTab("")
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
                    text: i18n("Shortcuts")
                    icon.name: "configure-shortcuts"
                    onTriggered:
                    {
                        var dialog = _shortcutsDialogComponent.createObject(control)
                        dialog.open()
                    }
                }

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

    Component
    {
        id: _shortcutsDialogComponent

        ShortcutsDialog
        {
            onClosed: destroy()
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
        const s = path.toString().trim().toLowerCase()
        if (s.startsWith("javascript:") || s.startsWith("data:"))
            return

        if(currentTab.count === 1)
        {
            currentTab.split(path)
            return
        }

        // Split already open — switch to the inactive pane and navigate there
        // so the URL loads in the other half rather than the one already active.
        var inactiveIndex = currentTab.activeSplitIndex === 0 ? 1 : 0
        currentTab.currentIndex = inactiveIndex
        openUrl(path)
    }

    function collectSessionUrls(onlyPinned)
    {
        var tabs = []
        for (var i = 0; i < _browserListView.count; i++)
        {
            const tab = _browserListView.contentModel.get(i)
            if (!tab) continue

            // Collect all pane URLs for this tab (1 for normal, 2 for split view).
            var urls = []
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
            // Store as one entry per tab so split state is preserved on restore.
            if (urls.length > 0 && (!onlyPinned || tab.pinned))
                tabs.push({urls: urls, pinned: tab.pinned || false})
        }
        return tabs
    }

    function openUrl(path)
    {
        if(!control.currentBrowser)
            return

        const pathStr = path.toString().trim()

        // Block dangerous pseudo-protocols and data URIs typed into the address bar.
        const lower = pathStr.toLowerCase()
        if (lower.startsWith("javascript:") || lower.startsWith("data:"))
            return

        if(_surf.isValidUrl(path))
        {
            if(_surf.hasProtocol(path))
                control.currentBrowser.url = path
            else
                control.currentBrowser.url = 'https://' + path
        } else
        {
            // Validate the configured search engine URL starts with https:// so a
            // misconfigured or tampered setting cannot become a javascript: navigation.
            const engine = appSettings.searchEnginePage.toString()
            if (!engine.toLowerCase().startsWith("https://"))
                return
            control.currentBrowser.url = engine + encodeURIComponent(pathStr)
        }

        control.currentTab.forceActiveFocus()
    }

}
