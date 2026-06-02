/*
 * KOpenWallpaper — video wallpaper renderer for KDE Plasma 6
 *
 * Root must be a WallpaperItem (Plasma 6 API). Persisted keys from
 * contents/config/main.xml are read as configuration.<Key>.
 */
import QtQuick
import QtMultimedia
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // VideoOutput.fillMode shares our stored int values:
    //   0 = Stretch, 1 = PreserveAspectFit, 2 = PreserveAspectCrop
    readonly property int cfgFillMode: root.configuration.FillMode
    // Stored as a String (file:// URL or path); QML coerces it to MediaPlayer's
    // url source. NB: config must NOT be a kcfg "Url" type — QUrl cannot be
    // marshalled over the wallpaper KCM's D-Bus call and crashes System Settings.
    readonly property string cfgVideoUrl: root.configuration.VideoUrl

    // Pauses playback while a window is maximized/fullscreen (battery saving).
    OcclusionWatcher { id: occ }
    readonly property bool paused: root.configuration.PauseWhenObscured && occ.obscured
    onPausedChanged: {
        if (paused) {
            player.pause()
        } else if (root.cfgVideoUrl !== "") {
            player.play()
        }
    }

    // Solid backdrop, visible in "fit" mode (letterboxing) or before the
    // first frame is decoded.
    Rectangle {
        anchors.fill: parent
        color: root.configuration.BackgroundColor
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: root.cfgFillMode
    }

    MediaPlayer {
        id: player
        source: root.cfgVideoUrl
        videoOutput: videoOutput
        loops: MediaPlayer.Infinite
        playbackRate: root.configuration.PlaybackRate

        audioOutput: AudioOutput {
            muted: root.configuration.Muted
            volume: root.configuration.Volume / 100.0
        }

        onErrorOccurred: function(error, errorString) {
            console.warn("KOpenWallpaper: media error", error, errorString)
        }

        onSourceChanged: restartTimer.restart()
    }

    // Debounce rapid config changes (e.g. while typing a path) before
    // (re)starting playback.
    Timer {
        id: restartTimer
        interval: 150
        onTriggered: {
            player.stop()
            if (root.cfgVideoUrl !== "" && !root.paused) {
                player.play()
            }
        }
    }

    Component.onCompleted: {
        if (root.cfgVideoUrl !== "" && !root.paused) {
            player.play()
        }
    }
}
