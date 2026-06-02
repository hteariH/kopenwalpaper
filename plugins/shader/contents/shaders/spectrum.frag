#version 440
// Classic frequency-bar spectrum. Reads 16 band levels from the canonical UBO
// (spec0..spec3, fed by the kopen-audio helper) — passed as uniforms, not a
// texture, because a dynamic QML texture stuttered while uniforms are smooth.
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
    vec4 spec0;
    vec4 spec1;
    vec4 spec2;
    vec4 spec3;
};

const float NBARS = 16.0;

vec3 pal(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

// Band value by index 0..15 without dynamic indexing (GLSL ES safe).
float specVal(int idx) {
    vec4 v = (idx < 4) ? spec0 : (idx < 8) ? spec1 : (idx < 12) ? spec2 : spec3;
    int c = idx - 4 * (idx / 4);
    return (c == 0) ? v.x : (c == 1) ? v.y : (c == 2) ? v.z : v.w;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float yb = 1.0 - uv.y;                     // 0 at bottom → 1 at top

    float fb = uv.x * NBARS;
    int bar = int(fb);
    float h = pow(clamp(specVal(bar), 0.0, 1.0), 0.8) * 0.92;

    float fxp = fract(fb);
    float inBar = smoothstep(0.05, 0.12, fxp) * smoothstep(0.05, 0.12, 1.0 - fxp);

    vec3 c = pal(0.34 - (yb / max(h, 0.001)) * 0.30 + float(bar) / NBARS * 0.10 + iTime * 0.02);

    vec3 col = vec3(0.02, 0.02, 0.05);
    float fill = smoothstep(0.004, 0.0, yb - h) * inBar;
    col += c * fill * 1.1;
    col += inBar * smoothstep(0.05, 0.0, abs(yb - h)) * (c + 0.3) * (0.7 + 0.6 * audioLevel);
    col += c * inBar * 0.12 * exp(-max(yb - h, 0.0) * 14.0);

    col *= 0.9 + 0.3 * audioLevel;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
