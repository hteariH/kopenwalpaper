/*
 * KOpenWallpaper (GIF) — configuration page.
 * Persisted key Foo <-> property cfg_Foo.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: cfg

    // Injected by the wallpaper config host.
    property var configDialog
    property var wallpaperConfiguration

    property alias cfg_ImageUrl: pathField.text
    property int cfg_FillMode
    property string cfg_BackgroundColor
    property alias cfg_Speed: speedSpin.realValue

    RowLayout {
        Kirigami.FormData.label: i18n("Animated image:")

        QQC2.TextField {
            id: pathField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            placeholderText: i18n("Path to a gif / apng / animated webp…")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: fileDialog.open()
        }
    }

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

    QQC2.SpinBox {
        id: speedSpin
        Kirigami.FormData.label: i18n("Animation speed:")
        property real realValue: 1.0
        from: 25; to: 400; stepSize: 25
        value: Math.round(realValue * 100)
        textFromValue: function(v) { return (v / 100).toFixed(2) + "×" }
        valueFromText: function(t) { return Math.round(parseFloat(t) * 100) }
        onValueModified: realValue = value / 100
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose an animated image")
        nameFilters: [
            i18n("Animated images (*.gif *.png *.apng *.webp)"),
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
