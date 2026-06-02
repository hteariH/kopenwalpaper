# Contributing to KOpenWallpaper

Thanks for your interest! This is a set of native **KDE Plasma 6 wallpaper
plugins**. Contributions — new wallpaper types, shaders, fixes, docs — are
welcome.

## Development setup

You need KDE Plasma 6 and Qt 6 with:

- `qt6-multimedia` (+ codecs) — Video plugin
- `qt6-webengine` — Web plugin
- `qt6-shadertools` — provides `qsb`, required to build the Shader plugin
- `qt6-declarative` dev tools — provides `qmllint`

Build and install everything for your user:

```bash
./install.sh                 # compiles shaders, installs all plugins
./install.sh shader          # only one plugin
kquitapp6 plasmashell && (plasmashell &)   # reload the running shell
```

Compiled `.qsb` files are build artifacts (git-ignored); `install.sh` and
`compile-shaders.sh` generate them.

## Testing a change

Apply a plugin and tweak its config from the command line (no clicking):

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var ds = desktops();
for (var i = 0; i < ds.length; i++) { var d = ds[i];
  d.wallpaperPlugin = "com.github.kopenwalpaper.shader";
  d.currentConfigGroup = ["Wallpaper", "com.github.kopenwalpaper.shader", "General"];
  d.writeConfig("Preset", "plasma");
  d.reloadConfig(); }'
```

Check for runtime errors (scope to the live PID — stale PIDs carry old logs):

```bash
journalctl --user --since "1 min ago" | grep "plasmashell\[$(pgrep -x plasmashell)\]"
```

Run `qmllint` on QML you touch, and `./compile-shaders.sh` after editing any
shader.

## Project layout

```
plugins/<type>/
  metadata.json                 # Plasma/Wallpaper manifest (KPlugin.Id, MIT)
  contents/config/main.xml      # config keys (KConfigXT)
  contents/ui/main.qml          # WallpaperItem renderer
  contents/ui/config.qml        # settings page (Kirigami.FormLayout)
```

## Adding a new wallpaper type

1. Copy an existing `plugins/<type>/` as a template.
2. Give it a unique `KPlugin.Id` (`com.github.kopenwalpaper.<type>`).
3. `main.qml` root **must** be a `WallpaperItem` (`org.kde.plasma.plasmoid`);
   read config as `configuration.<Key>`.
4. `config.qml` **must** declare `property var configDialog` and
   `property var wallpaperConfiguration`, plus one `cfg_<Key>` per config key.
5. `./install.sh <type>` picks it up automatically (it installs every
   `plugins/*/` with a `metadata.json`).

## Conventions that bite if ignored

- **Config path keys: use `type="String"`, never `type="Url"`.** The wallpaper
  KCM marshals config over D-Bus as `a{sv}`; `QUrl` is not a registered D-Bus
  type and System Settings **aborts (SIGABRT)** on apply. QML coerces a string
  to `url` where needed.
- **Shaders:** Qt 6 `ShaderEffect.fragmentShader` takes a URL to a precompiled
  `.qsb`, never raw GLSL. Build with `./compile-shaders.sh`.
- **Canonical UBO:** every shader (fragment *and* the bundled `passthrough.vert`)
  must declare a **byte-identical** `std140 binding = 0` block:
  `qt_Matrix, qt_Opacity, iTime, iResolution, imageAspect, breatheAmount,
  swayAmount, aberration, bokehAmount, vignetteAmount`. GL links binding-0
  across stages — any mismatch fails linking. Unused fields are kept on purpose.
- **Performance:** don't drive animation with a refresh-locked `FrameAnimation`.
  Use a ~30 fps `Timer` and pause when the wallpaper isn't visible — full-screen
  shaders at 120/165 Hz pin the GPU (bad on laptops / hybrid GPUs).

## Code style

Match the surrounding code. QML: 4-space indent, `id` first, group properties
logically, comment the non-obvious (especially Plasma/Qt quirks). Keep config
keys and `cfg_<Key>` names in sync with `main.xml`.

## Commits & PRs

- Small, focused commits with clear messages.
- State how you tested (which plugin, applied + checked journal/screenshot).
- By contributing you agree your work is licensed under the project's
  [MIT license](LICENSE).

## Publishing to the KDE Store

Plasma 6 wallpaper plugins are distributed as **“Plasma Wallpaper Plugins”** on
[store.kde.org](https://store.kde.org) (installable via *Get New Wallpaper
Plugins* / KNewStuff). There is **no `.desktop` file** — `metadata.json` is the
manifest. To publish:

1. Package a plugin folder (the contents of `plugins/<type>/`) as a `.tar.gz`.
2. Create a listing under the *Plasma Wallpaper Plugins* category.
3. Upload `screenshots/preview.png` (and the individual shots) as the listing
   images.
