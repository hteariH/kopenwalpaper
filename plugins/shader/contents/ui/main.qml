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
    Component.onCompleted: compileCustom()

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
