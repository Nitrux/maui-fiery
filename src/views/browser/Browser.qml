import QtQuick
import QtQml
import QtQuick.Controls

import QtWebEngine
import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB
import org.maui.fiery as Fiery


Maui.SplitViewItem
{
    id: control
    property alias url : _webView.url
    property alias webView : _webView
    property WebEngineProfile browserProfile: root.profile
    readonly property string title : _webView.title.length ? _webView.title : "Fiery"
    readonly property string iconName: _webView.icon

    height: ListView.view.height
    width:  ListView.view.width

    Maui.Controls.title: title
    Maui.Controls.toolTipText:  _webView.url

    property bool _webFullScreen: false
    property string _hoveredUrl: ""
    property var _pendingFileRequest: null

    // Exit-fullscreen button shown in the top-right corner while the page
    // is in web-requested fullscreen. Pressing Escape or clicking it calls
    // ExitFullScreen, which triggers onFullScreenRequested(toggleOn=false).
    ToolButton
    {
        z: 10
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Maui.Style.space.medium
        visible: control._webFullScreen
        icon.name: "view-restore"
        ToolTip.text: i18n("Exit Full Screen")
        ToolTip.visible: hovered
        ToolTip.delay: 1000
        onClicked: _webView.triggerWebAction(WebEngineView.ExitFullScreen)
    }

    // Mandatory anti-phishing overlay shown for 4 s whenever a page enters
    // fullscreen.  Rendered at z=100 — entirely above the WebEngineView — so
    // the page cannot cover or mimic it with its own drawing.
    Rectangle
    {
        id: _fullscreenOverlay
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Maui.Style.space.big

        visible: false
        radius: Maui.Style.radiusV
        color: Maui.Theme.backgroundColor
        border.color: Maui.Theme.textColor
        border.width: 1
        opacity: 0.95

        width:  _fullscreenLabel.implicitWidth  + Maui.Style.space.huge * 2
        height: _fullscreenLabel.implicitHeight + Maui.Style.space.medium * 2

        Label
        {
            id: _fullscreenLabel
            anchors.centerIn: parent
            color: Maui.Theme.textColor
            text:
            {
                var host = ""
                try { host = new URL(_webView.url.toString()).hostname } catch(e) {}
                return host.length > 0
                    ? i18n("%1 is now fullscreen · Press Esc to exit", host)
                    : i18n("Page is now fullscreen · Press Esc to exit")
            }
        }

        Timer
        {
            id: _fullscreenOverlayTimer
            interval: 4000
            onTriggered: _fullscreenOverlay.visible = false
        }
    }

    Shortcut
    {
        sequence: "Escape"
        enabled: control._webFullScreen
        onActivated: _webView.triggerWebAction(WebEngineView.ExitFullScreen)
    }

    // Accept URLs and text dropped onto the browser pane (e.g. a link dragged
    // from another app or from the browser itself).
    DropArea
    {
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]

        onDropped: (drop) =>
        {
            var url = ""
            if (drop.hasUrls)
                url = drop.urls[0].toString()
            else
                url = drop.text.trim()

            if (url.length > 0)
                _webView.url = url
        }
    }

    ActionsMenu
    {
        id: _menu
        webView: _webView
    }

    // File-chooser / save-as dialog shown in response to onFileDialogRequested.
    // When the user accepts, acceptFiles() forwards the selected paths to the
    // web page; when they cancel (visible returns to false with no selection),
    // reject() lets the page know the dialog was dismissed.
    FB.FileDialog
    {
        id: _fileDialog

        onFinished: function(paths)
        {
            if (control._pendingFileRequest === null)
                return

            var req = control._pendingFileRequest
            control._pendingFileRequest = null

            if (paths.length > 0)
            {
                var filePaths = paths.map(function(p)
                {
                    var s = p.toString()
                    // Strip the file:// prefix and decode percent-encoded characters
                    // (e.g. %20 → space) so the engine receives a plain filesystem
                    // path rather than a URL-encoded string.
                    return decodeURIComponent(s.startsWith("file://") ? s.slice(7) : s)
                })
                req.acceptFiles(filePaths)
            }
            else
            {
                req.reject()
            }
        }

        onVisibleChanged:
        {
            // If the dialog was closed without triggering onFinished (user
            // pressed Cancel or dismissed the dialog), clean up the pending
            // request so the web page isn't left waiting.
            if (!visible && control._pendingFileRequest !== null)
            {
                control._pendingFileRequest.reject()
                control._pendingFileRequest = null
            }
        }
    }

    WebEngineView
    {
        id: _webView

        anchors.fill: parent

        profile: control.browserProfile
        zoomFactor: appSettings.zoomFactor

        onContextMenuRequested: (request) =>
        {
            request.accepted = true // Make sure QtWebEngine doesn't show its own context menu.
            _menu.request = request

            // Stamp the element under the pointer with a unique attribute *now*,
            // before the menu is visible.  The Speed and Fullscreen JS actions
            // then target this attribute instead of re-running elementFromPoint
            // at trigger time, closing the window where a page could inject a
            // replacement element at those coordinates.
            const elemId = 'fiery-ctx-' + Date.now()
            _menu.contextElemId = elemId
            _webView.runJavaScript(
                '(function(x,y,id){' +
                '  var e=document.elementFromPoint(x,y);' +
                '  if(e) e.setAttribute("data-fiery-ctx",id);' +
                '})(' + request.x + ',' + request.y + ',"' + elemId + '")'
            )

            _menu.show()
        }

        // The observer disconnects as soon as a banner is removed (success),
        // and unconditionally after 20 mutation callbacks as a failsafe for
        // highly dynamic single-page applications that would otherwise keep
        // running querySelectorAll against ~40 selectors indefinitely.
        readonly property string _cookieBannerScript: "(function(){'use strict';var s=['#cookiebanner','#cookie-banner','#cookie-notice','#cookie-bar','#cookie-consent','#cookie-popup','#gdpr-banner','#gdpr-consent','#gdpr-popup','#consent-banner','#consent-notice','#CybotCookiebotDialog','#onetrust-banner-sdk','#onetrust-consent-sdk','#qc-cmp2-container','#sp_message_container','#didomi-popup','#didomi-host','#usercentrics-root','.cookie-banner','.cookie-notice','.cookie-consent','.cookie-popup','.cookie-bar','.cookie-wall','.gdpr','.gdpr-banner','.gdpr-notice','.gdpr-popup','.consent-banner','.consent-notice','.cc-window','.cc-banner','.cc-overlay','.cookieconsent','[id^=\"cookie\"]','[class*=\"CookieBanner\"]','[aria-label*=\"cookie\" i]'];var o;var n=0;function r(){var f=false;s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();f=true;});}catch(e){}});if(document.body){document.body.style.removeProperty('overflow');document.body.style.removeProperty('position');}return f;}r();var t;o=new MutationObserver(function(){if(++n>20){o.disconnect();return;}if(t)clearTimeout(t);t=setTimeout(function(){if(r())o.disconnect();},500);});o.observe(document.documentElement,{childList:true,subtree:true});})();"

        onLoadingChanged: function(loadingInfo)
        {
            if(loadingInfo.status === WebEngineView.LoadSucceededStatus)
            {
                control._loadFailed = false
                console.log("Load succeeded. offTheRecord:", _webView.profile.offTheRecord, "url:", control.url)
                if (!_webView.profile.offTheRecord)
                    Fiery.History.appendUrl(control.url, control.title)
                if (appSettings.cookieBannerBlocker)
                    _webView.runJavaScript(_webView._cookieBannerScript)
            }
            else if(loadingInfo.status === WebEngineView.LoadFailedStatus)
            {
                control._loadFailed = true
            }
            else if(loadingInfo.status === WebEngineView.LoadStartedStatus)
            {
                control._loadFailed = false
            }
        }

        onIconChanged:
        {
            if (icon && !_webView.profile.offTheRecord)
                Fiery.History.updateIcon(url, icon)
        }

        onLinkHovered: (url) =>
        {
            control._hoveredUrl = url
        }

        onFindTextFinished: {
            //                   findInPageResultIndex = result.activeMatch;
            //                   findInPageResultCount = result.numberOfMatches;
        }

        onFileDialogRequested: (request) =>
        {
            request.accepted = true
            control._pendingFileRequest = request

            switch (request.mode)
            {
                case FileDialogRequest.FileModeOpen:
                case FileDialogRequest.FileModeOpenMultiple:
                    _fileDialog.mode = FB.FileDialog.Open
                    break
                case FileDialogRequest.FileModeSave:
                    _fileDialog.mode = FB.FileDialog.Save
                    break
                case FileDialogRequest.FileModeUploadFolder:
                    _fileDialog.mode = FB.FileDialog.Dirs
                    break
                default:
                    _fileDialog.mode = FB.FileDialog.Open
            }

            _fileDialog.open()
        }

        onNewWindowRequested: (request) =>
        {
            if(!request.userInitiated)
                return;

            _appView.browserView.openTab(request.requestedUrl.toString())
        }

        onFullScreenRequested: function(request)
        {
            request.accept()
            control._webFullScreen = request.toggleOn
            if (request.toggleOn)
            {
                Window.window.showFullScreen()
                _fullscreenOverlay.visible = true
                _fullscreenOverlayTimer.restart()
            }
            else
            {
                Window.window.showNormal()
                _fullscreenOverlayTimer.stop()
                _fullscreenOverlay.visible = false
            }
        }

        onFeaturePermissionRequested: (securityOrigin, feature) =>
        {
            var granted = false
            switch (feature)
            {
                case WebEngineView.Notifications:
                    granted = appSettings.allowNotifications
                    break
                case WebEngineView.Geolocation:
                    granted = appSettings.allowGeolocation
                    break
                case WebEngineView.MediaAudioCapture:
                    granted = appSettings.allowMicrophone
                    break
                case WebEngineView.MediaVideoCapture:
                    granted = appSettings.allowCamera
                    break
                case WebEngineView.MediaAudioVideoCapture:
                    granted = appSettings.allowMicrophone && appSettings.allowCamera
                    break
                case WebEngineView.DesktopVideoCapture:
                case WebEngineView.DesktopAudioVideoCapture:
                    granted = appSettings.allowDesktopCapture
                    break
                case WebEngineView.MouseLock:
                    granted = appSettings.allowMouseLock
                    break
                default:
                    break
            }
            _webView.grantFeaturePermission(securityOrigin, feature, granted)
        }

        onNavigationRequested: (request) =>
        {
            console.log("Navigation requested",  request.navigationType)
        }

        settings.accelerated2dCanvasEnabled : true
        settings.allowGeolocationOnInsecureOrigins : false
        settings.allowRunningInsecureContent : appSettings.allowRunningInsecureContent
        settings.allowWindowActivationFromJavaScript : false
        settings.autoLoadImages : appSettings.autoLoadImages
        settings.dnsPrefetchEnabled : appSettings.dnsPrefetchEnabled
        settings.hyperlinkAuditingEnabled : false
        settings.javascriptCanAccessClipboard : appSettings.javascriptCanAccessClipboard
        settings.javascriptCanOpenWindows : appSettings.javascriptCanOpenWindows
        settings.javascriptCanPaste : false
        settings.javascriptEnabled : appSettings.javascriptEnabled
        settings.linksIncludedInFocusChain : true
        settings.localContentCanAccessFileUrls : false
        settings.localContentCanAccessRemoteUrls : false
        settings.localStorageEnabled : appSettings.localStorageEnabled
        settings.pdfViewerEnabled : appSettings.pdfViewerEnabled
        settings.playbackRequiresUserGesture : appSettings.playbackRequiresUserGesture
        settings.pluginsEnabled : false
        settings.webGLEnabled : appSettings.webGLEnabled
        settings.webRTCPublicInterfacesOnly : appSettings.webRTCPublicInterfacesOnly
        settings.autoLoadIconsForPage : appSettings.autoLoadIconsForPage
        settings.errorPageEnabled : appSettings.errorPageEnabled
        settings.focusOnNavigationEnabled : false
        settings.fullScreenSupportEnabled : appSettings.fullScreenSupportEnabled
        settings.printElementBackgrounds : true
        settings.screenCaptureEnabled : appSettings.screenCaptureEnabled
        settings.showScrollBars : appSettings.showScrollBars
        settings.spatialNavigationEnabled : false
    }

    property bool _loadFailed: false

    // Workaround for QtWebEngine GPU surface not repainting after a
    // Wayland compositor workspace switch (e.g. Hyprland).
    //
    // Root cause: when Hyprland hides a workspace it stops sending
    // wl_surface.frame callbacks.  Chromium's Viz compositor detects the
    // absence of BeginFrame acknowledgements and goes idle.  When the
    // workspace is shown again Viz is still idle — it won't produce a new
    // GPU frame until it receives a BeginFrame, but it won't receive one
    // until it submits a frame.  Qt Quick therefore composites a stale or
    // empty texture → black screen.
    //
    // The single-RAF approach used previously was fragile: Wayland
    // re-enables wl_surface.frame callbacks asynchronously, so the one
    // frame of GPU activity could fire before the compositor was ready to
    // accept it, leaving Viz idle again.  A multi-frame burst keeps Viz
    // active long enough for the callback round-trip to complete.
    //
    // The same stall can happen when a tab is brought back to the
    // foreground after being backgrounded long enough for Viz to throttle,
    // so we also trigger on onVisibleChanged.
    function _kickVizCompositor()
    {
        _webView.lifecycleState = WebEngineView.Active
        _webView.runJavaScript(
            "(function(){" +
            "  var old=document.getElementById('fiery-viz-kick');" +
            "  if(old)old.remove();" +
            "  var e=document.createElement('div');" +
            "  e.id='fiery-viz-kick';" +
            "  e.style.cssText='position:fixed;top:0;left:0;width:2px;height:2px;" +
                               "transform:translateZ(0);pointer-events:none;" +
                               "opacity:0.001;z-index:2147483647';" +
            "  document.documentElement.appendChild(e);" +
            "  var frames=0;" +
            "  function tick(){" +
            "    if(++frames<5&&e.parentNode){e.style.width=(2+frames)+'px';requestAnimationFrame(tick);}" +
            "    else{e.remove();}" +
            "  }" +
            "  requestAnimationFrame(tick);" +
            "})()"
        )
    }

    onVisibleChanged:
    {
        if (visible && Window.window.active)
            _kickVizCompositor()
    }

    Connections
    {
        target: Window.window
        function onActiveChanged()
        {
            if (Window.window.active && control.visible)
                _kickVizCompositor()
        }
    }

    // Status bar: shows the URL of any link currently under the cursor.
    // Positioned at the bottom-left, overlaying the page content, matching
    // the convention used by all major browsers to help users detect phishing.
    Rectangle
    {
        z: 5
        anchors.left: _webView.left
        anchors.bottom: _webView.bottom
        visible: control._hoveredUrl.length > 0

        width: Math.min(_statusLabel.implicitWidth + Maui.Style.space.medium * 2,
                        _webView.width * 0.75)
        height: _statusLabel.implicitHeight + Maui.Style.space.small * 2

        color: Maui.Theme.backgroundColor
        border.color: Maui.Theme.separatorColor
        border.width: 1
        radius: Maui.Style.radiusV

        Label
        {
            id: _statusLabel
            anchors.fill: parent
            anchors.margins: Maui.Style.space.medium
            // Collapse any whitespace runs (including \r, \n, tabs) to a single
            // space so a padded URL cannot hide a malicious suffix past the elision.
            // safeDisplayUrl converts non-ASCII hostnames to Punycode (IDN protection).
            text: _surf.safeDisplayUrl(control._hoveredUrl).replace(/\s+/g, ' ').trim()
            elide: Text.ElideRight
            font.pointSize: Maui.Style.fontGroup.small
            color: Maui.Theme.textColor
            verticalAlignment: Text.AlignVCenter
        }
    }

    Maui.Holder
    {
        anchors.fill: parent
        visible: control.url.toString().length <= 0 || control._loadFailed
        emoji: "qrc:/internet.svg"

        title: control._loadFailed ? i18n("Error") : i18n("Start Browsing")
        body: i18n("Enter a new URL or open a recent site.")
    }

}


