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

    height: ListView.view ? ListView.view.height : 0
    width:  ListView.view ? ListView.view.width : 0

    Maui.Controls.title: title
    Maui.Controls.toolTipText:  _webView.url

    property bool _webFullScreen: false
    property string _hoveredUrl: ""
    property var _pendingFileRequest: null

    property bool _isSleeping: false
    property bool _drmNotified: false

    WidevinePrompt { id: _widevinePrompt }

    Timer
    {
        id: _sleepTimer
        repeat: false
        interval: Math.max(1, appSettings.tabSleepDelay) * 60000
        onTriggered:
        {
            const u = _webView.url.toString()
            if (u.length > 0 && u !== "about:blank" && !_webView.loading)
            {
                _webView.lifecycleState = 2 // WebEngineView.Discarded — frees GPU+CPU memory
                control._isSleeping = true
            }
        }
    }

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

    // Anti-phishing overlay shown for 4 s on fullscreen entry.
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
        webFullScreen: control._webFullScreen
    }

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
            if (!visible && control._pendingFileRequest !== null)
            {
                control._pendingFileRequest.reject()
                control._pendingFileRequest = null
            }
        }
    }

    // Opaque backdrop for error pages (window uses transparent compositing).
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
        // Chromium infers prefers-color-scheme from backgroundColor.
        // Blank tabs and force-dark mode use the theme color; otherwise white.
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
            request.accepted = true
            _menu.request = request

            // Tag the element under the pointer now so JS actions target the
            // correct element at trigger time, not a page-injected replacement.
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

        // Captures credentials from password fields on user input and stores them
        // under a Symbol key (window._fieryCK) for later harvesting.
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
            "document.addEventListener('submit',function(e){" +
            "var f=e.target;if(!f)return;" +
            "if(!f.querySelector('input[type=\"password\"]'))return;" +
            "if(typeof window[_k]==='string')console.log('__FIERY_CRED_READY__');" +
            "},{capture:true});" +
            "})()"

        // Reads and clears the credential stored by the watcher.
        readonly property string _credentialHarvestScript:
            "(function(){" +
            "var _k=window._fieryCK;" +
            "if(!_k)return null;" +
            "var c=typeof window[_k]==='string'?window[_k]:null;" +
            "window[_k]=true;" +
            "return c;" +
            "})()"

        function buildFillerScript(creds) {
            var safe = creds.map(function(c) {
                return {
                    username: typeof c.username === 'string' ? c.username : '',
                    password: typeof c.password === 'string' ? c.password : ''
                }
            })
            var json = JSON.stringify(safe)
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

        // Removes cookie consent banners. Selector list + heuristic fallback +
        // MutationObserver (disconnects after 20 callbacks or 30 s).
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

        // Removes subscribe/paywall/newsletter overlays and undoes CSS clipping tricks.
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
            "var o;" +
            "function cheap(){" +
            "s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});}" +
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
            "r();" +
            "setTimeout(cheap,1500);" +
            "setTimeout(function(){r();o.disconnect();},8000);" +
            "var t;o=new MutationObserver(function(){" +
            "if(t)clearTimeout(t);" +
            "t=setTimeout(cheap,500);});" +
            "o.observe(document.documentElement,{childList:true,subtree:true});" +
            "})();"

        // Defeats ad-blocker detection walls via DOM spoofing and overlay removal.
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
            "var pos=el.style.position;" +
            "if(pos==='fixed'||pos==='absolute'||pos==='sticky'||el.getAttribute('role')){" +
            "el.remove();}" +
            "}catch(e){}});}" +
            "function cheap(){" +
            "s.forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});}" +
            "function r(){" +
            "cheap();" +
            "if(document.querySelector('[role=\"dialog\"],[role=\"alertdialog\"],div[class*=\"modal\"],div[class*=\"overlay\"],div[class*=\"popup\"],div[id*=\"adblock\"]')){" +
            "heuristic();}" +
            "if(document.body){document.body.style.removeProperty('overflow');document.body.style.removeProperty('position');}" +
            "if(document.documentElement)document.documentElement.style.removeProperty('overflow');}" +
            "cheap();" +
            "setTimeout(cheap,1500);" +
            "var o;var t;" +
            "o=new MutationObserver(function(){" +
            "if(t)clearTimeout(t);" +
            "t=setTimeout(cheap,500);});" +
            "o.observe(document.documentElement,{childList:true,subtree:true});" +
            "setTimeout(function(){r();o.disconnect();},8000);" +
            "})();"

        // Intercepts Widevine EME requests and emits a sentinel for the Qt side.
        readonly property string _drmDetectionScript:
            "(function(){" +
            "if(window.__fieryDrmHooked)return;" +
            "window.__fieryDrmHooked=true;" +
            "var _orig=navigator.requestMediaKeySystemAccess.bind(navigator);" +
            "navigator.requestMediaKeySystemAccess=function(ks,cfg){" +
            "if(ks==='com.widevine.alpha')" +
            "console.warn('__FIERY_DRM_REQUIRED__');" +
            "return _orig(ks,cfg);" +
            "};" +
            "})()"

        // YouTube ad blocker: skips/fast-forwards ads via MutationObserver + interval.
        readonly property string _youtubeAdBlockScript:
            "(function(){'use strict';" +
            "if(!location.hostname.includes('youtube.com'))return;" +
            "if(window._fieryYtAdBlock)return;" +
            "window._fieryYtAdBlock=true;" +
            "var _iv=null,_obs=null,_bgIv=null;" +
            "function vid(){return document.querySelector('#movie_player video,.html5-video-player video');}" +
            "function player(){return document.querySelector('#movie_player,.html5-video-player');}" +
            "function adOn(){" +
            "var p=player();if(!p)return false;" +
            "if(p.classList.contains('ad-showing')||p.classList.contains('ad-interrupting'))return true;" +
            "return!!(document.querySelector('.ytp-ad-player-overlay,.ytp-ad-simple-ad-badge,.ytp-ad-preview-container'));}" +
            "function skip(){" +
            "var b=document.querySelector(" +
            "'.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-ad-skip-button-slot button');" +
            "if(b&&b.offsetParent!==null){b.click();return true;}return false;}" +
            "function overlays(){" +
            "['.ytp-ad-player-overlay','.ytp-ad-text-overlay','.ytp-ad-image-overlay'," +
            "'.ytp-featured-product','.ytp-suggested-action','.ytp-ad-action-interstitial']" +
            ".forEach(function(q){try{document.querySelectorAll(q).forEach(function(e){e.remove();});}catch(e){}});}" +
            "function handle(){" +
            "if(!adOn()){" +
            "var v=vid();if(v&&v._fiery){if(!v._fiery.m)v.muted=false;if(v.playbackRate>1)v.playbackRate=v._fiery.r||1;delete v._fiery;}" +
            "stop();return;}" +
            "if(skip()){overlays();return;}" +
            "var v=vid();" +
            "if(v){if(!v._fiery)v._fiery={m:v.muted,r:v.playbackRate};" +
            "v.muted=true;v.playbackRate=16;" +
            "if(v.duration&&isFinite(v.duration)&&v.duration-v.currentTime>0.1){try{v.currentTime=v.duration-0.1;}catch(e){}}}" +
            "overlays();}" +
            "function start(){if(!_iv)_iv=setInterval(handle,150);}" +
            "function stop(){if(_iv){clearInterval(_iv);_iv=null;}}" +
            "function attach(){" +
            "var p=player();if(!p)return false;" +
            "if(_obs)_obs.disconnect();" +
            "_obs=new MutationObserver(function(){if(adOn()){handle();start();}else{stop();handle();}});" +
            "_obs.observe(p,{attributes:true,attributeFilter:['class']});" +
            "if(adOn()){handle();start();}return true;}" +
            "function init(){" +
            "if(!attach()){" +
            "var bo=new MutationObserver(function(){if(attach())bo.disconnect();});" +
            "bo.observe(document.documentElement,{childList:true,subtree:true});" +
            "setTimeout(function(){bo.disconnect();},30000);}}" +
            "_bgIv=setInterval(function(){if(adOn()&&!_iv){handle();start();}},1000);" +
            "document.addEventListener('yt-navigate-finish',function(){" +
            "stop();if(_obs){_obs.disconnect();_obs=null;}init();});" +
            "init();" +
            "})()"

        onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceId)
        {
            if (message === "__FIERY_CRED_READY__" && !_webView.profile.offTheRecord) {
                _webView.runJavaScript(_webView._credentialHarvestScript, function(result) {
                    if (!result) return
                    try {
                        var cred = JSON.parse(result)
                        if (cred && cred.p)
                            Fiery.PasswordManager.requestSave(cred.h, cred.u || "", cred.p)
                    } catch(e) {}
                })
            }
            if (message === "__FIERY_DRM_REQUIRED__"
                    && !_webView.profile.offTheRecord
                    && !Fiery.WidevineInstaller.isInstalled
                    && !control._drmNotified)
            {
                control._drmNotified = true
                root.notify("dialog-information",
                            i18n("DRM Content"),
                            i18n("This page requires Widevine DRM. Enable it in Settings → Features."),
                            [])
            }
        }

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
                if (appSettings.adBlockEnabled && _webView.url.toString().indexOf("youtube.com") !== -1)
                    _webView.runJavaScript(_webView._youtubeAdBlockScript)
                if (!_webView.profile.offTheRecord)
                    _webView.runJavaScript(_webView._drmDetectionScript)

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
                control._drmNotified = false

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

        // Thin themed scrollbar via injected CSS; colors sampled from MauiKit theme.
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
                "'::-webkit-scrollbar{display:block!important;width:6px!important;height:6px!important;}'" +
                "+'::-webkit-scrollbar-track{background:transparent!important;}'" +
                "+'::-webkit-scrollbar-thumb{background:" + thumb + "!important;border-radius:3px!important;}'" +
                "+'::-webkit-scrollbar-thumb:hover{background:" + thumbHover + "!important;}'" +
                "+'::-webkit-scrollbar-thumb:active{background:" + thumbActive + "!important;}'" +
                "+'::-webkit-scrollbar-corner{background:transparent!important;}';" +
                "})();"
        }
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
            if (control.visible && Window.window && Window.window.active)
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
            // Cancel any pending sleep countdown and clear the sleeping flag.
            _sleepTimer.stop()
            _isSleeping = false
            // Restore full rendering when the tab is brought to the foreground.
            _webView.lifecycleState = 0 // WebEngineView.Active
            if (Window.window && Window.window.active)
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
            // Start the sleep countdown: if the tab stays hidden long enough,
            // the timer will discard the page entirely to reclaim more memory.
            if (appSettings.tabSleepEnabled)
                _sleepTimer.restart()
        }
    }

    // Window.window.active covers focus changes within a workspace.
    Connections
    {
        target: Window.window
        function onActiveChanged()
        {
            if (Window.window && Window.window.active && control.visible)
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
            font.pointSize: Maui.Style.fontSizes.small
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
