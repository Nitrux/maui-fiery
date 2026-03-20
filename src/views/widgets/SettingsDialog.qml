import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB
import org.maui.fiery as Fiery

Maui.SettingsDialog
{
    id: control

    Maui.SectionGroup
    {
        title: i18n("Navigation")
        description: i18n("Configure the app basic navigation features.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Restore Session")
            label2.text: i18n("Open previous tabs on launch.")

            Switch
            {
                Layout.fillHeight: true
                checkable: true
                checked: appSettings.restoreSession
                onToggled: appSettings.restoreSession = !appSettings.restoreSession
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Switch to New Tab")
            label2.text: i18n("Automatically focus a tab when it is opened.")

            Switch
            {
                Layout.fillHeight: true
                checkable: true
                checked: appSettings.switchToTab
                onToggled: appSettings.switchToTab = !appSettings.switchToTab
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Load Images")
            label2.text: i18n("Automatically load images on web pages.")

            Switch
            {
                Layout.fillHeight: true
                checkable: true
                checked: appSettings.autoLoadImages
                onToggled: appSettings.autoLoadImages = !appSettings.autoLoadImages
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Load Favicons")
            label2.text: i18n("Automatically load site icons for tabs.")

            Switch
            {
                Layout.fillHeight: true
                checkable: true
                checked: appSettings.autoLoadIconsForPage
                onToggled: appSettings.autoLoadIconsForPage = !appSettings.autoLoadIconsForPage
            }
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("General")
        label2.text: i18n("Configure home page, search engine, and downloads.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_generalComponent)
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("Features")
        label2.text: i18n("Configure browser features and media behaviour.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_featuresComponent)
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("JavaScript")
        label2.text: i18n("Configure JavaScript behaviour.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_jsComponent)
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("Permissions")
        label2.text: i18n("Control which features websites are allowed to use.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_permissionsComponent)
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("Privacy & Security")
        label2.text: i18n("Ad blocker, tracking, and data options.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_privacyComponent)
        }
    }

    // ── General ─────────────────────────────────────────────────────────────

    Component
    {
        id: _generalComponent

        Maui.SettingsPage
        {
            title: i18n("General")

            Maui.SectionItem
            {
                label1.text: i18n("Home Page")
                label2.text: i18n("Page loaded on startup and for new tabs.")

                TextField
                {
                    Layout.fillWidth: true
                    text: appSettings.homePage
                    onEditingFinished: appSettings.homePage = text
                }
            }

            Maui.SectionItem
            {
                label1.text: i18n("Search Engine")
                label2.text: i18n("Engine used when entering a plain query.")

                TextField
                {
                    Layout.fillWidth: true
                    text: appSettings.searchEnginePage
                    onEditingFinished: appSettings.searchEnginePage = text
                }
            }

            Maui.SectionItem
            {
                label1.text: i18n("User Agent")
                label2.text: i18n("Override the browser identity string sent to websites. Leave blank to use the default.")

                TextField
                {
                    Layout.fillWidth: true
                    placeholderText: i18n("Default")
                    text: appSettings.customUserAgent
                    onEditingFinished: appSettings.customUserAgent = text
                }
            }

            Maui.SectionGroup
            {
                title: i18n("Downloads")

                Maui.SectionItem
                {
                    label1.text: i18n("Downloads Folder")
                    label2.text: i18n("Where downloaded files are saved.")

                    TextField
                    {
                        id: _downloadsPathField
                        Layout.fillWidth: true
                        text: appSettings.downloadsPath
                        onEditingFinished: appSettings.downloadsPath = text
                    }

                    ToolButton
                    {
                        icon.name: "folder-open"
                        onClicked: _folderDialog.open()
                    }

                    FB.FileDialog
                    {
                        id: _folderDialog
                        mode: FB.FileDialog.Dirs
                        onFinished: function(paths)
                        {
                            if(paths.length > 0)
                            {
                                const path = paths[0].toString().replace("file://", "")
                                appSettings.downloadsPath = path
                                _downloadsPathField.text = path
                            }
                        }
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Auto Save")
                    label2.text: i18n("Download files without asking each time.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.autoSave
                        onToggled: appSettings.autoSave = !appSettings.autoSave
                    }
                }
            }
        }
    }

    // ── Features ─────────────────────────────────────────────────────────────

    Component
    {
        id: _featuresComponent

        Maui.SettingsPage
        {
            title: i18n("Features")

            Maui.SectionGroup
            {
                Maui.FlexSectionItem
                {
                    label1.text: i18n("PDF Viewer")
                    label2.text: i18n("Open PDF documents in the browser instead of downloading.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.pdfViewerEnabled
                        onToggled: appSettings.pdfViewerEnabled = !appSettings.pdfViewerEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("WebGL")
                    label2.text: i18n("Enable hardware-accelerated 3D graphics.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.webGLEnabled
                        onToggled: appSettings.webGLEnabled = !appSettings.webGLEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Fullscreen")
                    label2.text: i18n("Allow web pages to request fullscreen mode.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.fullScreenSupportEnabled
                        onToggled: appSettings.fullScreenSupportEnabled = !appSettings.fullScreenSupportEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Screen Capture")
                    label2.text: i18n("Allow web pages to capture screen contents.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.screenCaptureEnabled
                        onToggled: appSettings.screenCaptureEnabled = !appSettings.screenCaptureEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Error Pages")
                    label2.text: i18n("Show the browser's built-in error page when a site fails to load due to a network error.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.errorPageEnabled
                        onToggled: appSettings.errorPageEnabled = !appSettings.errorPageEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Dark Mode")
                    label2.text: i18n("Signal a dark color scheme preference to web pages. Sites that support dark mode will switch automatically.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.forceDarkMode
                        onToggled: appSettings.forceDarkMode = !appSettings.forceDarkMode
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Scroll Bars")
                    label2.text: i18n("Show scroll bars on web pages.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.showScrollBars
                        onToggled: appSettings.showScrollBars = !appSettings.showScrollBars
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Block Autoplay")
                    label2.text: i18n("Require a user gesture before media starts playing.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.playbackRequiresUserGesture
                        onToggled: appSettings.playbackRequiresUserGesture = !appSettings.playbackRequiresUserGesture
                    }
                }
            }
        }
    }

    // ── JavaScript ───────────────────────────────────────────────────────────

    Component
    {
        id: _jsComponent

        Maui.SettingsPage
        {
            title: i18n("JavaScript")

            Maui.SectionGroup
            {
                Maui.FlexSectionItem
                {
                    label1.text: i18n("Enable JavaScript")
                    label2.text: i18n("Run JavaScript on web pages. Disabling this will break most sites.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.javascriptEnabled
                        onToggled: appSettings.javascriptEnabled = !appSettings.javascriptEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Clipboard Access")
                    label2.text: i18n("Allow JavaScript to read from and write to the clipboard.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.javascriptCanAccessClipboard
                        onToggled: appSettings.javascriptCanAccessClipboard = !appSettings.javascriptCanAccessClipboard
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Open New Windows")
                    label2.text: i18n("Allow JavaScript to open new browser windows.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.javascriptCanOpenWindows
                        onToggled: appSettings.javascriptCanOpenWindows = !appSettings.javascriptCanOpenWindows
                    }
                }
            }
        }
    }

    // ── Permissions ──────────────────────────────────────────────────────────

    Component
    {
        id: _permissionsComponent

        Maui.SettingsPage
        {
            title: i18n("Permissions")

            Maui.SectionGroup
            {
                description: i18n("These are global defaults. When disabled, the permission is silently denied for all sites without a prompt.")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Notifications")
                    label2.text: i18n("Allow websites to send desktop notifications.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowNotifications
                        onToggled: appSettings.allowNotifications = !appSettings.allowNotifications
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Location")
                    label2.text: i18n("Allow websites to request your geographic location.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowGeolocation
                        onToggled: appSettings.allowGeolocation = !appSettings.allowGeolocation
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Microphone")
                    label2.text: i18n("Allow websites to access your microphone.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowMicrophone
                        onToggled: appSettings.allowMicrophone = !appSettings.allowMicrophone
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Camera")
                    label2.text: i18n("Allow websites to access your camera.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowCamera
                        onToggled: appSettings.allowCamera = !appSettings.allowCamera
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Screen Capture")
                    label2.text: i18n("Allow websites to record your screen or desktop audio.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowDesktopCapture
                        onToggled: appSettings.allowDesktopCapture = !appSettings.allowDesktopCapture
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Pointer Lock")
                    label2.text: i18n("Allow websites to capture and hide the cursor (used in browser games).")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.allowMouseLock
                        onToggled: appSettings.allowMouseLock = !appSettings.allowMouseLock
                    }
                }
            }
        }
    }

    // ── Privacy & Security ───────────────────────────────────────────────────

    Component
    {
        id: _privacyComponent

        Maui.SettingsPage
        {
            title: i18n("Privacy & Security")

            Maui.SectionGroup
            {
                title: i18n("Tracking & Ads")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Do Not Track")
                    label2.text: i18n("Send a DNT header asking sites not to track you. Compliance is voluntary.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.doNotTrack
                        onToggled: appSettings.doNotTrack = !appSettings.doNotTrack
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Ad Blocker")
                    label2.text: i18n("Block requests to known ad and tracker domains. Changes take effect after reload. Place a custom hosts-format file at ~/.config/fiery/blocklist.txt to override the built-in list.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.adBlockEnabled
                        onToggled: appSettings.adBlockEnabled = !appSettings.adBlockEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Cookie Banner Blocker")
                    label2.text: i18n("Automatically remove cookie consent popups and GDPR banners.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.cookieBannerBlocker
                        onToggled: appSettings.cookieBannerBlocker = !appSettings.cookieBannerBlocker
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Block Third-Party Cookies")
                    label2.text: i18n("Prevent sites from setting cookies on behalf of domains other than the one you are visiting. Breaks some login flows on sites that delegate authentication to a third party.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.blockThirdPartyCookies
                        onToggled: appSettings.blockThirdPartyCookies = !appSettings.blockThirdPartyCookies
                    }
                }

                Maui.FlexSectionItem
                {
                    visible: appSettings.blockThirdPartyCookies
                    label1.text: i18n("Cookie Exceptions")
                    label2.text: i18n("Sites listed here may set third-party cookies even when blocking is enabled. Enter the domain only (e.g. accounts.google.com).")

                    Button
                    {
                        text: i18n("Add Site")
                        onClicked: _whitelistDialog.open()
                    }
                }

                // One row per whitelisted domain, visible only while blocking is on.
                Repeater
                {
                    model: appSettings.blockThirdPartyCookies
                           ? (function() { try { return JSON.parse(appSettings.thirdPartyCookiesWhitelistJson) } catch(e) { return [] } })()
                           : []

                    Maui.FlexSectionItem
                    {
                        required property string modelData
                        required property int    index

                        label1.text: modelData
                        label2.text: ""

                        ToolButton
                        {
                            icon.name: "list-remove"
                            onClicked:
                            {
                                var list = (function() { try { return JSON.parse(appSettings.thirdPartyCookiesWhitelistJson) } catch(e) { return [] } })()
                                list.splice(index, 1)
                                appSettings.thirdPartyCookiesWhitelistJson = JSON.stringify(list)
                            }
                        }
                    }
                }

                // Add-domain dialog, shared with the "Add Site" button above.
                Dialog
                {
                    id: _whitelistDialog
                    title: i18n("Add Cookie Exception")
                    standardButtons: Dialog.Ok | Dialog.Cancel
                    anchors.centerIn: parent

                    TextField
                    {
                        id: _whitelistField
                        width: parent.width
                        placeholderText: "accounts.example.com"
                        Keys.onReturnPressed: _whitelistDialog.accept()
                    }

                    onOpened: { _whitelistField.text = ""; _whitelistField.forceActiveFocus() }

                    onAccepted:
                    {
                        var domain = _whitelistField.text.trim().toLowerCase()
                        if (!domain) return
                        var list = (function() { try { return JSON.parse(appSettings.thirdPartyCookiesWhitelistJson) } catch(e) { return [] } })()
                        if (list.indexOf(domain) < 0)
                        {
                            list.push(domain)
                            appSettings.thirdPartyCookiesWhitelistJson = JSON.stringify(list)
                        }
                    }
                }
            }

            Maui.SectionGroup
            {
                title: i18n("Security")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("HTTPS-Only Mode")
                    label2.text: i18n("Automatically upgrade all HTTP requests to HTTPS. Pages that do not support HTTPS will fail to load.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.httpsOnly
                        onToggled: appSettings.httpsOnly = !appSettings.httpsOnly
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("DNS over HTTPS")
                    label2.text: i18n("Encrypt DNS lookups to prevent snooping and tampering. Takes effect after restart.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.dohEnabled
                        onToggled: appSettings.dohEnabled = !appSettings.dohEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    visible: appSettings.dohEnabled
                    label1.text: i18n("DoH Resolver URL")
                    label2.text: i18n("HTTPS endpoint for the DNS resolver. Leave blank for Cloudflare (default).")

                    TextField
                    {
                        Layout.fillWidth: true
                        text: appSettings.dohUrl
                        placeholderText: "https://cloudflare-dns.com/dns-query"
                        onEditingFinished: appSettings.dohUrl = text
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("WebRTC IP Protection")
                    label2.text: i18n("Limit WebRTC to public IP addresses only, preventing local network IP leaks.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.webRTCPublicInterfacesOnly
                        onToggled: appSettings.webRTCPublicInterfacesOnly = !appSettings.webRTCPublicInterfacesOnly
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("DNS Prefetch")
                    label2.text: i18n("Pre-resolve DNS for links on the page to speed up navigation.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.dnsPrefetchEnabled
                        onToggled: appSettings.dnsPrefetchEnabled = !appSettings.dnsPrefetchEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Local Storage")
                    label2.text: i18n("Allow websites to store data locally in the browser.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.localStorageEnabled
                        onToggled: appSettings.localStorageEnabled = !appSettings.localStorageEnabled
                    }
                }
            }

            Maui.SectionGroup
            {
                title: i18n("Clear Browsing Data")
                description: i18n("Permanently delete stored browsing data.")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Browsing History")
                    label2.text: i18n("Clear all visited URLs and page titles.")

                    Button
                    {
                        text: i18n("Clear")
                        onClicked: Fiery.History.clearAll()
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Cache")
                    label2.text: i18n("Clear cached images and files.")

                    Button
                    {
                        text: i18n("Clear")
                        onClicked: root.profile.clearHttpCache()
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Cookies & Site Data")
                    label2.text: i18n("Clear cookies stored by websites.")

                    Button
                    {
                        text: i18n("Clear")
                        onClicked: root.profile.cookieStore.deleteAllCookies()
                    }
                }
            }
        }
    }

}
