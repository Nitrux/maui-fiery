import QtQuick
import QtQuick.Controls
import QtWebEngine

import org.mauikit.controls as Maui

Item
{
    id: control

    Maui.Controls.title: title
    Maui.Controls.toolTipText: currentItem.url
    Maui.Controls.color: browserProfile.offTheRecord ? Maui.Theme.visitedLinkColor : ""

    property url url
    property bool pinned: false
    property WebEngineProfile browserProfile: root.profile
    property int popupGeometryNudge: 0
    property bool overviewMode: false

    property alias currentIndex : _splitView.currentIndex
    property alias orientation : _splitView.orientation
    readonly property int activeSplitIndex:
    {
        for (var i = 0; i < _splitView.count; ++i)
        {
            const item = _splitView.contentModel.get(i)
            if (item && item.webView && item.webView.activeFocus)
                return i
        }

        return Math.max(0, _splitView.currentIndex)
    }

    readonly property alias count : _splitView.count
    readonly property alias currentItem : _splitView.currentItem
    readonly property alias model : _splitView.contentModel
    readonly property string title : currentItem ? currentItem.title : ""
    readonly property var urls : count === 2 ?  [model.get(0).url,  model.get(1).url] : [currentItem.url]

    readonly property alias browser : _splitView.currentItem
    readonly property url faviconSource: currentItem ? currentItem.faviconSource : ""
    property url previewSource: currentItem ? currentItem.previewSource : ""

    function capturePreview()
    {
        if (currentItem && typeof currentItem.capturePreview === "function")
            currentItem.capturePreview()
    }

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
        anchors.bottomMargin: control.popupGeometryNudge
        orientation: Qt.Horizontal
        background: null

        Component.onCompleted: split(control.url)
    }

    Component
    {
        id: _browserComponent
        Browser
        {
            overviewMode: control.overviewMode
            splitView: _splitView
        }
    }

    function _syncSplitIndices()
    {
        for (var i = 0; i < _splitView.count; ++i)
        {
            const item = _splitView.contentModel.get(i)
            if (item)
                item.splitIndex = i
        }
    }

    function split(path)
    {
        if(_splitView.count === 2)
        {
            return
        }

        _splitView.addSplit(_browserComponent, {'url': path, 'browserProfile': control.browserProfile})
        _syncSplitIndices()
    }

    function pop()
    {
        if(_splitView.count === 1)
        {
            return //can not pop all the browsers, leave at leats 1
        }

        closeSplit(control.activeSplitIndex === 1 ? 0 : 1)
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
        if (_splitView.count === 1 || index < 0 || index >= _splitView.count)
            return

        const item = _splitView.takeItem(index)
        if (!item)
            return

        if (item.webView)
        {
            item.webView.audioMuted = true
            item.webView.stop()
            item.webView.runJavaScript(
                "(function(){Array.from(document.querySelectorAll(\"audio,video\")).forEach(function(media){try{media.pause();}catch(e){}});})()")
            item.webView.lifecycleState = 2 // WebEngineView.Discarded
        }

        item.destroy()
        _syncSplitIndices()
        _splitView.currentIndex = Math.min(_splitView.currentIndex, _splitView.count - 1)
    }
}

