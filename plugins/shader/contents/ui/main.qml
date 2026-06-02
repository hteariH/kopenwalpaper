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
    // Rendered values — these drive the shader. Produced by playing back the
    // buffered audio frames at render rate (see the playback block in `clock`).
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
        var z = Qt.vector4d(0, 0, 0, 0)
        spec0 = z; spec1 = z; spec2 = z; spec3 = z
        afBuf = []; afBase = 0; afLast = -1; afHead = 0; afRate = 80
        afPrevLast = -1; afPrevMs = 0
    }
    onAudioOnChanged: audioOn ? startAudio() : stopAudio()

    // 16-band spectrum delivered as uniforms (4 vec4s) — a dynamic QML texture
    // stuttered, uniforms don't. Set each frame by the playback block.
    property vector4d spec0: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec1: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec2: Qt.vector4d(0, 0, 0, 0)
    property vector4d spec3: Qt.vector4d(0, 0, 0, 0)

    // --- audio frame playback buffer ---
    // The helper writes a rolling window of ~86 fps frames; we receive a batch
    // ~1x/s and play it back smoothly. Each frame is a 20-number array
    // [bass, mid, treble, level, b0..b15] keyed by an absolute monotonic index.
    property var afBuf: []        // frames, afBuf[0] is absolute index afBase
    property double afBase: 0     // absolute index of afBuf[0]
    property double afLast: -1    // newest absolute index received
    property double afHead: 0     // float playhead (absolute index space)
    property double afRate: 80    // EMA of the producer's frame rate (fps)
    property double afPrevLast: -1
    property double afPrevMs: 0
    // Target latency: a bit over one delivery-worth of frames, so playback
    // never underruns between the ~1 Hz batches. ~1.2 s at 86 fps.
    readonly property int afBufferFrames: 105

    // Reads the helper's rolling window of frames. QML XMLHttpRequest can't read
    // local files (blocked unless QML_XHR_ALLOW_FILE_READ=1), so use the
    // executable engine to `cat` it. NOTE: this engine delivers only ~1 result/s
    // regardless of `interval` and can't stream — measured empirically. So each
    // poll fetches a whole window of recent frames; we append the ones we
    // haven't seen (by index) to afBuf and play them back at render rate.
    P5Support.DataSource {
        id: audioReader
        engine: "executable"
        interval: 200
        connectedSources: (root.audioOn && root.visible && !root.paused)
                          ? ["cat " + root.audioFile] : []
        onNewData: (source, data) => {
            // Parse the window into frames (file is contiguous, oldest first).
            const lines = (data["stdout"] || "").split("\n")
            var frames = []
            for (var li = 0; li < lines.length; li++) {
                const p = lines[li].trim().split(/\s+/).map(parseFloat)
                if (p.length >= 21 && !isNaN(p[0])) frames.push(p)  // [idx, vals…]
            }
            if (frames.length === 0 || frames[frames.length - 1][0] <= root.afLast)
                return

            // If the window continues the buffer, append; otherwise (empty, or a
            // gap after a pause/stall) start fresh — afBase assumes a contiguous
            // afBuf, so a discontiguous append would corrupt sampling.
            var contiguous = root.afBuf.length > 0 && frames[0][0] <= root.afLast + 1
            if (!contiguous) {
                root.afBuf = []
                root.afBase = frames[0][0]
                root.afLast = frames[0][0] - 1
            }
            for (var fi = 0; fi < frames.length; fi++) {
                if (frames[fi][0] <= root.afLast) continue   // overlap, already have
                root.afBuf.push(frames[fi].slice(1))         // drop the index column
                root.afLast = frames[fi][0]
            }

            var now = Date.now()
            if (contiguous && root.afPrevLast >= 0 && root.afPrevMs > 0) {
                // Track the producer's frame rate (drives playback speed).
                var dIdx = root.afLast - root.afPrevLast
                var dSec = (now - root.afPrevMs) / 1000.0
                if (dIdx > 0 && dSec > 0.05)
                    root.afRate = root.afRate * 0.6 + (dIdx / dSec) * 0.4
            } else {
                // Fresh start: place the playhead one buffer-length behind.
                root.afHead = root.afLast - root.afBufferFrames
            }
            root.afPrevLast = root.afLast
            root.afPrevMs = now
        }
    }

    // Linear-interpolated frame at an absolute (fractional) index, clamped to
    // the buffer. Returns a 20-number array or null if empty.
    function afSample(absIdx) {
        var n = afBuf.length
        if (n === 0) return null
        var rel = absIdx - afBase
        if (rel <= 0) return afBuf[0]
        if (rel >= n - 1) return afBuf[n - 1]
        var i = Math.floor(rel)
        var f = rel - i
        var a = afBuf[i], b = afBuf[i + 1], out = []
        for (var k = 0; k < a.length; k++) out.push(a[k] + (b[k] - a[k]) * f)
        return out
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

            if (root.audioOn && dt > 0 && root.afBuf.length > 0) {
                // Advance the playhead at the producer's rate (so we replay the
                // real ~86 fps frames in order), plus a gentle pull toward the
                // target latency behind the newest frame — a tracking loop that
                // keeps ~afBufferFrames of buffer without ever freezing.
                var desired = root.afLast - root.afBufferFrames
                root.afHead += dt * root.afRate
                root.afHead += (desired - root.afHead) * (1.0 - Math.exp(-dt / 1.5))
                if (root.afHead > root.afLast) root.afHead = root.afLast
                if (root.afHead < root.afBase) root.afHead = root.afBase

                var fr = root.afSample(root.afHead)
                if (fr) {
                    root.audioBass = fr[0]; root.audioMid = fr[1]
                    root.audioTreble = fr[2]; root.audioLevel = fr[3]
                    root.spec0 = Qt.vector4d(fr[4], fr[5], fr[6], fr[7])
                    root.spec1 = Qt.vector4d(fr[8], fr[9], fr[10], fr[11])
                    root.spec2 = Qt.vector4d(fr[12], fr[13], fr[14], fr[15])
                    root.spec3 = Qt.vector4d(fr[16], fr[17], fr[18], fr[19])
                }

                // Drop frames the playhead has passed (keep a few for interp).
                var drop = Math.floor(root.afHead - root.afBase) - 2
                if (drop > 0) {
                    root.afBuf.splice(0, drop)
                    root.afBase += drop
                }
            }
        }
        onRunningChanged: if (!running) lastMs = 0
    }
}
