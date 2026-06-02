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
    // The audio/spectrum visualizers need the feed, so they imply reactivity.
    readonly property bool audioOn: audioReactive
        || ["audio", "spectrum", "spectrumring"].indexOf(preset) >= 0
    readonly property string audioFile: "/tmp/kopenwalpaper-audio"
    // Rendered (smoothed) values — these drive the shader.
    property real audioLevel: 0
    property real audioBass: 0
    property real audioMid: 0
    property real audioTreble: 0
    // Targets set by the reader; the clock interpolates the rendered values
    // toward these every frame. The executable DataSource only delivers data
    // ~1-2x/s, so without this the bars would step instead of glide.
    property real tgtLevel: 0
    property real tgtBass: 0
    property real tgtMid: 0
    property real tgtTreble: 0

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
        tgtLevel = 0; tgtBass = 0; tgtMid = 0; tgtTreble = 0
        var z = Qt.vector4d(0, 0, 0, 0)
        spec0 = z; spec1 = z; spec2 = z; spec3 = z
        tgtSpec0 = z; tgtSpec1 = z; tgtSpec2 = z; tgtSpec3 = z
    }
    onAudioOnChanged: audioOn ? startAudio() : stopAudio()

    // 16-band spectrum delivered as uniforms (4 vec4s), exactly like the smooth
    // scalar path — a dynamic QML texture stuttered, uniforms don't. spec* are
    // the rendered (smoothed) bands; tgtSpec* are the latest reader targets.
    property vector4d spec0: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec1: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec2: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec3: Qt.vector4d(0, 0, 0, 0)
    property vector4d tgtSpec0: Qt.vector4d(0, 0, 0, 0)
    property vector4d tgtSpec1: Qt.vector4d(0, 0, 0, 0)
    property vector4d tgtSpec2: Qt.vector4d(0, 0, 0, 0)
    property vector4d tgtSpec3: Qt.vector4d(0, 0, 0, 0)

    // Reads the helper's "bass mid treble level + 16 bands" line. QML
    // XMLHttpRequest can't read local files (blocked unless
    // QML_XHR_ALLOW_FILE_READ=1), so use the executable engine to `cat` it.
    // NOTE: this engine only delivers ~1-2 results/s regardless of `interval`
    // (it spawns a process per poll); it sets *targets*, and the clock Timer
    // interpolates the rendered uniforms toward them so visuals stay smooth.
    P5Support.DataSource {
        id: audioReader
        engine: "executable"
        interval: 33
        connectedSources: (root.audioOn && root.visible && !root.paused)
                          ? ["cat " + root.audioFile] : []
        onNewData: (source, data) => {
            const p = (data["stdout"] || "").trim().split(/\s+/).map(parseFloat)
            if (p.length >= 4) {
                root.tgtBass = p[0] || 0
                root.tgtMid = p[1] || 0
                root.tgtTreble = p[2] || 0
                root.tgtLevel = p[3] || 0
            }
            if (p.length >= 20) {
                root.tgtSpec0 = Qt.vector4d(p[4] || 0, p[5] || 0, p[6] || 0, p[7] || 0)
                root.tgtSpec1 = Qt.vector4d(p[8] || 0, p[9] || 0, p[10] || 0, p[11] || 0)
                root.tgtSpec2 = Qt.vector4d(p[12] || 0, p[13] || 0, p[14] || 0, p[15] || 0)
                root.tgtSpec3 = Qt.vector4d(p[16] || 0, p[17] || 0, p[18] || 0, p[19] || 0)
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
        // 16-band spectrum (spec0..spec3) for the spectrum visualizers.
        property vector4d spec0: root.spec0
        property vector4d spec1: root.spec1
        property vector4d spec2: root.spec2
        property vector4d spec3: root.spec3

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

    // Animation clock. ~30 fps for ambient shaders (a full-screen shader at the
    // native 120/165 Hz needlessly pins the GPU on a laptop), but ~60 fps for
    // audio-reactive presets where smoothness is wanted. iTime advances by real
    // elapsed time, so motion speed is independent of the tick rate. Paused
    // while the wallpaper isn't visible.
    Timer {
        id: clock
        property double lastMs: 0
        interval: root.audioOn ? 16 : 33   // ~60 fps with audio, else ~30 fps
        repeat: true
        running: root.visible && !root.paused
        onTriggered: {
            var now = Date.now()
            var dt = lastMs > 0 ? (now - lastMs) / 1000.0 : 0
            if (dt > 0) {
                fx.iTime += dt * root.speed
            }
            lastMs = now

            // Glide the rendered audio uniforms toward the reader's targets.
            // The feed only updates ~1-2x/s; this exponential follow (tau ~70ms)
            // turns those sparse steps into a fluid 60 fps rise/fall.
            if (root.audioOn && dt > 0) {
                var a = 1.0 - Math.exp(-dt / 0.07)
                root.audioBass += (root.tgtBass - root.audioBass) * a
                root.audioMid += (root.tgtMid - root.audioMid) * a
                root.audioTreble += (root.tgtTreble - root.audioTreble) * a
                root.audioLevel += (root.tgtLevel - root.audioLevel) * a
                root.spec0 = root.spec0.times(1.0 - a).plus(root.tgtSpec0.times(a))
                root.spec1 = root.spec1.times(1.0 - a).plus(root.tgtSpec1.times(a))
                root.spec2 = root.spec2.times(1.0 - a).plus(root.tgtSpec2.times(a))
                root.spec3 = root.spec3.times(1.0 - a).plus(root.tgtSpec3.times(a))
            }
        }
        onRunningChanged: if (!running) lastMs = 0
    }
}
