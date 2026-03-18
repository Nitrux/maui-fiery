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

    text: control.tabView.contentModel.get(control.mindex).title

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
