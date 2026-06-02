/*
 * KOpenWallpaper (Shader) — configuration page.
 * The shader is chosen from a gallery of live preview tiles.
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
    property alias cfg_AudioReactive: audioBox.checked
    property alias cfg_CustomShaderUrl: customField.text
    property alias cfg_ImageUrl: imageField.text
    property alias cfg_Speed: speedSpin.realValue
    property alias cfg_BreatheAmount: breatheSlider.value
    property alias cfg_SwayAmount: swaySlider.value
    property alias cfg_Aberration: aberrationSlider.value
    property alias cfg_BokehAmount: bokehSlider.value
    property alias cfg_Vignette: vignetteSlider.value

    readonly property var knownPresets: ["image", "plasma", "waves", "starfield", "audio", "custom"]

    // Shared ~20 fps clock for the preview tiles (only while the page is shown).
    property real previewTime: 0
    Timer {
        interval: 50; repeat: true; running: cfg.visible
        onTriggered: cfg.previewTime += 0.05
    }
    // Texture for the "image" preview tile.
    Image {
        id: previewImg
        visible: false; cache: false; asynchronous: true
        source: cfg.cfg_ImageUrl
        sourceSize.width: 512
    }

    // Normalize a stale/unknown saved preset (e.g. a removed "blueneko").
    Component.onCompleted: if (knownPresets.indexOf(cfg_Preset) === -1) cfg_Preset = "image"

    // --- one live shader preview (canonical UBO, same as main.qml) ---
    component ShaderPreview: ShaderEffect {
        property string fragName
        blending: false
        property real iTime: cfg.previewTime
        property vector2d iResolution: Qt.vector2d(width, height)
        property real imageAspect: previewImg.implicitHeight > 0
                                   ? previewImg.implicitWidth / previewImg.implicitHeight : 1.0
        property real breatheAmount: cfg.cfg_BreatheAmount
        property real swayAmount: cfg.cfg_SwayAmount
        property real aberration: cfg.cfg_Aberration
        property real bokehAmount: cfg.cfg_BokehAmount
        property real vignetteAmount: cfg.cfg_Vignette
        // Synthetic pulse so the audio-visualizer tile looks alive in the gallery.
        property real audioBass: 0.5 + 0.5 * Math.sin(cfg.previewTime * 3.0)
        property real audioMid: 0.5 + 0.5 * Math.sin(cfg.previewTime * 2.3 + 1.0)
        property real audioTreble: 0.5 + 0.5 * Math.sin(cfg.previewTime * 4.1 + 2.0)
        property real audioLevel: 0.5 + 0.4 * Math.sin(cfg.previewTime * 2.0)
        property variant source: previewImg
        vertexShader: Qt.resolvedUrl("../shaders/passthrough.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../shaders/" + fragName + ".frag.qsb")
    }

    // --- one clickable gallery tile ---
    component PresetTile: Rectangle {
        id: tile
        property string presetKey
        property string label
        readonly property bool selected: cfg.cfg_Preset === presetKey
        width: Kirigami.Units.gridUnit * 9
        height: Kirigami.Units.gridUnit * 6
        radius: 4
        color: "black"
        border.width: selected ? 3 : 1
        border.color: selected ? Kirigami.Theme.highlightColor
                               : Kirigami.Theme.disabledTextColor

        // Live shader preview for the built-in/image presets…
        ShaderPreview {
            anchors.fill: parent
            anchors.margins: tile.border.width
            visible: tile.presetKey !== "custom"
                     && (tile.presetKey !== "image" || cfg.cfg_ImageUrl.length > 0)
            fragName: tile.presetKey
        }
        // …or an icon for "custom" / a hint for "image" with no picture yet.
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.medium; height: width
            visible: tile.presetKey === "custom"
                     || (tile.presetKey === "image" && cfg.cfg_ImageUrl.length === 0)
            source: tile.presetKey === "custom" ? "code-context" : "viewimage"
        }

        QQC2.Label {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 2
            text: tile.label
            font: Kirigami.Theme.smallFont
            color: "white"
            style: Text.Outline; styleColor: "black"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: cfg.cfg_Preset = tile.presetKey
        }
    }

    Flow {
        Kirigami.FormData.label: i18n("Shader:")
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
        spacing: Kirigami.Units.smallSpacing

        PresetTile { presetKey: "image";     label: i18n("Living image") }
        PresetTile { presetKey: "plasma";    label: i18n("Plasma") }
        PresetTile { presetKey: "waves";     label: i18n("Waves") }
        PresetTile { presetKey: "starfield"; label: i18n("Starfield") }
        PresetTile { presetKey: "audio";     label: i18n("Audio") }
        PresetTile { presetKey: "custom";    label: i18n("Custom") }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Image:")
        enabled: cfg.cfg_Preset === "image"

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
        enabled: cfg.cfg_Preset === "custom"

        QQC2.TextField {
            id: customField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            placeholderText: i18n("Pick a .frag (auto-compiled) or a .qsb…")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: fileDialog.open()
        }
    }

    QQC2.Label {
        visible: cfg.cfg_Preset === "custom"
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        text: i18n("A .frag is compiled with qsb automatically (cached in ~/.cache/kopenwalpaper). It must declare the same std140 'buf' block as the bundled shaders.")
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
        visible: cfg.cfg_Preset === "image"
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
        id: audioBox
        Kirigami.FormData.label: i18n("Audio:")
        text: i18n("React to system audio output")
    }

    QQC2.Label {
        visible: audioBox.checked || cfg.cfg_Preset === "audio"
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        text: i18n("Captures the default audio output's monitor via a small Python helper (needs PipeWire/PulseAudio + numpy). The Audio preset visualizes it.")
    }

    QQC2.CheckBox {
        id: pauseBox
        Kirigami.FormData.label: i18n("Power saving:")
        text: i18n("Pause while a window is maximized or fullscreen")
    }

    // Reusable 0–200 % effect slider row, used for the Living-image controls.
    component FxSlider: RowLayout {
        property alias value: slider.value
        enabled: cfg.cfg_Preset === "image"
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

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a shader")
        nameFilters: [ i18n("Shaders (*.frag *.qsb)"), i18n("GLSL source (*.frag)"), i18n("Compiled (*.qsb)"), i18n("All files (*)") ]
        onAccepted: customField.text = selectedFile
    }

    QtDialogs.FileDialog {
        id: imageDialog
        title: i18n("Choose an image")
        nameFilters: [ i18n("Images (*.png *.jpg *.jpeg *.webp)"), i18n("All files (*)") ]
        onAccepted: imageField.text = selectedFile
    }
}
