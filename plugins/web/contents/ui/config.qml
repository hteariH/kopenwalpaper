/*
 * KOpenWallpaper (Web) — configuration page.
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

    property alias cfg_PageUrl: urlField.text
    property alias cfg_MutePage: muteBox.checked

    RowLayout {
        Kirigami.FormData.label: i18n("Page URL / file:")

        QQC2.TextField {
            id: urlField
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            placeholderText: i18n("https://… or a local .html file (empty = built-in demo)")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: fileDialog.open()
        }
    }

    QQC2.CheckBox {
        id: muteBox
        Kirigami.FormData.label: i18n("Audio:")
        text: i18n("Mute page")
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        text: i18n("Tip: point this at a local HTML/WebGL scene for animated, " +
                   "interactive wallpapers. Leave empty to use the bundled demo.")
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose an HTML file")
        nameFilters: [ i18n("Web pages (*.html *.htm)"), i18n("All files (*)") ]
        onAccepted: urlField.text = selectedFile
    }
}
