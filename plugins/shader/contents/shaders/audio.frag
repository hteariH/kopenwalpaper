#version 440
// Audio visualizer: a living, glowing "energy blob". Its radius swells with
// bass, spikes into a spiky star with treble, its colour flows with the mids,
// and a bloom pulses from the centre on bass hits. It keeps breathing gently
// when silent. Band levels (0..1) come from the canonical UBO (kopen-audio).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    float imageAspect;
    float breatheAmount;
    float swayAmount;
    float aberration;
    float bokehAmount;
    float vignetteAmount;
    float audioLevel;
    float audioBass;
    float audioMid;
    float audioTreble;
    vec4 spec0;   // 16-band spectrum (4 bands per vec4)
    vec4 spec1;
    vec4 spec2;
    vec4 spec3;
};

vec3 pal(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x);

    float bass = audioBass, mid = audioMid, treb = audioTreble, lvl = audioLevel;

    // Reactive contour: idle breathing (stays alive when quiet) + bass swell
    // + sharp treble spikes + slower mid lobes.
    float R = 0.26
            + 0.020 * sin(iTime * 1.3 + a * 3.0)
            + bass * 0.20
            + treb * 0.10 * sin(a * 16.0 + iTime * 7.0)
            + mid  * 0.07 * sin(a * 7.0 - iTime * 3.0);

    float d = r - R;  // <0 inside the blob

    float hueShift = iTime * 0.05 + mid * 0.5 + a / 6.28318;
    vec3 hue = pal(hueShift);

    vec3 col = vec3(0.0);

    // Glowing filled interior, brighter toward the centre, lifted by loudness.
    float inside = smoothstep(0.012, -0.04, d);
    col += hue * inside * (0.35 + 0.65 * (1.0 - r / max(R, 0.001))) * (0.5 + 0.8 * lvl);

    // Bright rim, flares with treble.
    col += hue * smoothstep(0.03, 0.0, abs(d)) * (0.8 + 1.4 * treb);

    // Central bass bloom.
    col += pal(0.05 + iTime * 0.05) * bass * 0.9 * exp(-r * 4.0);

    // Treble sparkle just outside the contour.
    float sp = pow(0.5 + 0.5 * sin(a * 30.0 + iTime * 4.0), 12.0) * treb;
    col += sp * smoothstep(0.10, 0.0, abs(d - 0.02)) * vec3(0.8, 0.9, 1.0);

    // Faint background wash + vignette.
    col += pal(hueShift + 0.5) * 0.03 * (1.0 - r);
    col *= smoothstep(1.2, 0.2, r);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
