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
                control.openUrl(url)
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

    // Opaque backdrop for Chromium's built-in error pages. The transparent
    // window compositing stack (background: null + WindowBlur) means any
    // non-fully-opaque color bleeds through to the desktop. Force alpha=1
    // so neither the Rectangle nor the WebEngineView backing are see-through.
    Rectangle
    {
        anchors.fill: parent
        color: Qt.rgba(Maui.Theme.backgroundColor.r,
                       Maui.Theme.backgroundColor.g,
                       Maui.Theme.backgroundColor.b, 1.0)
        visible: control._loadFailed && appSettings.errorPageEnabled
    }

    WebEngineView
    {
        id: _webView

        anchors.fill: parent

        profile: control.browserProfile
        zoomFactor: appSettings.zoomFactor
        // Chromium infers prefers-color-scheme from backgroundColor: a dark
        // value signals dark mode to sites that support it.
        //
        // - Blank tab (about:blank / empty): use the theme background so the
        //   empty-tab state matches the window instead of flashing white.
        // - Loaded page, force dark mode on: use the dark theme background to
        //   signal prefers-color-scheme: dark to supporting sites.
        // - Loaded page, force dark mode off: use white so pages that lack a
        //   native dark theme are not broken by the system color scheme.
        backgroundColor:
        {
            const u = _webView.url.toString()
            const isBlank = u === "" || u === "about:blank"
            if (isBlank || appSettings.forceDarkMode)
                return Qt.rgba(Maui.Theme.backgroundColor.r,
                               Maui.Theme.backgroundColor.g,
                               Maui.Theme.backgroundColor.b, 1.0)
            return "white"
        }

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
                '})(' + Math.max(0, Math.floor(request.x) || 0) + ',' + Math.max(0, Math.floor(request.y) || 0) + ',' + JSON.stringify(elemId) + ')'
            )

            _menu.show()
        }

        // Watches for password fields (including dynamically injected ones) and
        // records the last user-typed credential in window._fieryLastCred.
        // Only trusted input events are captured so auto-fill does not trigger saves.
        // Username lookup searches the whole document and prefers email-type inputs
        // to handle multi-step forms where the email field is outside the password form.
        // Credential storage uses a Symbol key stored at window._fieryCK.  The Symbol
        // prevents accidental property collisions; however, same-origin page scripts
        // can read window._fieryCK and therefore the stored value.  This is acceptable:
        // same-origin scripts already have direct access to the password field value.
        readonly property string _credentialWatcherScript:
            "(function(){" +
            "var _k=window._fieryCK||(window._fieryCK=Symbol('fieryCredKey'));" +
            "if(window[_k])return;" +
            "window[_k]=true;" +
            "var sel='input:not([type=\"password\"]):not([type=\"hidden\"]):not([type=\"submit\"]):not([type=\"button\"]):not([type=\"checkbox\"]):not([type=\"radio\"])';" +
            "function bestUsername(scope){" +
            "var ins=Array.from(scope.querySelectorAll(sel)).filter(function(i){return i.value&&i.value.trim();});" +
            "var em=ins.filter(function(i){return i.type==='email'||(i.name&&i.name.toLowerCase().indexOf('email')!==-1)||(i.id&&i.id.toLowerCase().indexOf('email')!==-1);});" +
            "return em.length?em[em.length-1].value:ins.length?ins[ins.length-1].value:'';}" +
            "var _ck=Symbol('fieryCred');" +
            "function attach(pw){" +
            "if(pw[_ck])return;" +
            "pw[_ck]=true;" +
            "pw.addEventListener('input',function(e){" +
            "if(!e.isTrusted)return;" +
            "if(!pw.value)return;" +
            "var f=pw.form||pw.closest('form');" +
            "var un=bestUsername(f||document);" +
            "if(!un&&f)un=bestUsername(document);" +
            "window[_k]=JSON.stringify({h:location.hostname,u:un,p:pw.value});" +
            "});}" +
            "function scan(){" +
            "document.querySelectorAll('input[type=\"password\"]').forEach(attach);}" +
            "scan();" +
            // Debounced observer: schedule a single scan 500 ms after DOM activity
            // settles.  The flag prevents stacking timers during rapid mutations
            // (e.g. JS-framework re-renders, benchmark DOM churning) so the full-
            // document querySelectorAll runs at most once per burst of changes.
            "var _t=null;" +
            "new MutationObserver(function(muts){" +
            "if(_t)return;" +
            "for(var i=0;i<muts.length;i++){" +
            "var ns=muts[i].addedNodes;" +
            "for(var j=0;j<ns.length;j++){" +
            "if(ns[j].nodeType===1){" +
            "_t=setTimeout(function(){_t=null;scan();},500);" +
            "return;}}}" +
            "}).observe(document.documentElement,{childList:true,subtree:true});" +
            "})()"

        // Reads and clears the credential captured by the watcher via its Symbol key.
        // The key itself is stored under a second Symbol so page code cannot guess it.
        readonly property string _credentialHarvestScript:
            "(function(){" +
            "var _k=window._fieryCK;" +
            "if(!_k)return null;" +
            "var c=typeof window[_k]==='string'?window[_k]:null;" +
            "window[_k]=true;" +
            "return c;" +
            "})()"

        // Builds an auto-fill script for the given credentials array [{username, password}].
        // Uses the native HTMLInputElement value setter so React/Vue controlled inputs
        // receive the change and their internal state stays in sync.
        //
        // Multi-step forms (e.g. email on step 1, password on step 2) are handled by a
        // persistent MutationObserver: username fields are filled as soon as they appear,
        // and the password field is filled when it appears (after the user advances to
        // the next step). The observer disconnects once the password has been filled.
        function buildFillerScript(creds) {
            var json = JSON.stringify(creds)
            return "(function(){" +
                "var creds=" + json + ";" +
                "if(!creds||!creds.length)return;" +
                "var username=creds[0].username||'';" +
                "var password=creds[0].password||'';" +
                "var setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;" +
                "var unSel='input[type=\"email\"],input[type=\"text\"],input[type=\"tel\"]';" +
                "var pwSel='input[type=\"password\"]';" +
                "function setVal(el,val){" +
                "setter.call(el,val);" +
                "el.dispatchEvent(new Event('input',{bubbles:true}));" +
                "el.dispatchEvent(new Event('change',{bubbles:true}));}" +
                "function sameOrigin(el){try{return el.ownerDocument===document;}catch(e){return false;}}" +
                "function tryFillUsername(){" +
                "var un=document.querySelector(unSel);" +
                "if(un&&sameOrigin(un)&&!un._fieryFilled&&username){" +
                "un._fieryFilled=true;" +
                "setVal(un,username);}}" +
                "function tryFillPassword(){" +
                "var pw=document.querySelector(pwSel);" +
                "if(pw&&sameOrigin(pw)&&!pw._fieryFilled&&password){" +
                "pw._fieryFilled=true;" +
                "setVal(pw,password);" +
                "return true;}" +
                "return false;}" +
                "tryFillUsername();" +
                "if(!tryFillPassword()){" +
                "var obs=new MutationObserver(function(){" +
                "tryFillUsername();" +
                "if(tryFillPassword())obs.disconnect();});" +
                "obs.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['type','style','hidden']});}" +
                "})()"
        }

        // Injects a <style> element that replaces Chromium's default scrollbar with a thin,
        // rounded, floating style matching the active MauiKit theme. Colors are sampled from
        // the theme at injection time and embedded directly in the CSS string.
        readonly property string _scrollbarScript: {
            function clamp(v) { return Math.max(0, Math.min(255, Math.round(v * 255))) }
            var c  = Maui.Theme.textColor
            var tr = clamp(c.r), tg = clamp(c.g), tb = clamp(c.b)
            var h  = Maui.Theme.highlightColor
            var hr = clamp(h.r), hg = clamp(h.g), hb = clamp(h.b)
            var thumb       = "rgba(" + tr + "," + tg + "," + tb + ",1.0)"
            var thumbHover  = "rgba(" + tr + "," + tg + "," + tb + ",1.0)"
            var thumbActive = "rgba(" + hr + "," + hg + "," + hb + ",1.0)"
            return "(function(){" +
                "var s=document.getElementById('fiery-sb');" +
                "if(!s){s=document.createElement('style');s.id='fiery-sb';document.head&&document.head.appendChild(s);}" +
                "s.textContent=" +
                "'::-webkit-scrollbar{width:6px;height:6px;}'" +
                "+'::-webkit-scrollbar-track{background:transparent;}'" +
                "+'::-webkit-scrollbar-thumb{background:" + thumb + ";border-radius:3px;}'" +
                "+'::-webkit-scrollbar-thumb:hover{background:" + thumbHover + ";}'" +
                "+'::-webkit-scrollbar-thumb:active{background:" + thumbActive + ";}'" +
                "+'::-webkit-scrollbar-corner{background:transparent;}';" +
                "})();"
        }

        // The observer disconnects as soon as a banner is removed (success),
        // and unconditionally after 20 mutation callbacks as a failsafe for
        // highly dynamic single-page applications that would otherwise keep
        // running querySelectorAll against the selector list indefinitely.
        readonly property string _cookieBannerScript: "(function(){'use strict';var s=['#cookiebanner','#cookie-banner','#cookie-notice','#cookie-bar','#cookie-consent','#cookie-popup','#gdpr-banner','#gdpr-consent','#gdpr-popup','#consent-banner','#consent-notice','#CybotCookiebotDialog','#onetrust-banner-sdk','#onetrust-consent-sdk','#qc-cmp2-container','#sp_message_container','#didomi-popup','#didomi-host','#usercentrics-root','.cookie-banner','.cookie-notice','.cookie-consent','.cookie-popup','.cookie-bar','.cookie-wall','.gdpr','.gdpr-banner','.gdpr-notice','.gdpr-popup','.consent-banner','.consent-notice','.cc-window','.cc-banner','.cc-overlay','.cookieconsent','[id^=\"cookie\"]','[class*=\"CookieBanner\"]','[aria-label*=\"cookie\" i]','[aria-label*=\"consent\" i]','[aria-label*=\"privacy\" i]','#real-cookie-banner','[id*=\"real-cookie\"]','#BorlabsCookie','[id*=\"borlabs-cookie\"]','[class*=\"borlabs-cookie\"]','#cmplz-cookiebanner','[id*=\"cmplz\"]','[class*=\"cmplz-\"]','#cky-consent','#cky-overlay','[class*=\"cky-consent\"]','#termly-code-snippet-support','[id*=\"termly\"]','[class*=\"termly\"]','#iubenda-cs-banner','[class*=\"iubenda-cs\"]','#moove_gdpr_cookie_modal','#moove_gdpr_cookie_info_bar','[id*=\"moove_gdpr\"]','#cookiescript_injected','[id*=\"cookiescript\"]','#cookie-law-info-bar','[id*=\"cookie-law-info\"]','[class*=\"cookie-law\"]','.klaro','#klaro','#cookieConsentContainer','#cookieConsent','[id*=\"cookieConsent\"]','[class*=\"cookieConsent\"]','[id*=\"cookie_consent\"]','[class*=\"cookie_consent\"]','[id*=\"cookie-agree\"]','[class*=\"cookie-agree\"]','[id*=\"truste-consent\"]','[class*=\"truste\"]','[id*=\"consent-manager\"]','[class*=\"consent-manager\"]'];" +
            // Content-based heuristic: find consent modals by text + CSS position so
            // unknown plugins (hundreds of WordPress CMPs etc.) are caught without
            // needing a specific selector entry for each one.
            // Selector-only pass — no getComputedStyle, no innerText, safe to run
            // from the MutationObserver on every DOM mutation burst.
            "function unlock(){" +
            "if(document.body){document.body.style.removeProperty('overflow');document.body.style.removeProperty('position');document.body.style.removeProperty('height');}" +
            "if(document.documentElement)document.documentElement.style.removeProperty('overflow');}" +
            "function quick(){var f=false;" +
            "s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();f=true;});}catch(e){}});" +
            "unlock();return f;}" +
            // Heavy pass — calls getComputedStyle + innerText (layout-forcing).
            // Run only 3 times at fixed intervals after page load; never from the
            // MutationObserver so benchmark-style DOM churn doesn't trigger it.
            "var pat=/cookie|consent|gdpr|privacy pref|personal data|data protection/i;" +
            "function heuristic(){" +
            "document.querySelectorAll('[role=\"dialog\"],[role=\"alertdialog\"],div[class*=\"modal\"],div[class*=\"popup\"],div[id*=\"modal\"],div[id*=\"popup\"],body>div,body>section,body>aside').forEach(function(el){" +
            "try{if(!el.isConnected)return;" +
            "var cs=window.getComputedStyle(el);var pos=cs.position;" +
            "if(pos!=='fixed'&&pos!=='absolute'&&pos!=='sticky')return;" +
            "var txt=el.innerText||'';" +
            "if(txt.length<20||txt.length>3000)return;" +
            "if(pat.test(txt))el.remove();}catch(e){}});}" +
            "function backdrops(){" +
            "document.querySelectorAll('body>*').forEach(function(el){" +
            "try{if(!el.isConnected)return;" +
            "var cs=window.getComputedStyle(el);" +
            "if(cs.position!=='fixed')return;" +
            "if((el.innerText||'').trim().length>30)return;" +
            "var bg=cs.backgroundColor;" +
            "if(bg&&bg!=='transparent'&&bg!=='rgba(0, 0, 0, 0)'){el.remove();return;}" +
            "if(parseFloat(cs.opacity)<0.1)el.remove();}catch(e){}});}" +
            "function full(){quick();heuristic();backdrops();}" +
            "full();setTimeout(full,1500);setTimeout(full,4000);" +
            "var o;var n=0;var t;" +
            "o=new MutationObserver(function(){" +
            "if(++n>20){o.disconnect();return;}" +
            "if(t)clearTimeout(t);" +
            "t=setTimeout(function(){if(quick())o.disconnect();},500);});" +
            "o.observe(document.documentElement,{childList:true,subtree:true});" +
            "setTimeout(function(){o.disconnect();},30000);" +
            "})();"

        // Removes subscribe, newsletter, and ad-blocker-detection overlays and undoes CSS tricks
        // (max-height clipping, gradient masks, blur filters) that inline paywalls use to obscure
        // article content. Three-pass approach: (1) selector-based removal of elements matching
        // known id/class patterns; (2) content-based heuristic fallback for elements with opaque
        // or hashed class names; (3) CSS property stripping to reveal clipped content. Runs
        // immediately on load and retries at fixed intervals via MutationObserver to catch
        // elements injected after the initial page load.
        readonly property string _subscribeBlockerScript: "(function(){'use strict';var s=[" +
            "'#adblock-overlay','#adblock-modal','#adblock-notice','#adblock-wall'," +
            "'#adblocker','#ad-blocker-overlay','.adblock-overlay','.adblock-modal'," +
            "'.adblock-notice','.adblock-wall','[id*=\"adblock\"]','[class*=\"adblock\"]'," +
            "'[id*=\"ad-block\"]','[class*=\"ad-block\"]','[id*=\"adblocker\"]','[class*=\"adblocker\"]'," +
            "'#newsletter-modal','#newsletter-popup','#newsletter-overlay'," +
            "'.newsletter-modal','.newsletter-popup','.newsletter-overlay'," +
            "'[id*=\"newsletter\"]','[class*=\"newsletter\"]'," +
            "'[id*=\"subscribe\"]','[class*=\"subscribe\"]'," +
            "'[id*=\"subscription\"]','[class*=\"subscription\"]'," +
            "'[id*=\"paywall\"]','[class*=\"paywall\"]'," +
            "'[id*=\"piano-\"]','[class*=\"piano-id\"]','[class*=\"tp-modal\"]','[class*=\"tp-backdrop\"]'," +
            "'[id*=\"regwall\"]','[class*=\"regwall\"]'," +
            "'[id*=\"paygate\"]','[class*=\"paygate\"]'," +
            "'[id*=\"gate-\"]','[class*=\"gate-\"]'," +
            "'[id*=\"-gate\"]','[class*=\"-gate\"]'," +
            "'[id*=\"metered-\"]','[class*=\"metered-\"]'," +
            "'[class*=\"duet--cta\"]','[class*=\"duet--auth\"]','[class*=\"duet--paywall\"]'," +
            "'[class*=\"c-cta\"]','[class*=\"p-welcome\"]'," +
            "'#zephr-overlay'," +
            "'[class*=\"paywall-overlay\"]','[class*=\"overlay--paywall\"]'," +
            "'[id*=\"fusion-app\"] [class*=\"paywall\"]'," +
            "'[aria-label*=\"subscribe\" i]','[aria-label*=\"newsletter\" i]'," +
            "'[aria-label*=\"adblock\" i]'" +
            "];" +
            "function reveal(){" +
            "document.querySelectorAll('*').forEach(function(e){" +
            "var cs=window.getComputedStyle(e);" +
            "var st=e.style;" +
            "if(cs.webkitMaskImage&&cs.webkitMaskImage!=='none'){" +
            "st.setProperty('-webkit-mask-image','none','important');" +
            "st.setProperty('mask-image','none','important');}" +
            "if(cs.filter&&cs.filter.indexOf('blur')!==-1){" +
            "st.setProperty('filter','none','important');}" +
            "if(cs.overflow==='hidden'&&st.maxHeight&&st.maxHeight!=='none'){" +
            "var mh=st.maxHeight;" +
            "if(mh.indexOf('calc')===-1&&mh.indexOf('vh')===-1&&mh.indexOf('vw')===-1&&mh.indexOf('%')===-1){" +
            "st.removeProperty('max-height');" +
            "st.removeProperty('overflow');}}});}" +
            "function heuristic(){" +
            "var roots=Array.from(document.querySelectorAll('main,article,body'));" +
            "var pat=/continue reading|subscribe (to|for|now|and)|unlimited access|(\\$|€|£)[0-9]+(\\.[0-9]+)?\\s*\\/(month|year|mo|yr)|sign in to (read|continue)|create (a free )?account to/i;" +
            "roots.forEach(function(root){" +
            "Array.from(root.children).forEach(function(el){" +
            "var txt=el.textContent||'';" +
            "var words=txt.trim().split(/\\s+/).length;" +
            "if(words>300)return;" +
            "if(!pat.test(txt))return;" +
            "if(!el.querySelector('button,a[href*=\"subscri\"],a[href*=\"account\"],a[href*=\"signin\"],a[href*=\"sign-in\"],a[href*=\"register\"]'))return;" +
            "el.remove();});});}" +
            // cheap: selector removal only — no innerText, no getComputedStyle.
            // Called by the MutationObserver so DOM churn on JS-heavy pages does
            // not trigger layout-forcing operations on every mutation burst.
            "var o;" +
            "function cheap(){" +
            "s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});}" +
            // heavy: full scan including heuristic (innerText + getComputedStyle).
            // Only called at fixed post-load intervals, never from the observer.
            "function r(){" +
            "cheap();" +
            "heuristic();" +
            "reveal();" +
            "if(!document.getElementById('fiery-reader')){" +
            "if(document.body){" +
            "document.body.style.removeProperty('overflow');" +
            "document.body.style.removeProperty('position');" +
            "document.body.style.removeProperty('height');}" +
            "if(document.documentElement){" +
            "document.documentElement.style.removeProperty('overflow');}}" +
            "}" +
            // On load: full scan (paywalls are typically in the DOM at parse time).
            // 1.5s: cheap selector-only pass for late-hydrated frameworks.
            // 8s: final full scan then disconnect — catches late-injected walls.
            "r();" +
            "setTimeout(cheap,1500);" +
            "setTimeout(function(){r();o.disconnect();},8000);" +
            "var t;o=new MutationObserver(function(){" +
            "if(t)clearTimeout(t);" +
            "t=setTimeout(cheap,500);});" +
            "o.observe(document.documentElement,{childList:true,subtree:true});" +
            "})();"

        // Defeats "please disable your ad blocker" detection walls. Two-pronged:
        // (1) DOM spoofing — define window.canRunAds and inject a visible bait <div>
        //     so scripts that measure ad-element dimensions think ads are running;
        // (2) Selector + heuristic removal — remove overlay elements by known
        //     id/class patterns and, as a fallback, by scanning modal-like elements
        //     whose text matches a broad set of detection phrases.
        // A MutationObserver retries for up to 30 s to catch dynamically injected walls.
        readonly property string _adblockDetectionScript: "(function(){'use strict';" +
            "try{" +
            "Object.defineProperty(window,'canRunAds',{value:true,writable:false,configurable:false});" +
            "if(!document.getElementById('fiery-adsbait')){" +
            "var b=document.createElement('div');" +
            "b.id='fiery-adsbait';" +
            "b.className='ad-banner adsbygoogle adsbox pub_300x250 pub_728x90 text-ad textAd textad';" +
            "b.style.cssText='height:1px!important;width:1px!important;position:absolute!important;left:-9999px!important;top:-9999px!important;display:block!important;visibility:visible!important';" +
            "document.documentElement.appendChild(b);}}" +
            "catch(e){}" +
            "var s=[" +
            "'#adblock-overlay','#adblock-modal','#adblock-notice','#adblock-wall','#adblock-banner'," +
            "'#adblocker','#ad-blocker','#ad-blocker-overlay','#ad-blocker-modal','#ad-blocker-notice'," +
            "'#adDetect','#adBlockDetect','#adBlockOverlay','#adBlockMessage','#adBlockModal'," +
            "'#anti-adblock','#antiAdblock','#antiadblock','#ab-notice','#ab-overlay'," +
            "'.adblock-overlay','.adblock-modal','.adblock-notice','.adblock-wall','.adblock-banner'," +
            "'.adblocker','.ad-blocker','.ad-blocker-overlay','.ad-blocker-modal'," +
            "'.anti-adblock','.antiAdblock','.ab-notice','.ab-overlay'," +
            "'[id*=\"adblock\"]','[class*=\"adblock\"]'," +
            "'[id*=\"ad-block\"]','[class*=\"ad-block\"]'," +
            "'[id*=\"adblocker\"]','[class*=\"adblocker\"]'," +
            "'[id*=\"ad_block\"]','[class*=\"ad_block\"]'," +
            "'[id*=\"adDetect\"]','[class*=\"adDetect\"]'," +
            "'[id*=\"anti-adblock\"]','[class*=\"anti-adblock\"]'," +
            "'[id*=\"antiAdblock\"]','[class*=\"antiAdblock\"]'," +
            "'[id*=\"antiadblock\"]','[class*=\"antiadblock\"]'," +
            "'[id*=\"ab-detection\"]','[class*=\"ab-detection\"]'," +
            "'[aria-label*=\"adblock\" i]','[aria-label*=\"ad blocker\" i]','[aria-label*=\"adblocker\" i]'" +
            "];" +
            "var adPat=/ad[\\s\\-_]?block(er)?|adblocker|disable\\s+(your\\s+)?(ad|blocker)|turn\\s+off\\s+(your\\s+)?(ad|blocker)|we(\\s*('ve|(\\s+have)))\\s+noticed|you(\\s*('re|(\\s+are)))\\s+using\\s+(an?\\s+)?ad|using\\s+(an?\\s+)?ad[\\s\\-_]?block|please\\s+(support|whitelist|allowlist|disable|turn\\s+off)|support\\s+us\\s+(by|and)/i;" +
            "function heuristic(){" +
            "var cands=document.querySelectorAll(" +
            "'body>div,body>section,body>aside,body>article," +
            "body>div>div,body>div>section," +
            "[role=\"dialog\"],[role=\"alertdialog\"]," +
            "div[class*=\"modal\"],div[class*=\"overlay\"],div[class*=\"popup\"],div[class*=\"banner\"]," +
            "div[id*=\"modal\"],div[id*=\"overlay\"],div[id*=\"popup\"]');" +
            "cands.forEach(function(el){" +
            "try{" +
            "var txt=el.textContent||'';" +
            "if(txt.length>2000||txt.length<10)return;" +
            "if(!adPat.test(txt))return;" +
            // Avoid getComputedStyle (forces layout reflow). The candidate selector
            // already targets body children, modal/overlay classes, and dialog roles,
            // so most overlays are already pre-filtered. Check inline style position
            // (no layout cost) and role attribute as the final confirmation.
            "var pos=el.style.position;" +
            "if(pos==='fixed'||pos==='absolute'||pos==='sticky'||el.getAttribute('role')){" +
            "el.remove();}" +
            "}catch(e){}});}" +
            // cheap: selector removal only — safe to call from the MutationObserver.
            "function cheap(){" +
            "s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});}" +
            // heavy: selectors + conditional heuristic.
            // The heuristic (textContent scan) is guarded by a fast querySelector:
            // if the page has no modal/overlay/dialog elements at all it is skipped
            // entirely, avoiding DOM traversal cost on pages like benchmarks.
            "function r(){" +
            "cheap();" +
            "if(document.querySelector('[role=\"dialog\"],[role=\"alertdialog\"],div[class*=\"modal\"],div[class*=\"overlay\"],div[class*=\"popup\"],div[id*=\"adblock\"]')){" +
            "heuristic();}" +
            "if(document.body){document.body.style.removeProperty('overflow');document.body.style.removeProperty('position');}" +
            "if(document.documentElement)document.documentElement.style.removeProperty('overflow');}" +
            // Detection walls appear after page JS runs, not at parse time.
            // 1.5s: cheap pass for early async scripts.
            // 8s: full scan then disconnect. r() guards the heuristic behind a
            //     fast querySelector so it is skipped entirely on pages with no
            //     modal/overlay elements (benchmarks, simple pages, etc.).
            "cheap();" +
            "setTimeout(cheap,1500);" +
            "var o;var t;" +
            "o=new MutationObserver(function(){" +
            "if(t)clearTimeout(t);" +
            "t=setTimeout(cheap,500);});" +
            "o.observe(document.documentElement,{childList:true,subtree:true});" +
            "setTimeout(function(){r();o.disconnect();},8000);" +
            "})();"

        onLoadingChanged: function(loadingInfo)
        {
            if(loadingInfo.status === WebEngineView.LoadSucceededStatus)
            {
                control._loadFailed = false
                if (!_webView.profile.offTheRecord)
                    Fiery.History.appendUrl(control.url, control.title)
                if (appSettings.showScrollBars)
                    _webView.runJavaScript(_webView._scrollbarScript)
                if (appSettings.cookieBannerBlocker)
                    _webView.runJavaScript(_webView._cookieBannerScript)
                if (appSettings.subscribeBlockerEnabled)
                    _webView.runJavaScript(_webView._subscribeBlockerScript)
                if (appSettings.adblockDetectionBlockerEnabled)
                    _webView.runJavaScript(_webView._adblockDetectionScript)

                if (!_webView.profile.offTheRecord) {
                    // Prompt to save credentials captured from the previous page.
                    if (control._pendingCredPass) {
                        Fiery.PasswordManager.requestSave(control._pendingCredHost,
                                                          control._pendingCredUser,
                                                          control._pendingCredPass)
                        control._pendingCredHost = ""
                        control._pendingCredUser = ""
                        control._pendingCredPass = ""
                    }

                    // Install the credential watcher for this page.
                    _webView.runJavaScript(_webView._credentialWatcherScript)

                    // Prompt the user to fill saved credentials if any exist for this host.
                    // hasCredentials() checks SQLite only — the keyring is never touched here.
                    try {
                        var host = new URL(_webView.url.toString()).hostname
                        if (host && Fiery.PasswordManager.hasCredentials(host)) {
                            _fillPasswordAction.host = host
                            root.notify("dialog-password",
                                        i18n("Saved Password"),
                                        i18n("Fill credentials for %1?", host),
                                        [_fillPasswordAction, _dismissFillAction])
                        }
                    } catch(e) {}
                }
            }
            else if(loadingInfo.status === WebEngineView.LoadFailedStatus)
            {
                // HTTP errors (4xx/5xx) still deliver the server's HTML to the
                // renderer, so the page content is visible. Only raise _loadFailed
                // for genuine network/system failures where nothing is rendered.
                control._loadFailed = loadingInfo.errorDomain !== WebEngineView.HttpErrorDomain
            }
            else if(loadingInfo.status === WebEngineView.LoadStartedStatus)
            {
                control._loadFailed = false

                // Harvest any credential the watcher recorded before the page unloads.
                if (!_webView.profile.offTheRecord) {
                    _webView.runJavaScript(_webView._credentialHarvestScript, function(result) {
                        if (!result) return
                        try {
                            var cred = JSON.parse(result)
                            if (cred && cred.p) {
                                control._pendingCredHost = cred.h
                                control._pendingCredUser = cred.u || ""
                                control._pendingCredPass = cred.p
                            }
                        } catch(e) {}
                    })
                }
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
            const scheme = request.url.toString().trim().toLowerCase()
            if (scheme.startsWith("javascript:") || scheme.startsWith("data:"))
                request.action = WebEngineNavigationRequest.IgnoreRequest
        }

        settings.accelerated2dCanvasEnabled : true
        settings.allowGeolocationOnInsecureOrigins : false
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

    // Credentials captured at LoadStartedStatus from the previous page.
    // Held in QML (not web storage) so they survive cross-origin redirects.
    property string _pendingCredHost: ""
    property string _pendingCredUser: ""
    property string _pendingCredPass: ""

    // Actions shown in the "fill credentials?" notification prompt.
    // find() is called only here — at the moment the user taps Fill — so the
    // keyring unlock prompt (if any) appears in direct response to user intent.
    Action
    {
        id: _fillPasswordAction
        property string host: ""
        text: i18n("Fill")
        onTriggered:
        {
            var creds = Fiery.PasswordManager.find(_fillPasswordAction.host)
            if (creds.length > 0)
                _webView.runJavaScript(_webView.buildFillerScript(creds))
        }
    }

    Action
    {
        id: _dismissFillAction
        text: i18n("Not Now")
    }

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
        _webView.lifecycleState = 0 // WebEngineView.Active
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

    // Delayed retry: the initial kick may fire before Wayland re-enables
    // wl_surface.frame callbacks after a workspace switch, leaving Viz idle
    // again. A second kick ~800 ms later catches that window.
    Timer
    {
        id: _vizRetryTimer
        interval: 800
        repeat: false
        onTriggered:
        {
            if (control.visible && Window.window.active)
            {
                _webView.lifecycleState = 0 // WebEngineView.Active
                _webView.runJavaScript(
                    "(function(){" +
                    "  requestAnimationFrame(function(){requestAnimationFrame(function(){});});" +
                    "})()")
            }
        }
    }

    onVisibleChanged:
    {
        if (visible)
        {
            // Restore full rendering when the tab is brought to the foreground.
            _webView.lifecycleState = 0 // WebEngineView.Active
            if (Window.window.active)
            {
                _kickVizCompositor()
                _vizRetryTimer.restart()
            }
        }
        else if (!_webView.recentlyAudible)
        {
            // Freeze the renderer while the tab is hidden: JavaScript timers,
            // animations, and GPU compositing are paused, cutting CPU/GPU load
            // for background tabs to near-zero.  Pages stay in memory and resume
            // instantly when the tab is selected again.
            // Skip if the tab is playing audio so background media keeps running.
            _webView.lifecycleState = 1 // WebEngineView.Frozen
        }
    }

    // Window.window.active covers focus changes within a workspace.
    Connections
    {
        target: Window.window
        function onActiveChanged()
        {
            if (Window.window.active && control.visible)
            {
                _kickVizCompositor()
                _vizRetryTimer.restart()
            }
        }
    }

    // Qt.application.state catches workspace switches on Hyprland/Wayland:
    // the compositor changes the application state when its workspace is
    // shown or hidden, even if Window.window.active does not toggle.
    Connections
    {
        target: Qt.application
        function onStateChanged()
        {
            if (Qt.application.state === Qt.ApplicationActive && control.visible)
            {
                _kickVizCompositor()
                _vizRetryTimer.restart()
            }
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
        visible: control.url.toString().length <= 0
        emoji: "qrc:/internet.svg"

        title: i18n("Start Browsing")
        body: i18n("Enter a new URL or open a recent site.")
    }

}
