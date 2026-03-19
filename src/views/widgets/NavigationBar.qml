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

    readonly property WebEngineView webView : control.tabView.contentModel.get(control.mindex).browser.webView
    readonly property bool _pinned: control.tabView.contentModel.get(control.mindex).pinned

    text: _pinned ? "" : control.tabView.contentModel.get(control.mindex).title

    width: control.tabView.mobile
           ? ListView.view.width
           : (_pinned ? implicitHeight + Maui.Style.space.medium
                      : Math.max(160, Math.min(260, implicitWidth)))

    background: Rectangle
    {
        color: control.checked
               ? Maui.Theme.alternateBackgroundColor
               : (control.hovered || control.pressed ? Maui.Theme.hoverColor : "transparent")
        radius: Maui.Style.radiusV
    }

    onClicked:
    {
       if(control.mindex === control.tabView.currentIndex)
       {
          openEditMode()
       }else
       {
           control.tabView.setCurrentIndex(control.mindex)
       }
    }

    onRightClicked:
    {
        control.tabView.openTabMenu(control.mindex)
    }

    onCloseClicked:
    {
        control.tabView.closeTabClicked(control.mindex)
    }

    icon.source: control.webView.icon
    icon.color: "transparent"

    Maui.ProgressIndicator
    {
        id: _progress
        width: parent.width
        anchors.bottom: parent.bottom
        visible: webView.loading

    }
}
