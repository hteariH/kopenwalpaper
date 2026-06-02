#!/usr/bin/env python3
"""
kopen-audio — capture the system audio output (the default sink's monitor) and
write smoothed, auto-gained frequency-band levels to a small file that the
KOpenWallpaper shader reads. Pure stdlib + numpy; capture via parec/pw-record.

Output file content (overwritten ~40x/s): four floats 0..1, space-separated:
    bass mid treble level
"""
import argparse
import os
import signal
import subprocess
import sys

import numpy as np

RATE = 44100
N = 1024  # samples per analysis frame (~23 ms)


def default_monitor():
    try:
        sink = subprocess.check_output(["pactl", "get-default-sink"], text=True).strip()
        if sink:
            return sink + ".monitor"
    except Exception:
        pass
    try:
        out = subprocess.check_output(["pactl", "list", "short", "sources"], text=True)
        for line in out.splitlines():
            if "monitor" in line:
                return line.split("\t")[1]
    except Exception:
        pass
    return None


def open_capture(device):
    """Start a raw s16le mono capture process, return it (parec preferred)."""
    if _have("parec"):
        cmd = ["parec", "--raw", "--format=s16le", f"--rate={RATE}", "--channels=1"]
        if device:
            cmd += ["-d", device]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE)
    if _have("pw-record"):
        cmd = ["pw-record", "--rate", str(RATE), "--channels", "1", "--format", "s16"]
        if device:
            cmd += ["--target", device]
        cmd += ["-"]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE)
    sys.stderr.write("kopen-audio: no parec/pw-record available\n")
    sys.exit(1)


def _have(prog):
    from shutil import which
    return which(prog) is not None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="file to write band levels to")
    ap.add_argument("--device", default="", help="capture source (default: sink monitor)")
    args = ap.parse_args()

    device = args.device or default_monitor() or ""
    proc = open_capture(device)

    # PID file lets the wallpaper stop exactly this instance (pkill -f would
    # also match the launching shell, whose args contain this script's path).
    pidfile = args.out + ".pid"
    try:
        with open(pidfile, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

    def cleanup(*_):
        try:
            proc.terminate()
        except Exception:
            pass
        for path in (args.out, pidfile):
            try:
                os.remove(path)
            except Exception:
                pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    win = np.hanning(N).astype(np.float32)
    freqs = np.fft.rfftfreq(N, 1.0 / RATE)

    def band(mag, lo, hi):
        m = (freqs >= lo) & (freqs < hi)
        return float(mag[m].mean()) if m.any() else 0.0

    smooth = np.zeros(4, dtype=np.float32)
    peak = np.full(4, 1e-4, dtype=np.float32)  # per-band running peak (auto-gain)
    nbytes = N * 2

    while True:
        buf = proc.stdout.read(nbytes)
        if not buf or len(buf) < nbytes:
            if proc.poll() is not None:
                break
            continue
        x = np.frombuffer(buf, dtype=np.int16).astype(np.float32) / 32768.0
        rms = float(np.sqrt(np.mean(x * x)))
        mag = np.abs(np.fft.rfft(x * win))
        raw = np.array([
            band(mag, 20, 250),     # bass
            band(mag, 250, 2000),   # mid
            band(mag, 2000, 12000),  # treble
            rms,                     # overall level
        ], dtype=np.float32)

        # Per-band auto-gain: peak rises instantly, decays slowly.
        peak = np.maximum(peak * 0.9995, raw)
        norm = np.clip(raw / (peak + 1e-6), 0.0, 1.0)
        # Exponential smoothing for less jittery visuals.
        smooth = smooth * 0.6 + norm * 0.4

        line = "%.4f %.4f %.4f %.4f" % tuple(smooth)
        try:
            tmp = args.out + ".tmp"
            with open(tmp, "w") as f:
                f.write(line)
            os.replace(tmp, args.out)
        except Exception:
            pass

    cleanup()


if __name__ == "__main__":
    main()
