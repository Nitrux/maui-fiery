import QtQuick.Controls

import org.mauikit.controls as Maui

Maui.SettingsDialog
{
    id: control

    Maui.Controls.title: i18n("Shortcuts")

    Maui.SectionGroup
    {
        title: i18n("Tabs")
        description: i18n("Manage tabs, windows, and browsing sessions from the keyboard.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Open Navigation")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "L" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("New Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "T" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Close Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "W" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Reopen Closed Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Shift" }
                Action { text: "T" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Next Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Tab" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Previous Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Shift" }
                Action { text: "Tab" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Jump to Tab")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "1-9" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("New Window")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "N" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Toggle Private Browsing")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Shift" }
                Action { text: "N" }
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Navigation")
        description: i18n("Control page loading, history, and browser views.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Reload Page")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "R" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Hard Reload")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Shift" }
                Action { text: "R" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Stop Loading")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Esc" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Back")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Alt" }
                Action { text: "Left" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Forward")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Alt" }
                Action { text: "Right" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Find In Page")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "F" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("View Page Source")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "U" }
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Page")
        description: i18n("Save, bookmark, zoom, and open browser panels.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Bookmark Page")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "D" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Downloads")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "J" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("History")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "H" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Save Page")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "S" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Zoom In")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "=" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Zoom Out")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "-" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Reset Zoom")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "0" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Toggle Full Screen")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "F11" }
            }
        }
    }
}
