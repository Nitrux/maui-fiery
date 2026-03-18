import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui

import org.maui.fiery as Fiery

Maui.Page
{
    id: control

    background: null
    headBar.middleContent: Maui.SearchField
    {
        id: _entryField
        Layout.fillWidth: true
        Layout.maximumWidth: 500
        Layout.alignment: Qt.AlignCenter
    }

    Maui.ListBrowser
    {
        id: _listView
        anchors.fill: parent

        holder.visible: count === 0
        holder.emoji: "bookmarks"
        holder.title: i18n("No Bookmarks")
        holder.body: i18n("Bookmarked pages will appear here.")

        model: Maui.BaseModel
        {
            list: Fiery.Bookmarks
            filter: _entryField.text
            sort: "adddate"
            sortOrder: Qt.DescendingOrder
            recursiveFilteringEnabled: true
            sortCaseSensitivity: Qt.CaseInsensitive
            filterCaseSensitivity: Qt.CaseInsensitive
        }

        delegate:  Maui.ListBrowserDelegate
        {
            width: ListView.view.width
            label1.text: model.title
            tooltipText: model.url
            imageSource: model.icon.replace("image://favicon/", "")
            iconSizeHint: Maui.Style.iconSizes.medium
            onClicked:
            {
                _listView.currentIndex = index
                _browserView.openTab(model.url)
            }
        }

    }
}
