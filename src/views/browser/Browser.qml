import QtQuick
import QtQml
import QtQuick.Controls

import QtWebEngine
import org.mauikit.controls as Maui
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

    Shortcut
    {
        sequence: "Escape"
        enabled: control._webFullScreen
        onActivated: _webView.triggerWebAction(WebEngineView.ExitFullScreen)
    }

    ActionsMenu
    {
        id: _menu
        webView: _webView
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
            _menu.show()

            //                _menu.show()
        }

        readonly property string _cookieBannerScript: "(function(){'use strict';var s=['#cookiebanner','#cookie-banner','#cookie-notice','#cookie-bar','#cookie-consent','#cookie-popup','#gdpr-banner','#gdpr-consent','#gdpr-popup','#consent-banner','#consent-notice','#CybotCookiebotDialog','#onetrust-banner-sdk','#onetrust-consent-sdk','#qc-cmp2-container','#sp_message_container','#didomi-popup','#didomi-host','#usercentrics-root','.cookie-banner','.cookie-notice','.cookie-consent','.cookie-popup','.cookie-bar','.cookie-wall','.gdpr','.gdpr-banner','.gdpr-notice','.gdpr-popup','.consent-banner','.consent-notice','.cc-window','.cc-banner','.cc-overlay','.cookieconsent','[id^=\"cookie\"]','[class*=\"CookieBanner\"]','[aria-label*=\"cookie\" i]'];function r(){s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});if(document.body){document.body.style.removeProperty('overflow');document.body.style.removeProperty('position');}}r();new MutationObserver(r).observe(document.documentElement,{childList:true,subtree:true});})();"

        onLoadingChanged: function(loadingInfo)
        {
            if(loadingInfo.status === WebEngineView.LoadSucceededStatus)
            {
                control._loadFailed = false
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
            console.log("LINK HOVERED", url)
        }

        onFindTextFinished: {
            //                   findInPageResultIndex = result.activeMatch;
            //                   findInPageResultCount = result.numberOfMatches;
        }

        onFileDialogRequested: (request) =>
        {
            console.log("FILE DIALOG REQUESTED", request.mode, FileDialogRequest.FileModeSave)

        }

        onNewWindowRequested: (request) =>
        {
            if(!request.userInitiated)
                return;

            var newWindow = windowComponent.createObject(root)
            request.openIn(newWindow.webView);
        }

        onFullScreenRequested: function(request)
        {
            request.accept()
            control._webFullScreen = request.toggleOn
            if (request.toggleOn)
                Window.window.showFullScreen()
            else
                Window.window.showNormal()
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
        settings.localContentCanAccessFileUrls : true
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
    // requestAnimationFrame asks Blink's renderer to schedule a paint
    // frame, which causes it to submit a fresh texture to Qt Quick.
    Connections
    {
        target: Window.window
        function onActiveChanged()
        {
            if (Window.window.active && control.visible)
            {
                // When a Wayland compositor (e.g. Hyprland) hides a workspace,
                // it stops sending wl_surface.frame callbacks. Chromium's Viz
                // compositor detects this and stops producing GPU frames. When
                // the workspace becomes active again, Viz is still idle —
                // waiting for a BeginFrame it won't get — so Qt Quick composites
                // a stale/empty texture (black screen).
                //
                // An empty requestAnimationFrame() doesn't fix this because it
                // produces no damage in Viz's compositor layer tree. We need to
                // create actual layer damage. Briefly inserting a GPU-composited
                // element (transform:translateZ forces its own cc::Layer) marks
                // Viz's tree as dirty and forces a real swap buffer submission.
                _webView.lifecycleState = WebEngineView.Active
                _webView.runJavaScript(
                    "(function(){" +
                    "  var e=document.createElement('div');" +
                    "  e.style.cssText='position:fixed;top:0;left:0;width:1px;height:1px;" +
                                       "transform:translateZ(0);pointer-events:none;" +
                                       "opacity:0.001;z-index:2147483647';" +
                    "  document.documentElement.appendChild(e);" +
                    "  requestAnimationFrame(function(){e.remove();});" +
                    "})()"
                )
            }
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

    Component.onCompleted:
    {
        if(!control.url || !control.url.toString().length || !validURL(control.url))
        {
            //            _stackView.push(_startComponent)
        }
    }
}


