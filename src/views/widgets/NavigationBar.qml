import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

BrowserTabViewButton
{
    id: control

    property int position: control.TabBar.position

    // The Repeater in TabView.qml injects `index` as a context property into
    // each delegate.  It is more reliable than mindex (= TabBar.index) because
    // QQC TabBar's stackBefore/stackAfter reordering failures corrupt TabBar.index,
    // causing mindex to point at the wrong slot after pin/unpin.
    delegateIndex: (typeof index != "undefined" && index >= 0) ? index : -1

    readonly property WebEngineView webView:
    {
        var item = control.tabView.contentModel.get(control.mindex)
        if (!item || !item.browser) return null
        return item.browser.webView
    }

    readonly property bool _pinned:
    {
        var item = control.tabView.contentModel.get(control.mindex)
        return item ? (item.pinned || false) : false
    }

    readonly property bool _audible:  webView !== null && (webView.recentlyAudible || webView.audioMuted)
    readonly property bool _sleeping: webView !== null && webView.lifecycleState === WebEngineView.LifecycleState.Discarded
    readonly property real _pinnedTabWidth: control.height + Maui.Style.space.medium

    // Hide close button on pinned tabs, matching browser convention.
    closeButtonVisible: !_pinned

    // Maui.TabButton derives its intrinsic width from an internal RowLayout.
    // When a tab is pinned, its title, base icon and close button all vanish,
    // so the layout can collapse after a close and the remaining pinned tabs
    // get packed on top of each other. Keep a transparent spacer in the
    // layout so pinned tabs still report a stable footprint to the TabBar.
    leftContent: Item
    {
        width: control._pinned ? control._pinnedTabWidth : 0
        height: 1
        opacity: 0
        enabled: false
    }

    // Per-tab status indicators: sleep (moon) and audio (speaker).
    rightContent: Row
    {
        spacing: 2

        // Sleep indicator — visible when the tab has been discarded to save memory.
        ToolButton
        {
            visible: control._sleeping
            height: 16
            width:  16
            padding: 0
            enabled: false   // informational only; clicking the tab wakes it
            contentItem: Text
            {
                text: "\uf186"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                color: Maui.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            ToolTip.text: i18n("Tab is sleeping")
            ToolTip.visible: hovered
            ToolTip.delay: 1000
        }

        // Speaker / mute indicator — visible whenever the tab is producing audio
        // or has been explicitly muted. Click toggles mute.
        ToolButton
        {
            visible: control._audible && !control._pinned
            height: 16
            width:  16
            padding: 0
            contentItem: Text
            {
                text: (control.webView && control.webView.audioMuted) ? "\uf026" : "\uf028"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                color: Maui.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: if (control.webView) control.webView.audioMuted = !control.webView.audioMuted
            ToolTip.text: (control.webView && control.webView.audioMuted) ? i18n("Unmute tab") : i18n("Mute tab")
            ToolTip.visible: hovered
            ToolTip.delay: 1000
        }
    }

    // Override text to empty when pinned; use tabInfo.title otherwise.
    // A direct binding is used instead of a Binding element to avoid the
    // binding-restoration failure across component boundaries that would
    // collapse the property to its default when unpinning.
    text: control._pinned ? "" : (tabInfo ? tabInfo.title : "")

    // Keep width fixed for pinned (icon-only square) tabs.
    // A direct binding is used instead of a Binding element for the same
    // reason: when the Binding element deactivated on unpin, the base-class
    // width expression failed to restore and the button collapsed to 0px,
    // causing all tabs to render on top of each other ("joined").
    width: control._pinned
        ? (control.height + Maui.Style.space.medium)
        : (control.tabView.mobile ? ListView.view.width : Math.max(160, Math.min(260, implicitWidth)))

    onClicked:
    {
        if (control.mindex === control.tabView.currentIndex)
            openEditMode()
        else
            control.tabView.setCurrentIndex(control.mindex)
    }

    onRightClicked: _tabMenu.show()
    onCloseClicked: control.tabView.closeTabClicked(control.mindex)

    // For pinned tabs the internal IconLabel GridLayout leaves a phantom
    // fillWidth label column that shoves the icon to the left even when the
    // label is invisible.  Suppress the icon entirely and render it ourselves
    // via underlayContent so we can anchor it to the true centre.
    icon.source: control._pinned ? "" : (webView ? webView.icon : "")
    icon.color: "transparent"

    // Both pinned-tab overlays live inside underlayContent so their parent is
    // _underlay (which fills the full button).  Direct unnamed children would
    // go to _content.data (the IconLabel) via TabButton's default alias and
    // inherit its shifted geometry, causing mis-centering and pin/unpin drift.
    underlayContent: Item
    {
        anchors.fill: parent

        // Favicon — shown when pinned and not audible.
        Maui.Icon
        {
            visible: control._pinned && !control._audible && webView !== null
            source: webView ? webView.icon : ""
            color: "transparent"
            width: 16
            height: 16
            anchors.centerIn: parent
        }

        // Audio glyph — replaces the favicon when pinned and audible/muted.
        Item
        {
            visible: control._pinned && control._audible
            anchors.fill: parent

            Text
            {
                anchors.centerIn: parent
                text: (control.webView && control.webView.audioMuted) ? "\uf026" : "\uf028"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                color: Maui.Theme.textColor
            }

            ToolTip.text: (control.webView && control.webView.audioMuted) ? i18n("Unmute tab") : i18n("Mute tab")
            ToolTip.visible: _audioOverlayArea.containsMouse
            ToolTip.delay: 1000

            MouseArea
            {
                id: _audioOverlayArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (control.webView) control.webView.audioMuted = !control.webView.audioMuted
            }
        }
    }

    // Per-tab context menu.  Defined here so we have full control over each
    // item's visibility — the TabView's menuActions machinery only supports
    // Action objects which have no visible property.
    Maui.ContextualMenu
    {
        id: _tabMenu

        MenuItem
        {
            text: i18n("Detach")
            onTriggered:
            {
                var urls = control.tabView.tabAt(control.mindex).urls
                newWindow(urls)
                control.tabView.closeTab(control.mindex)
            }
        }

        MenuItem
        {
            text: control._pinned ? i18n("Unpin") : i18n("Pin")
            onTriggered:
            {
                var tab = control.tabView.tabAt(control.mindex)
                tab.pinned = !tab.pinned
            }
        }

        MenuItem
        {
            visible: control._audible
            height: visible ? implicitHeight : 0
            text: (control.webView && control.webView.audioMuted) ? i18n("Unmute Tab") : i18n("Mute Tab")
            icon.name: (control.webView && control.webView.audioMuted) ? "audio-volume-muted" : "audio-volume-high"
            onTriggered: if (control.webView) control.webView.audioMuted = !control.webView.audioMuted
        }

        // Close is only useful for pinned tabs: unpinned tabs already have a
        // visible close button on the tab itself.
        MenuItem
        {
            text: i18n("Close")
            // Intentionally no icon.name — requirement: Close must have no icon.
            visible: control._pinned
            height: visible ? implicitHeight : 0
            onTriggered: control.tabView.closeTab(control.mindex)
        }
    }

}
