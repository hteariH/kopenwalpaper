/*
 * OcclusionWatcher — exposes `obscured = true` when a non-minimized window is
 * maximized or fullscreen on THIS wallpaper's screen + virtual desktop +
 * activity. Animated wallpapers bind their playback to `!obscured` to stop
 * burning GPU/CPU while the desktop can't be seen (Wallpaper-Engine style).
 *
 * Shared verbatim across all KOpenWallpaper plugins (kept in each package
 * because Plasma wallpaper packages can't share QML files).
 */
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: watcher

    property bool obscured: false

    TaskManager.VirtualDesktopInfo { id: vdi }
    TaskManager.ActivityInfo { id: ai }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        // Only windows on the same screen/desktop/activity as this wallpaper.
        screenGeometry: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
        activity: ai.currentActivity
        virtualDesktop: vdi.currentDesktop
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true

        onDataChanged: Qt.callLater(watcher.reevaluate)
        onCountChanged: Qt.callLater(watcher.reevaluate)
        onActiveTaskChanged: Qt.callLater(watcher.reevaluate)
    }

    function reevaluate() {
        for (let i = 0; i < tasksModel.count; i++) {
            const idx = tasksModel.makeModelIndex(i);
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized)) {
                continue;
            }
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMaximized)
                    || tasksModel.data(idx, TaskManager.AbstractTasksModel.IsFullScreen)) {
                watcher.obscured = true;
                return;
            }
        }
        watcher.obscured = false;
    }

    Component.onCompleted: reevaluate()
}
