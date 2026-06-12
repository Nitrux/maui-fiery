import QtQuick
import QtQml

import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui

/**
 * @inherit TabButton
 * @brief A TabButton crafted to be use along with the MauiKit TabView.
 *
 * This control only adds some extra functionality to integrate well with MauiKit TabView. If you consider changing the tab button of the TabView for a custom one, use this as the base.
 *
 * This control adds the DnD features, and integrates with the attached Controls metadata properties.
 */
BrowserTabButton
{
    id: control

    autoExclusive: true

    /**
     * @brief The index of this tab button in the TabBar
     */
    property int delegateIndex: -1

    readonly property int mindex :
        ((typeof control.TabBar.index !== "undefined" && control.TabBar.index >= 0)
            ? control.TabBar.index
            : (control.delegateIndex >= 0
                ? control.delegateIndex
                : ((typeof index !== "undefined" && index >= 0) ? index : -1)))

    /**
     * @brief The TabView to which this tab button belongs to.
     * By default this is set to its parent.
     * @warning When creating a custom tab button for the TabView, you might need to bind this to the TabView ID.
     */
    property Item tabView : control.parent
    // Forces reevaluation of model-derived bindings after tab moves.
    readonly property int _modelPulse: control.tabView ? (control.tabView.currentIndex + control.tabView.count) : 0

    /**
     * @brief The object map containing information about this tab.
     * The information was provided using the Controls metadata attached properties.
     * @see Controls
     */
    readonly property var tabInfo:
    {
        const _pulse = control._modelPulse
        const item = control.tabView && control.tabView.contentModel ? control.tabView.contentModel.get(mindex) : null
        return item ? item.Maui.Controls : ({})
    }

    /**
     * @brief The color to be used in a bottom strip.
     * By default this checks for the `Controls.color` attached property, if it has not been set, it fallbacks to being transparent.
     */
    property color color : tabInfo.color ? tabInfo.color : "transparent"

    width: control.tabView.mobile ? ListView.view.width : Math.max(160, Math.min(260, implicitWidth))

    checked: control.mindex === control.tabView.currentIndex
    text: tabInfo.title

    icon.name: tabInfo.iconName

    Maui.Controls.badgeText: tabInfo.badgeText
    Maui.Controls.status: tabInfo.status    

    ToolTip.delay: 1000
    ToolTip.timeout: 5000
    ToolTip.visible: control.hovered && !Maui.Handy.isMobile && ToolTip.text.length
    ToolTip.text: tabInfo.toolTipText

    Drag.source: control
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.dragType: Drag.Internal
    Drag.proposedAction: Qt.IgnoreAction

    Rectangle
    {
        parent: control.background
        color: control.color
        height: control.color.a > 0 ? 1 : 2
        width: parent.width*0.9
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
    }

    MouseArea
    {
        id: dragArea
        anchors.fill: parent
        enabled: !Maui.Handy.isMobile && control.tabView.count > 1

        cursorShape: drag.active ? Qt.OpenHandCursor : undefined

        drag.target: this
        drag.axis: Drag.XAxis

        onClicked: (mouse) =>
        {
            if(mouse.button === Qt.RightButton)
            {
                control.rightClicked(mouse)
                return
            }
            control.clicked()
        }

        onPositionChanged:
        {
            control.grabToImage(function(result)
            {
                control.Drag.imageSource = result.url;
            })
        }
    }

    Timer
    {
        id: _dropAreaTimer
        interval: 250
        onTriggered:
        {
            if(_dropArea.containsDrag && control.mindex >= 0)
            {
                control.tabView.setCurrentIndex(mindex)
            }
        }
    }

    DropArea
    {
        id: _dropArea
        anchors.fill: parent
        onDropped: (drop) =>
        {
            if(!drop.source)
                return

                const from = drop.source.mindex
                const to = control.mindex

                if (from < 0 || to < 0 || from >= control.tabView.count || to >= control.tabView.count || to === from)
                {
                    return
                }
                control.tabView.moveTab(from , to)
        }

        onEntered: (drag) =>
        {
            if (drag.source == null || drag.source.mindex < 0)
                return

            _dropAreaTimer.restart()
        }

        onExited:
        {
            _dropAreaTimer.stop()
        }
    }
}
