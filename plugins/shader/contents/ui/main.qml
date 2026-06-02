/*
 * KOpenWallpaper (Shader) — procedural GLSL wallpaper for KDE Plasma 6.
 *
 * Renders a fragment shader via ShaderEffect. Qt6 requires precompiled .qsb
 * files (built from contents/shaders/*.frag by install.sh / compile-shaders.sh).
 * iTime is advanced by a FrameAnimation; iResolution tracks the item size.
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

WallpaperItem {
    id: root

    readonly property string preset: root.configuration.Preset
    // String path/URL (not kcfg "Url": QUrl crashes the KCM's D-Bus marshalling).
    readonly property string customUrl: root.configuration.CustomShaderUrl
    readonly property string imageUrl: root.configuration.ImageUrl
    readonly property real speed: root.configuration.Speed

    // file:// of the .qsb produced from a custom .frag (see compileCustom()).
    property string compiledFrag: ""

    // --- audio reactivity (see contents/tools/kopen-audio.py) ---
    readonly property bool audioReactive: root.configuration.AudioReactive
    // The "audio" visualizer needs the feed, so it implies reactivity.
    readonly property bool audioOn: audioReactive || preset === "audio"
    readonly property string audioFile: "/tmp/kopenwalpaper-audio"
    property real audioLevel: 0
    property real audioBass: 0
    property real audioMid: 0
    property real audioTreble: 0

    function helperPath() {
        return Qt.resolvedUrl("../tools/kopen-audio.py").toString().replace(/^file:\/\//, "")
    }
    // Kill the previous instance via its PID file (NOT pkill -f: that pattern
    // also matches this launcher shell, whose args contain the script path).
    readonly property string audioKillPrev:
        "P=\"" + audioFile + ".pid\"; [ -f \"$P\" ] && kill \"$(cat \"$P\")\" 2>/dev/null; "
    function startAudio() {
        audioCtl.connectSource("sh -c '" + audioKillPrev
            + "setsid python3 \"" + helperPath() + "\" --out " + audioFile
            + " >/dev/null 2>&1 &'")
    }
    function stopAudio() {
        audioCtl.connectSource("sh -c '" + audioKillPrev + "true'")
        audioLevel = 0; audioBass = 0; audioMid = 0; audioTreble = 0
    }
    onAudioOnChanged: audioOn ? startAudio() : stopAudio()

    // Reads the helper's band file ~25x/s. QML XMLHttpRequest can't read local
    // files (blocked unless QML_XHR_ALLOW_FILE_READ=1), so use the executable
    // engine's interval polling to `cat` it instead.
    P5Support.DataSource {
        id: audioReader
        engine: "executable"
        interval: 40
        connectedSources: (root.audioOn && root.visible && !root.paused)
                          ? ["cat " + root.audioFile] : []
        onNewData: (source, data) => {
            const parts = (data["stdout"] || "").trim().split(/\s+/)
            if (parts.length >= 4) {
                root.audioBass = parseFloat(parts[0]) || 0
                root.audioMid = parseFloat(parts[1]) || 0
                root.audioTreble = parseFloat(parts[2]) || 0
                root.audioLevel = parseFloat(parts[3]) || 0
            }
        }
    }

    // Fire-and-forget control channel for the audio helper (separate from the
    // shader-compile runner so their outputs don't get mixed up).
    P5Support.DataSource {
        id: audioCtl
        engine: "executable"
        connectedSources: []
        onNewData: (source) => audioCtl.disconnectSource(source)
    }
    Component.onDestruction: stopAudio()

    function shaderUrl() {
        if (preset === "custom" && customUrl.length > 0) {
            // A precompiled .qsb is used directly; a .frag is compiled on the
            // fly (compiledFrag) — fall back to plasma until that's ready.
            if (/\.qsb$/i.test(customUrl)) {
                return customUrl
            }
            return compiledFrag.length > 0 ? compiledFrag
                                           : Qt.resolvedUrl("../shaders/plasma.frag.qsb")
        }
        return Qt.resolvedUrl("../shaders/" + preset + ".frag.qsb")
    }

    // Runs `qsb` on a user-supplied .frag and caches the result under
    // ~/.cache/kopenwalpaper, so custom shaders don't need a manual build step.
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            runner.disconnectSource(source)
            const out = (data["stdout"] || "").trim()
            if (data["exit code"] === 0 && out.length > 0) {
                root.compiledFrag = "file://" + out
            } else {
                console.warn("KOpenWallpaper(Shader): qsb failed\n", data["stderr"])
            }
        }
    }

    function compileCustom() {
        compiledFrag = ""
        if (preset !== "custom" || customUrl.length === 0 || /\.qsb$/i.test(customUrl)) {
            return
        }
        const inPath = customUrl.replace(/^file:\/\//, "")
        const outName = inPath.split("/").pop() + ".qsb"
        const cacheRel = "$HOME/.cache/kopenwalpaper/" + outName
        // mkdir cache, locate qsb, compile to the cache, echo the path on success.
        // Body is single-quoted for sh -c; inner " are literal so $HOME expands.
        // Target set MUST match compile-shaders.sh / passthrough.vert.qsb, or
        // the GL backend can't find a GLSL version present in both stages and
        // linking fails (qt_TexCoord0 "no matching output").
        const cmd = "sh -c 'mkdir -p \"$HOME/.cache/kopenwalpaper\"; "
            + "QSB=$(command -v qsb6 || command -v qsb || echo /usr/lib/qt6/bin/qsb); "
            + "\"$QSB\" --glsl \"100es,120,150,300es,330,440\" --hlsl 50 --msl 12 -O "
            + "-o \"" + cacheRel + "\" \"" + inPath + "\" 1>&2 "
            + "&& printf %s \"" + cacheRel + "\"'"
        runner.connectSource(cmd)
    }

    onCustomUrlChanged: compileCustom()
    onPresetChanged: compileCustom()
    Component.onCompleted: {
        compileCustom()
        if (audioOn) {
            startAudio()
        }
    }

    // Texture for image-based shaders (sampler `source`). The "image" preset
    // animates whatever picture the user supplies; procedural presets ignore it.
    function textureUrl() {
        return imageUrl
    }

    // Stops the clock while a window is maximized/fullscreen (battery saving).
    OcclusionWatcher { id: occ }
    readonly property bool paused: root.configuration.PauseWhenObscured && occ.obscured

    // Backdrop while a shader (re)loads or if it fails.
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Hidden texture provider for image-based shaders (sampler2D `source`).
    Image {
        id: tex
        visible: false
        cache: false
        asynchronous: true
        source: root.textureUrl()
        sourceSize.width: 2560   // decode at a sane size regardless of original
        fillMode: Image.PreserveAspectCrop
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        blending: false

        // Mapped by name into the shader's std140 uniform block.
        property real iTime: 0.0
        property vector2d iResolution: Qt.vector2d(width, height)
        // Real source-image aspect, so image shaders cover-fit any picture.
        property real imageAspect: tex.implicitHeight > 0
                                   ? tex.implicitWidth / tex.implicitHeight : 1.0
        // Living-image effect strengths (1.0 = default look, 0 = off).
        property real breatheAmount: root.configuration.BreatheAmount
        property real swayAmount: root.configuration.SwayAmount
        property real aberration: root.configuration.Aberration
        property real bokehAmount: root.configuration.BokehAmount
        property real vignetteAmount: root.configuration.Vignette
        // Audio-reactive band levels (fed by audioReader).
        property real audioLevel: root.audioLevel
        property real audioBass: root.audioBass
        property real audioMid: root.audioMid
        property real audioTreble: root.audioTreble
        // Bound to the `source` sampler in image-based shaders.
        property variant source: tex

        // Explicit pass-through VS so stage I/O locations match under the GL
        // RHI backend (the built-in default VS does not export qt_TexCoord0
        // with an explicit location).
        vertexShader: Qt.resolvedUrl("../shaders/passthrough.vert.qsb")
        fragmentShader: root.shaderUrl()

        onStatusChanged: {
            if (status === ShaderEffect.Error) {
                console.warn("KOpenWallpaper(Shader): compile/load error\n", log)
            }
        }
    }

    // Ambient clock, capped to ~30 fps. Driving a full-screen fragment shader
    // at the native refresh (e.g. 165 Hz) pins the GPU continuously — needless
    // on a laptop. iTime advances by real elapsed time, so motion speed is
    // independent of the tick rate. Paused while the wallpaper isn't visible.
    Timer {
        id: clock
        property double lastMs: 0
        interval: 33   // ~30 fps
        repeat: true
        running: root.visible && !root.paused
        onTriggered: {
            var now = Date.now()
            if (lastMs > 0) {
                fx.iTime += (now - lastMs) / 1000.0 * root.speed
            }
            lastMs = now
        }
        onRunningChanged: if (!running) lastMs = 0
    }
}
