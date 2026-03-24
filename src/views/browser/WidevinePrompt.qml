import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui
import org.maui.fiery as Fiery

Maui.InfoDialog
{
    id: control

    title: i18n("Enable DRM Playback")

    message: i18n("Downloads the Widevine CDM (~8 MB).\n\n"
                  + "Proprietary software subject to Google's Terms of Service.\n\n"
                  + "Takes effect after restart.")

    template.iconSource: "media-playback-start"

    standardButtons: Dialog.Ok | Dialog.Cancel

    readonly property bool _isActive:
        Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Downloading ||
        Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Extracting

    Component.onCompleted:
    {
        var btn = standardButton(Dialog.Ok)
        if (btn) btn.palette.buttonText = Maui.Theme.positiveTextColor
    }

    Connections
    {
        target: Fiery.WidevineInstaller
        function onStateChanged()
        {
            var btn = control.standardButton(Dialog.Ok)
            if (btn) btn.enabled = !control._isActive

            if (Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Ready) {
                control.alert(i18n("Installed. Restart Fiery to enable DRM."), 0)
                Qt.callLater(function() { control.close() })
            } else if (Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Failed) {
                control.alert(Fiery.WidevineInstaller.statusMessage, 2)
            }
        }
        function onProgressChanged()
        {
            _progressBar.value = Fiery.WidevineInstaller.progress / 100.0
        }
    }

    ProgressBar
    {
        id: _progressBar
        Layout.fillWidth: true
        visible: control._isActive
        indeterminate: Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Extracting
        value: 0
    }

    onAccepted:
    {
        if (Fiery.WidevineInstaller.state === Fiery.WidevineInstaller.Ready)
            close()
        else
            Fiery.WidevineInstaller.install()
    }

    onRejected:
    {
        if (control._isActive)
            Fiery.WidevineInstaller.cancel()
        close()
    }
}
