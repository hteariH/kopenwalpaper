#version 440
// Aurora: stacked flowing light ribbons over a dark sky. Slowly drifts; gets
// brighter with audioLevel when audio reactivity is on.
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
    vec2 uv = qt_TexCoord0;
    float t = iTime * 0.25;
    float boost = 0.6 + 0.8 * audioLevel;

    // Dark sky gradient (deep blue at the bottom up to near-black).
    vec3 col = mix(vec3(0.02, 0.04, 0.09), vec3(0.0, 0.0, 0.02), uv.y);

    // A few curtains of light, each a soft horizontal band that waves.
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float centre = 0.35 + fi * 0.14;
        float wave = 0.05 * sin(uv.x * 5.0 + t * (1.0 + fi * 0.5) + fi)
                   + 0.03 * sin(uv.x * 11.0 - t * 1.7 + fi * 2.0);
        float curtain = exp(-pow((uv.y - centre - wave) * 9.0, 2.0));
        // Vertical streaks within the curtain.
        float streak = 0.6 + 0.4 * sin(uv.x * 60.0 + t * 3.0 + fi * 4.0);
        vec3 tint = pal(0.45 + fi * 0.1 + uv.x * 0.15 + t * 0.1);
        col += curtain * streak * tint * 0.5 * boost;
    }

    // Faint starfield high up.
    vec2 g = fract(uv * vec2(220.0, 140.0));
    float star = step(0.995, fract(sin(dot(floor(uv * vec2(220.0, 140.0)),
                 vec2(12.9898, 78.233))) * 43758.5453));
    col += star * smoothstep(0.6, 1.0, uv.y) * 0.6;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
