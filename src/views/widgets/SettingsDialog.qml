import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB
import org.maui.fiery as Fiery

import "../browser"

Maui.SettingsDialog
{
    id: control

    Maui.InfoDialog
    {
        id: confirmationDialog
        property string url: ""
        property string displayUrl: ""

        title: i18n("Reset downloads folder")
        message: i18n("Reset the downloads folder back to the default location?\n%1", displayUrl.length > 0 ? displayUrl : url)
        template.iconSource: "emblem-warning"

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted:
        {
            appSettings.downloadsPath = root.normalizeDownloadsPath("")
            confirmationDialog.close()
        }

        onRejected: confirmationDialog.close()
    }

    Maui.SectionGroup
    {
        title: i18n("General")

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
            label2.text: i18n("Override the browser identity string sent to websites.")

            TextField
            {
                Layout.fillWidth: true
                placeholderText: i18n("Default")
                text: appSettings.customUserAgent
                onEditingFinished: appSettings.customUserAgent = text
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Downloads")

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

        ColumnLayout
        {
            Layout.fillWidth: true
            spacing: Maui.Style.space.medium

            Maui.ListDelegate
            {
                Layout.fillWidth: true

                template.iconSource: "folder-download"
                template.iconSizeHint: Maui.Style.iconSizes.small
                template.label1.text: i18n("Downloads")
                template.label2.text: root.normalizeDownloadsPath(appSettings.downloadsPath)

                template.content: ToolButton
                {
                    icon.name: "edit-clear"
                    flat: true
                    onClicked:
                    {
                        confirmationDialog.url = appSettings.downloadsPath
                        confirmationDialog.displayUrl = root.normalizeDownloadsPath(appSettings.downloadsPath)
                        confirmationDialog.open()
                    }
                }
            }

            Button
            {
                Layout.fillWidth: true
                text: i18n("Change")
                onClicked: _folderDialog.open()
            }

            FB.FileDialog
            {
                id: _folderDialog
                mode: FB.FileDialog.Modes.Open
                browser.settings.onlyDirs: true
                onFinished: function(paths)
                {
                    if(paths.length > 0)
                    {
                        const path = root.normalizeDownloadsPath(paths[0])
                        appSettings.downloadsPath = path
                    }
                }
            }
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
        label1.text: i18n("Privacy and Security")
        label2.text: i18n("Ad blocker, tracking, and data options.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_privacyComponent)
        }
    }

    Maui.FlexSectionItem
    {
        label1.text: i18n("Passwords")
        label2.text: i18n("Manage saved login credentials.")

        ToolButton
        {
            icon.name: "go-next"
            checkable: true
            onToggled: control.addPage(_passwordsComponent)
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
                title: i18n("Site Behavior")

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
            }

            Maui.SectionGroup
            {
                title: i18n("Media Behavior")

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

            Maui.SectionGroup
            {
                title: i18n("Tab Behavior")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Tab Discard")
                    label2.text: i18n("Automatically discard background tabs to free memory. The tab reloads when you switch back to it.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.tabSleepEnabled
                        onToggled: appSettings.tabSleepEnabled = !appSettings.tabSleepEnabled
                    }
                }

                Maui.SectionItem
                {
                    visible: appSettings.tabSleepEnabled
                    label1.text: i18n("Tab Sleep (minutes)")
                    label2.text: i18n("How long a tab must be inactive before it is put to sleep.")

                    SpinBox
                    {
                        from: 1
                        to: 480
                        value: appSettings.tabSleepDelay
                        onValueModified: appSettings.tabSleepDelay = value
                    }
                }
            }

            Maui.SectionGroup
            {
                title: i18n("Javascript")

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

            Maui.SectionGroup
            {
                title: i18n("DRM Management")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Widevine DRM")
                    label2.text: (Fiery.WidevineInstaller.isInstalled && appSettings.widevineEnabled)
                                    ? i18n("Widevine CDM is installed and active. DRM-protected content is available.")
                                    : Fiery.WidevineInstaller.isInstalled
                                    ? i18n("Widevine CDM is installed. Enable to allow DRM-protected content.")
                                    : i18n("Enable playback of DRM-protected content (Netflix, etc.). Downloads the Widevine CDM from Google on first use.")

                    Switch
                    {
                        id: _widevineSwitch
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.widevineEnabled
                        onToggled:
                        {
                            appSettings.widevineEnabled = !appSettings.widevineEnabled
                            if (appSettings.widevineEnabled && !Fiery.WidevineInstaller.isInstalled)
                                _widevinePrompt.open()
                        }
                    }
                }

                WidevinePrompt { id: _widevinePrompt }
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
                title: i18n("Global")

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

    // ── Privacy and Security ───────────────────────────────────────────────────

    Component
    {
        id: _privacyComponent

        Maui.SettingsPage
        {
            title: i18n("Privacy and Security")

            Maui.SectionGroup
            {
                title: i18n("Tracking and Ads")

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
                    label2.text: i18n("Block requests to known ad and tracker domains, and skip video ads. Changes take effect after reload.")

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
                    label1.text: i18n("Strip Tracking Parameters")
                    label2.text: i18n("Remove UTM, fbclid, gclid, and other tracking tokens from URLs before the request is sent.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.stripTrackingParams
                        onToggled: appSettings.stripTrackingParams = !appSettings.stripTrackingParams
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Global Privacy Control")
                    label2.text: i18n("Send a Sec-GPC header asking sites not to sell or share your data. Legally binding in some jurisdictions.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.globalPrivacyControl
                        onToggled: appSettings.globalPrivacyControl = !appSettings.globalPrivacyControl
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Block AMP Links")
                    label2.text: i18n("Redirect Google AMP pages to the original publisher URL, preventing Google from tracking your reading habits.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.blockAmpLinks
                        onToggled: appSettings.blockAmpLinks = !appSettings.blockAmpLinks
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Subscribe and Ad-Block Popup Blocker")
                    label2.text: i18n("Automatically remove newsletter, subscription, and ad-blocker-detection overlays.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.subscribeBlockerEnabled
                        onToggled: appSettings.subscribeBlockerEnabled = !appSettings.subscribeBlockerEnabled
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Ad-Blocker Detection Bypass")
                    label2.text: i18n("Suppress \"please disable your ad blocker\" walls by spoofing ad-presence signals and removing detection overlays.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.adblockDetectionBlockerEnabled
                        onToggled: appSettings.adblockDetectionBlockerEnabled = !appSettings.adblockDetectionBlockerEnabled
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

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Browsing History")
                    label2.text: i18n("Clear all visited URLs and page titles.")

                    Button
                    {
                        text: i18n("Clear")
                        enabled: !appSettings.clearSessionOnExit
                        onClicked: Fiery.History.clearAll()
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Site Cache")
                    label2.text: i18n("Clear cached images and files.")

                    Button
                    {
                        text: i18n("Clear")
                        enabled: !appSettings.clearSessionOnExit
                        onClicked: root.profile.clearHttpCache()
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Cookies and Site Data")
                    label2.text: i18n("Clear cookies stored by websites.")

                    Button
                    {
                        text: i18n("Clear")
                        enabled: !appSettings.clearSessionOnExit
                        onClicked: root.profile.cookieStore.deleteAllCookies()
                    }
                }

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Clear Session on Exit")
                    label2.text: i18n("Forget the current session when the app closes.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: appSettings.clearSessionOnExit
                        onToggled: appSettings.clearSessionOnExit = !appSettings.clearSessionOnExit
                    }
                }
            }
        }
    }

    // ── Passwords ────────────────────────────────────────────────────────────

    Component
    {
        id: _passwordsComponent

        Maui.SettingsPage
        {
            id: _passwordsPage
            title: i18n("Passwords and Autofill")
            property string credentialsSearchQuery: ""
            property bool showPasswordDetails: true

            Maui.SectionGroup
            {
                title: i18n("Clear Passwords")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Remove Saved Credentials")
                    label2.text: i18n("Permanently delete all stored credentials.")

                    Button
                    {
                        text: i18n("Clear")
                        enabled: Fiery.PasswordManager.entries.length > 0
                        onClicked: _clearPasswordsDialog.open()
                    }

                    Dialog
                    {
                        id: _clearPasswordsDialog
                        title: i18n("Clear All Passwords?")
                        standardButtons: Dialog.Ok | Dialog.Cancel
                        anchors.centerIn: parent

                        Label
                        {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: i18n("This will permanently delete all saved credentials. This cannot be undone.")
                        }

                        onAccepted:
                        {
                            var all = Fiery.PasswordManager.entries
                            for (var i = 0; i < all.length; i++)
                                Fiery.PasswordManager.remove(all[i].host, all[i].username)
                        }
                    }
                }
            }

            Maui.SectionGroup
            {
                title: i18n("Passwords")

                Maui.FlexSectionItem
                {
                    label1.text: i18n("Show Password Details")
                    label2.text: i18n("Display the password actions, password field, and username in the list.")

                    Switch
                    {
                        Layout.fillHeight: true
                        checkable: true
                        checked: _passwordsPage.showPasswordDetails
                        onToggled: _passwordsPage.showPasswordDetails = !_passwordsPage.showPasswordDetails
                    }
                }

                Maui.SectionItem
                {
                    label1.text: i18n("Search")
                    label2.text: i18n("Filter saved credentials by domain.")

                    Maui.SearchField
                    {
                        Layout.fillWidth: true
                        placeholderText: "Search by domain"
                        text: _passwordsPage.credentialsSearchQuery
                        onTextChanged: _passwordsPage.credentialsSearchQuery = text
                    }
                }

                Maui.SectionItem
                {
                    visible: Fiery.PasswordManager.entries.length === 0
                    label1.text: i18n("No saved passwords")
                    label2.text: i18n("Passwords are offered for saving when you sign in to a site.")
                }

                Repeater
                {
                    model: Fiery.PasswordManager.entries

                    delegate: Maui.SectionItem
                    {
                        required property var modelData

                        visible: (_passwordsPage.credentialsSearchQuery || "").length === 0
                                 || String(modelData.host || "").toLowerCase().indexOf((_passwordsPage.credentialsSearchQuery || "").toLowerCase()) !== -1

                        property string passwordCache: ""

                        Component.onCompleted: loadPassword()

                        label1.text: modelData.host
                        label2.text: modelData.username
                        label2.visible: _passwordsPage.showPasswordDetails

                        function currentPassword()
                        {
                            if (passwordField.editMode)
                                return passwordField.text

                            if (_revealBtn.checked)
                                return passwordCache

                            return passwordCache
                        }

                        function loadPassword()
                        {
                            if ((passwordCache || "").length > 0)
                                return passwordCache

                            var creds = Fiery.PasswordManager.find(modelData.host) || []
                            for (var i = 0; i < creds.length; i++)
                            {
                                if (creds[i].username === modelData.username)
                                {
                                    passwordCache = creds[i].password || ""
                                    return passwordCache
                                }
                            }

                            return ""
                        }

                        template.content: RowLayout
                        {
                            visible: _passwordsPage.showPasswordDetails
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            spacing: Maui.Style.space.small

                            Button
                            {
                                id: _editBtn
                                checkable: true
                                text: checked ? i18n("Save") : i18n("Edit")
                                onToggled:
                                {
                                    if (checked)
                                    {
                                        passwordField.editMode = true
                                        passwordField.text = loadPassword()
                                        passwordField.forceActiveFocus()
                                        passwordField.selectAll()
                                    }
                                    else
                                    {
                                        Fiery.PasswordManager.save(modelData.host, modelData.username, passwordField.text)
                                        passwordCache = passwordField.text
                                        passwordField.editMode = false
                                        _revealBtn.checked = false
                                    }
                                }
                            }

                            Button
                            {
                                id: _revealBtn
                                checkable: true
                                text: checked ? i18n("Hide") : i18n("Show")
                                enabled: !passwordField.editMode
                                onToggled:
                                {
                                    if (checked)
                                        loadPassword()
                                }
                            }

                            Button
                            {
                                text: i18n("Remove")
                                onClicked: Fiery.PasswordManager.remove(modelData.host, modelData.username)
                            }
                        }

                        Maui.TextField
                        {
                            id: passwordField
                            visible: _passwordsPage.showPasswordDetails
                            Layout.fillWidth: true
                            readOnly: !editMode
                            text: currentPassword()
                            property bool editMode: false
                            selectByMouse: true
                            echoMode: editMode || _revealBtn.checked ? TextInput.Normal : TextInput.Password
                            font.family: Maui.Style.monospacedFont.family
                            onEditingFinished:
                            {
                                if (editMode)
                                {
                                    Fiery.PasswordManager.save(modelData.host, modelData.username, text)
                                    passwordCache = text
                                    editMode = false
                                    _editBtn.checked = false
                                }
                            }
                        }

                    }
                }
            }
        }
    }

}
