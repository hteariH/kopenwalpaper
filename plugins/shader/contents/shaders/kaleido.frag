#version 440
// Kaleidoscope: N-fold mirror symmetry over a slowly domain-warped colour
// field. Hypnotic, symmetric, always moving.
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

const float SEG = 6.0;  // mirror segments

vec3 pal(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x) + iTime * 0.1;          // slow rotation

    // Fold the angle into a wedge and mirror it.
    float wedge = 6.28318 / SEG;
    a = abs(mod(a, wedge) - wedge * 0.5);

    vec2 q = vec2(cos(a), sin(a)) * r;
    // Domain warp.
    q += 0.20 * vec2(sin(q.y * 3.0 + iTime), cos(q.x * 3.0 - iTime * 1.2));

    float v = sin(q.x * 6.0 + iTime)
            + sin(q.y * 6.0 - iTime * 1.2)
            + sin((q.x + q.y) * 4.0 + iTime * 0.5);

    vec3 col = pal(0.5 + v * 0.15 + r * 0.3 + iTime * 0.03);
    col *= 0.65 + 0.35 * sin(r * 10.0 - iTime * 2.0);
    col *= 1.0 + 0.4 * audioLevel;                   // pulse with loudness
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
