/*
 * KOpenWallpaper (GIF) — animated-image wallpaper for KDE Plasma 6.
 *
 * Uses AnimatedImage, which decodes GIF / APNG / animated WebP. Config keys
 * (contents/config/main.xml) are read as configuration.<Key>.
 */
import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // AnimatedImage inherits Image.fillMode, sharing our int values:
    //   0 = Stretch, 1 = PreserveAspectFit, 2 = PreserveAspectCrop
    readonly property int cfgFillMode: root.configuration.FillMode
    // String (file:// URL or path), coerced to AnimatedImage's url source.
    // Must not be a kcfg "Url" type (QUrl can't be D-Bus marshalled by the KCM).
    readonly property string cfgImageUrl: root.configuration.ImageUrl

    Rectangle {
        anchors.fill: parent
        color: root.configuration.BackgroundColor
    }

    AnimatedImage {
        id: image
        anchors.fill: parent
        source: root.cfgImageUrl
        fillMode: root.cfgFillMode
        speed: root.configuration.Speed
        playing: true
        cache: false
        asynchronous: true
        // Smooth scaling when the image is up/down-scaled to screen size.
        smooth: true
        mipmap: true

        onStatusChanged: {
            if (status === AnimatedImage.Error) {
                console.warn("KOpenWallpaper(GIF): failed to load", root.cfgImageUrl)
            }
        }
    }
}
