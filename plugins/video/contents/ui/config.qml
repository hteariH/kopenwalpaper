/*
 * KOpenWallpaper — configuration page shown in
 * System Settings / Desktop Settings → Wallpaper Type.
 *
 * Each persisted key Foo in config/main.xml is bound here through the
 * convention property cfg_Foo (+ cfg_FooDefault, injected by Plasma).
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: cfg

    // Injected by the Plasma wallpaper config host; declared so assignment
    // doesn't fail with "FormLayout does not have a property…".
    property var configDialog
    property var wallpaperConfiguration

    // --- bound configuration properties (cfg_<Key>) ---
    property alias cfg_VideoUrl: pathField.text
    property alias cfg_PauseWhenObscured: pauseBox.checked
    property int cfg_FillMode
    property string cfg_BackgroundColor
    property alias cfg_Muted: muteBox.checked
    property alias cfg_Volume: volumeSlider.value
    property alias cfg_PlaybackRate: rateSpin.realValue

    // ---- Video file ----
    RowLayout {
        Kirigami.FormData.label: i18n("Video file:")

        QQC2.TextField {
            id: pathField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            placeholderText: i18n("Path to an mp4 / webm / mkv file…")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: fileDialog.open()
        }
    }

    // ---- Fill mode ----
    QQC2.ComboBox {
        Kirigami.FormData.label: i18n("Fill mode:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Crop (fill screen)"), value: 2 },
            { text: i18n("Fit (keep aspect, letterbox)"), value: 1 },
            { text: i18n("Stretch"), value: 0 }
        ]
        currentIndex: indexOfValue(cfg.cfg_FillMode)
        onActivated: cfg.cfg_FillMode = currentValue
    }

    // ---- Background color (behind letterboxing) ----
    RowLayout {
        Kirigami.FormData.label: i18n("Background color:")

        Rectangle {
            implicitWidth: Kirigami.Units.gridUnit * 2
            implicitHeight: Kirigami.Units.gridUnit * 1.4
            radius: 3
            color: cfg.cfg_BackgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
        }
        QQC2.Button {
            text: i18n("Change…")
            onClicked: colorDialog.open()
        }
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Audio ----
    QQC2.CheckBox {
        id: muteBox
        Kirigami.FormData.label: i18n("Audio:")
        text: i18n("Mute")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Volume:")
        enabled: !muteBox.checked

        QQC2.Slider {
            id: volumeSlider
            from: 0; to: 100; stepSize: 1
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.Label { text: Math.round(volumeSlider.value) + "%" }
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Playback speed ----
    QQC2.SpinBox {
        id: rateSpin
        Kirigami.FormData.label: i18n("Playback speed:")
        property real realValue: 1.0
        from: 25; to: 400; stepSize: 25
        value: Math.round(realValue * 100)
        textFromValue: function(v) { return (v / 100).toFixed(2) + "×" }
        valueFromText: function(t) { return Math.round(parseFloat(t) * 100) }
        onValueModified: realValue = value / 100
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: pauseBox
        Kirigami.FormData.label: i18n("Power saving:")
        text: i18n("Pause while a window is maximized or fullscreen")
    }

    // ---- Dialogs ----
    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a video")
        nameFilters: [
            i18n("Videos (*.mp4 *.webm *.mkv *.ogv *.mov)"),
            i18n("All files (*)")
        ]
        onAccepted: pathField.text = selectedFile
    }

    QtDialogs.ColorDialog {
        id: colorDialog
        selectedColor: cfg.cfg_BackgroundColor
        onAccepted: cfg.cfg_BackgroundColor = selectedColor
    }
}
