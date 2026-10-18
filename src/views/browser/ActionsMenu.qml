import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import QtWebEngine
import org.mauikit.controls as Maui

Maui.ContextualMenu
{
    id: control
    property ContextMenuRequest request
    property WebEngineView webView

    property bool isValidUrl: request && request.linkUrl != "" // not strict equality
    property bool isAudio: request && request.mediaType === ContextMenuRequest.MediaTypeAudio
    property bool isImage: request && request.mediaType === ContextMenuRequest.MediaTypeImage
    property bool isVideo: request && request.mediaType === ContextMenuRequest.MediaTypeVideo
    property bool hasSelectedText: request && request.selectedText.length > 0
    property bool isContentEditable: request && request.isContentEditable
    property bool canSaveMedia: request && !!(request.mediaFlags & ContextMenuRequest.MediaCanSave)
    property bool canToggleMediaControls: request && !!(request.mediaFlags & ContextMenuRequest.MediaCanToggleControls)
    property bool interactiveMedia: (isAudio || isVideo)
                                  && !isValidUrl
                                  && !(request.mediaFlags & ContextMenuRequest.MediaInError)
                                  && (canSaveMedia || canToggleMediaControls)
    property bool hasEditActions: isContentEditable && (!!(request.editFlags & ContextMenuRequest.CanUndo) || !!(request.editFlags & ContextMenuRequest.CanRedo) || !!(request.editFlags & ContextMenuRequest.CanCut) || !!(request.editFlags & ContextMenuRequest.CanCopy) || !!(request.editFlags & ContextMenuRequest.CanPaste) || !!(request.editFlags & ContextMenuRequest.CanSelectAll))
    property bool hasTextActions: hasEditActions || (hasSelectedText && !!(request.editFlags & ContextMenuRequest.CanCopy))
    readonly property bool hasContextActions: hasEditActions || hasSelectedText || isValidUrl || isImage || interactiveMedia
    readonly property bool hasActions: webView !== null || hasContextActions
    // WebEngineView has no isFullScreen property; the fullscreen state is tracked
    // on the Browser wrapper item and passed in here explicitly.
    property bool webFullScreen: false

    // Unique attribute value stamped onto the target element the moment the
    // context menu opens.  All JS actions use querySelector on this attribute
    // rather than re-evaluating elementFromPoint at trigger time, preventing a
    // malicious page from injecting a different element into those coordinates
    // between menu-open and menu-item-click.
    property string contextElemId: ""
    property int playbackRate: 100

    MenuItem
    {
        text: i18n("Back")
        height: visible ? implicitHeight : -control.spacing
        visible: control.webView !== null
        enabled: control.webView && control.webView.canGoBack
        onTriggered: control.webView.triggerWebAction(WebEngineView.Back)
    }

    MenuItem
    {
        text: i18n("Forward")
        height: visible ? implicitHeight : -control.spacing
        visible: control.webView !== null
        enabled: control.webView && control.webView.canGoForward
        onTriggered: control.webView.triggerWebAction(WebEngineView.Forward)
    }

    MenuItem
    {
        text: i18n("Reload")
        height: visible ? implicitHeight : -control.spacing
        visible: control.webView !== null
        onTriggered: control.webView.triggerWebAction(WebEngineView.Reload)
    }

    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.hasContextActions
    }

    MenuItem
    {
        text: i18n("Undo")
        height: visible ? implicitHeight : -control.spacing
        visible: isContentEditable && !!(request.editFlags & ContextMenuRequest.CanUndo)
        onTriggered: webView.triggerWebAction(WebEngineView.Undo)
    }

    MenuItem
    {
        text: i18n("Redo")
        height: visible ? implicitHeight : -control.spacing
        visible: isContentEditable && !!(request.editFlags & ContextMenuRequest.CanRedo)
        onTriggered: webView.triggerWebAction(WebEngineView.Redo)
    }

    MenuItem
    {
        text: i18n("Cut")
        height: visible ? implicitHeight : -control.spacing
        visible: isContentEditable && !!(request.editFlags & ContextMenuRequest.CanCut)
        onTriggered: webView.triggerWebAction(WebEngineView.Cut)
    }

    MenuItem
    {
        text: i18n("Paste")
        height: visible ? implicitHeight : -control.spacing
        visible: isContentEditable && !!(request.editFlags & ContextMenuRequest.CanPaste)
        onTriggered:
        {
            //            control.close()
            webView.triggerWebAction(WebEngineView.Paste);
            //            pasteAction.trigger()
        }
    }

    MenuItem
    {
        text: i18n("Select all")
        height: visible ? implicitHeight : -control.spacing
        visible: isContentEditable && !!(request.editFlags & ContextMenuRequest.CanSelectAll)
        onTriggered:
        {
            webView.triggerWebAction(WebEngineView.SelectAll);
        }
    }


    MenuItem
    {
        text: i18n("Copy")
        height: visible ? implicitHeight : -control.spacing
        visible: hasSelectedText && !!(request.editFlags & ContextMenuRequest.CanCopy)
        onTriggered: webView.triggerWebAction(WebEngineView.Copy)
    }

    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.hasTextActions && control.isValidUrl
    }

    MenuItem
    {
        text: i18n("Copy Link")
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl
        onTriggered:
        {
            Maui.Handy.copyTextToClipboard(control.request.linkUrl)
        }
    }

    MenuItem
    {
        text: i18n("Open Link")
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl
        onTriggered:
        {
            openUrl(control.request.linkUrl)
        }
    }

    MenuItem
    {
        text: i18n("Open Link in New Tab")
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl
        onTriggered:
        {
            openTab(control.request.linkUrl)
        }
    }

    MenuItem
    {
        text: i18n("Open Link in Split View")
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl
        onTriggered:
        {
            openSplit( control.request.linkUrl);
        }
    }

    MenuItem
    {
        text: i18n("Open Link in New Window")
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl
        onTriggered:
        {
            newWindow([control.request.linkUrl]);
        }
    }


    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.isValidUrl && control.hasSelectedText
    }

    MenuItem
    {
        property string fullText: control.request ? control.request.selectedText || control.request.linkText : ""
        property string elidedText: fullText.length > 25 ? fullText.slice(0, 25) + "..." : fullText
        height: visible ? implicitHeight : -control.spacing
        visible: control.hasSelectedText
        text:  i18n('Search for "%1"', elidedText)
        onTriggered:
        {
            openTab(appSettings.searchEnginePage + encodeURIComponent(fullText));
        }
    }

    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: (control.hasSelectedText || control.isValidUrl)
                  && (control.isImage || control.interactiveMedia)
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.interactiveMedia && control.isVideo && control.canSaveMedia
        text: i18n("Save Video")
        onTriggered: webView.triggerWebAction(WebEngineView.DownloadMediaToDisk)
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.isImage
        text: i18n("Save Image")
        onTriggered: webView.triggerWebAction(WebEngineView.DownloadImageToDisk)
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.isImage
        text: i18n("Copy Image")
        onTriggered: webView.triggerWebAction(WebEngineView.CopyImageToClipboard)
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.isImage && control.request.mediaUrl !== url
        text: i18n("Open Image")
        onTriggered:
        {
            openTab(control.request.mediaUrl)
        }
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.interactiveMedia
        text: control.request && control.request.mediaFlags & ContextMenuRequest.MediaPaused
              ? i18n("Play")
              : i18n("Pause")
        onTriggered: webView.triggerWebAction(WebEngineView.ToggleMediaPlayPause)
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.interactiveMedia
                 && !!(control.request.mediaFlags & ContextMenuRequest.MediaHasAudio)
        text:  control.request && control.request.mediaFlags & ContextMenuRequest.MediaMuted
               ? i18n("Unmute")
               : i18n("Mute")
        onTriggered: webView.triggerWebAction(WebEngineView.ToggleMediaMute)
    }

    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: webView.settings.javascriptEnabled && control.interactiveMedia
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: webView.settings.javascriptEnabled && control.interactiveMedia
        contentItem: RowLayout
        {
            Label
            {
                Layout.fillWidth: true
                text: i18n("Speed")
            }

            SpinBox
            {
                value: control.playbackRate
                from: 25
                to: 1000
                stepSize: 25
                onValueModified: {
                    control.playbackRate = value
                    const js = '(function(id,rate){' +
                               '  var e=document.querySelector("[data-fiery-ctx="+JSON.stringify(id)+"]");' +
                               '  if(e) e.playbackRate=rate;' +
                               '})(' + JSON.stringify(control.contextElemId) + ',' + (control.playbackRate / 100) + ')'
                    webView.runJavaScript(js)
                }
                textFromValue: function(value, locale) {
                    return Number(value / 100).toLocaleString(locale, 'f', 2)
                }
            }
        }
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: control.interactiveMedia
                 && !!(control.request.mediaFlags & ContextMenuRequest.MediaLoop)
        text: i18n("Loop")
        onTriggered: webView.triggerWebAction(WebEngineView.ToggleMediaLoop)
    }

    MenuSeparator
    {
        height: visible ? implicitHeight : -control.spacing
        visible: webView.settings.javascriptEnabled && control.interactiveMedia && control.isVideo
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: webView.settings.javascriptEnabled && control.interactiveMedia && control.isVideo
        text: control.webFullScreen ? i18n("Exit fullscreen") : i18n("Fullscreen")
        onTriggered: {
            const js = control.webFullScreen
                ? 'document.exitFullscreen()'
                : '(function(id){' +
                  '  var e=document.querySelector("[data-fiery-ctx="+JSON.stringify(id)+"]");' +
                  '  if(e) e.requestFullscreen();' +
                  '})(' + JSON.stringify(control.contextElemId) + ')'
            webView.runJavaScript(js)
        }
    }

    MenuItem
    {
        height: visible ? implicitHeight : -control.spacing
        visible: webView.settings.javascriptEnabled
                 && control.interactiveMedia
                 && control.canToggleMediaControls
        text: control.request && control.request.mediaFlags & ContextMenuRequest.MediaControls
              ? i18n("Hide controls")
              : i18n("Show controls")
        onTriggered: webView.triggerWebAction(WebEngineView.ToggleMediaControls)
    }

}
