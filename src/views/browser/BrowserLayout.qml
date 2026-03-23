import QtQuick
import QtQuick.Controls
import QtWebEngine

import org.mauikit.controls as Maui

Item
{
    id: control

    Maui.Controls.title: title
    Maui.Controls.toolTipText: currentItem.url
    Maui.Controls.color: browserProfile.offTheRecord ? Maui.Theme.highlightColor : ""

    property url url
    property bool pinned: false
    property WebEngineProfile browserProfile: root.profile

    property alias currentIndex : _splitView.currentIndex
    property alias orientation : _splitView.orientation

    readonly property alias count : _splitView.count
    readonly property alias currentItem : _splitView.currentItem
    readonly property alias model : _splitView.contentModel
    readonly property string title : count === 2 ?  model.get(0).title + "  -  " + model.get(1).title : currentItem.title
    readonly property var urls : count === 2 ?  [model.get(0).url,  model.get(1).url] : [currentItem.url]

    readonly property alias browser : _splitView.currentItem

    Keys.enabled: true
    Keys.onPressed: (event) =>
                    {
                        if(event.key === Qt.Key_F3)
                        {
                            if(control.count === 2)
                            {
                                pop()
                                return
                            }//close the inactive split

                            split("")
                            event.accepted = true
                        }

                    }

    Maui.SplitView
    {
        id: _splitView

        anchors.fill: parent
        orientation: Qt.Horizontal
        background: null

        Component.onCompleted: split(control.url)
    }

    Component
    {
        id: _browserComponent
        Browser
        {

        }
    }

    function split(path)
    {
        if(_splitView.count === 2)
        {
            return
        }

        _splitView.addSplit(_browserComponent, {'url': path, 'browserProfile': control.browserProfile})
    }

    function pop()
    {
        if(_splitView.count === 1)
        {
            return //can not pop all the browsers, leave at leats 1
        }

        closeSplit(_splitView.currentIndex === 1 ? 0 : 1)
    }

    function closeSplit(index)
    {
        if(index >= _splitView.count)
        {
            return
        }

        destroyItem(index)
    }

    function destroyItem(index) //destroys a split view without warning
    {
        _splitView.closeSplit(index)
    }
}


