import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

Maui.TabViewButton
{
    id: control

    property int position: control.TabBar.position

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

    // Hide close button on pinned tabs, matching browser convention.
    closeButtonVisible: !_pinned

    // Override text to empty only when pinned; let the base class binding
    // handle the non-pinned case so tabInfo is never accessed from here.
    Binding
    {
        target: control
        property: "text"
        value: ""
        when: control._pinned
    }

    // Keep width fixed for pinned (icon-only square) and delegate to the
    // base formula otherwise. Avoids accessing ListView.view which is null
    // when the tab bar is not inside a ListView.
    width: _pinned
           ? implicitHeight + Maui.Style.space.medium
           : Math.max(160, Math.min(260, implicitWidth))

    background: Rectangle
    {
        color: control.checked
               ? Maui.Theme.alternateBackgroundColor
               : (control.hovered || control.pressed ? Maui.Theme.hoverColor : "transparent")
        radius: Maui.Style.radiusV
    }

    onClicked:
    {
        if (control.mindex === control.tabView.currentIndex)
            openEditMode()
        else
            control.tabView.setCurrentIndex(control.mindex)
    }

    onRightClicked: _tabMenu.show()
    onCloseClicked: control.tabView.closeTabClicked(control.mindex)

    icon.source: webView ? webView.icon : ""
    icon.color: "transparent"

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

    Maui.ProgressIndicator
    {
        id: _progress
        width: parent.width
        anchors.bottom: parent.bottom
        visible: webView ? webView.loading : false
    }
}
