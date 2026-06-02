/*
 * KOpenWallpaper (Shader) — configuration page.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: cfg

    property var configDialog
    property var wallpaperConfiguration

    property string cfg_Preset
    property alias cfg_PauseWhenObscured: pauseBox.checked
    property alias cfg_CustomShaderUrl: customField.text
    property alias cfg_ImageUrl: imageField.text
    property alias cfg_Speed: speedSpin.realValue
    property alias cfg_BreatheAmount: breatheSlider.value
    property alias cfg_SwayAmount: swaySlider.value
    property alias cfg_Aberration: aberrationSlider.value
    property alias cfg_BokehAmount: bokehSlider.value
    property alias cfg_Vignette: vignetteSlider.value

    // Reusable 0–200 % effect slider row, used for the Living-image controls.
    component FxSlider: RowLayout {
        property alias value: slider.value
        enabled: presetBox.currentValue === "image"
        QQC2.Slider {
            id: slider
            from: 0.0; to: 2.0; stepSize: 0.05
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.Label {
            text: Math.round(slider.value * 100) + "%"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
        }
    }

    QQC2.ComboBox {
        id: presetBox
        Kirigami.FormData.label: i18n("Shader:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Living image (animate a picture)"), value: "image" },
            { text: i18n("Plasma"), value: "plasma" },
            { text: i18n("Waves"), value: "waves" },
            { text: i18n("Starfield"), value: "starfield" },
            { text: i18n("Custom (.qsb)…"), value: "custom" }
        ]
        currentIndex: Math.max(0, indexOfValue(cfg.cfg_Preset))
        // Sync the stored value to whatever is actually shown — including the
        // index-0 fallback when the saved preset is unknown (e.g. an old
        // "blueneko"); otherwise the field-enable checks below would desync.
        onCurrentValueChanged: cfg.cfg_Preset = currentValue
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Image:")
        enabled: presetBox.currentValue === "image"

        QQC2.TextField {
            id: imageField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            placeholderText: i18n("Pick any image to animate…")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: imageDialog.open()
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Custom shader:")
        enabled: presetBox.currentValue === "custom"

        QQC2.TextField {
            id: customField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            placeholderText: i18n("Path to a compiled .frag.qsb…")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: fileDialog.open()
        }
    }

    QQC2.Label {
        visible: presetBox.currentValue === "custom"
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        text: i18n("Compile GLSL with:  ./compile-shaders.sh my.frag\n(needs the std140 'buf' block — see bundled shaders.)")
    }

    QQC2.SpinBox {
        id: speedSpin
        Kirigami.FormData.label: i18n("Speed:")
        property real realValue: 1.0
        from: 0; to: 400; stepSize: 25
        value: Math.round(realValue * 100)
        textFromValue: function(v) { return (v / 100).toFixed(2) + "×" }
        valueFromText: function(t) { return Math.round(parseFloat(t) * 100) }
        onValueModified: realValue = value / 100
    }

    Kirigami.Separator {
        Kirigami.FormData.label: i18n("Living-image effects")
        Kirigami.FormData.isSection: true
        visible: presetBox.currentValue === "image"
    }

    FxSlider {
        id: breatheSlider
        Kirigami.FormData.label: i18n("Breathing zoom:")
    }
    FxSlider {
        id: swaySlider
        Kirigami.FormData.label: i18n("Parallax sway:")
    }
    FxSlider {
        id: aberrationSlider
        Kirigami.FormData.label: i18n("Chromatic aberration:")
    }
    FxSlider {
        id: bokehSlider
        Kirigami.FormData.label: i18n("Bokeh particles:")
    }
    FxSlider {
        id: vignetteSlider
        Kirigami.FormData.label: i18n("Vignette:")
    }

    QQC2.CheckBox {
        id: pauseBox
        Kirigami.FormData.label: i18n("Power saving:")
        text: i18n("Pause while a window is maximized or fullscreen")
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a compiled shader")
        nameFilters: [ i18n("Compiled shaders (*.qsb)"), i18n("All files (*)") ]
        onAccepted: customField.text = selectedFile
    }

    QtDialogs.FileDialog {
        id: imageDialog
        title: i18n("Choose an image")
        nameFilters: [ i18n("Images (*.png *.jpg *.jpeg *.webp)"), i18n("All files (*)") ]
        onAccepted: imageField.text = selectedFile
    }
}
