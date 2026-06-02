#version 440
// Circular spectrum: 16 band levels (spec0..spec3 in the canonical UBO) laid
// out as radial bars around a centre circle. Uniform-fed (no texture).
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

float specVal(int idx) {
    vec4 v = (idx < 4) ? spec0 : (idx < 8) ? spec1 : (idx < 12) ? spec2 : spec3;
    int c = idx - 4 * (idx / 4);
    return (c == 0) ? v.x : (c == 1) ? v.y : (c == 2) ? v.z : v.w;
}

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float r = length(p);
    float ang = atan(p.y, p.x);
    float tt = ang / 6.28318 + 0.5;            // 0..1 around the circle

    float fb = tt * NBARS;
    int seg = int(fb);
    float h = pow(clamp(specVal(seg), 0.0, 1.0), 0.8);

    float R0 = 0.18 + 0.05 * audioBass;
    float barLen = h * 0.30;
    float rr = r - R0;

    float fxa = fract(fb);
    float inBar = smoothstep(0.08, 0.18, fxa) * smoothstep(0.08, 0.18, 1.0 - fxa);

    vec3 c = pal(float(seg) / NBARS + iTime * 0.05);
    vec3 col = vec3(0.02, 0.02, 0.05);

    float fill = step(0.0, rr) * smoothstep(0.004, 0.0, rr - barLen) * inBar;
    col += c * fill;
    col += inBar * smoothstep(0.02, 0.0, abs(rr - barLen)) * (c + 0.3);

    col += pal(iTime * 0.05) * 0.8 * smoothstep(0.012, 0.0, abs(r - R0));
    col += pal(0.1 + iTime * 0.05) * audioLevel * 0.5 * exp(-r * 5.0);

    col *= smoothstep(1.2, 0.15, r);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
