/*
 * KOpenWallpaper (Web) — HTML / WebGL wallpaper for KDE Plasma 6.
 *
 * Renders a web page via QtWebEngine. NOTE: QtWebEngine must be initialized
 * before the host QGuiApplication starts; plasmashell does not do this, so the
 * view may refuse to load (see README "Web wallpaper" caveat). The plugin is
 * written defensively and logs render-process failures rather than crashing.
 */
import QtQuick
import QtWebEngine
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // String URL/path (not kcfg "Url": QUrl crashes the KCM's D-Bus marshalling).
    readonly property string pageUrl: root.configuration.PageUrl

    function effectiveUrl() {
        return pageUrl.length > 0 ? pageUrl
                                  : Qt.resolvedUrl("../web/demo.html")
    }

    // Freezes the page (stops its timers / rAF) while a window is
    // maximized/fullscreen — saves CPU/GPU when the desktop can't be seen.
    OcclusionWatcher { id: occ }
    readonly property bool paused: root.configuration.PauseWhenObscured && occ.obscured

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    WebEngineView {
        id: view
        anchors.fill: parent
        url: root.effectiveUrl()
        // Desktop background: no interaction, no scrollbars, opaque base.
        backgroundColor: "black"
        settings.showScrollBars: false
        settings.localContentCanAccessFileUrls: true
        settings.localContentCanAccessRemoteUrls: true
        settings.playbackRequiresUserGesture: false
        audioMuted: root.configuration.MutePage
        // Active normally; Frozen suspends the page when obscured.
        lifecycleState: root.paused ? WebEngineView.LifecycleState.Frozen
                                    : WebEngineView.LifecycleState.Active

        onRenderProcessTerminated: function(status, code) {
            console.warn("KOpenWallpaper(Web): render process gone", status, code)
            reloadTimer.restart()
        }
    }

    // Recover from an occasional renderer crash.
    Timer {
        id: reloadTimer
        interval: 2000
        onTriggered: view.reload()
    }
}
