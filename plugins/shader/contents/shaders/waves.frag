#version 440
// Layered flowing colour waves / gradient bands.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    // CANONICAL UBO — identical in every shader (unused fields kept for layout).
    float imageAspect;
    float breatheAmount;
    float swayAmount;
    float aberration;
    float bokehAmount;
    float vignetteAmount;
    float audioLevel;   // overall loudness 0..1 (audio-reactive)
    float audioBass;
    float audioMid;
    float audioTreble;
    vec4 spec0;   // 16-band spectrum (4 bands per vec4)
    vec4 spec1;
    vec4 spec2;
    vec4 spec3;
};

void main() {
    vec2 uv = qt_TexCoord0;
    float t = iTime * 0.5;

    vec3 col = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float y = uv.y
                + 0.06 * sin(uv.x * 6.2831 * (1.0 + fi * 0.4) + t * (1.0 + fi))
                + 0.04 * sin(uv.x * 3.0 - t * (0.7 + fi * 0.3));
        float band = smoothstep(0.02, 0.0, abs(y - 0.5 + (fi - 1.5) * 0.18));
        vec3 tint = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.188) + fi * 1.3 + t);
        col += band * tint;
    }
    // Subtle vertical gradient backdrop.
    col += mix(vec3(0.02, 0.03, 0.08), vec3(0.10, 0.04, 0.14), uv.y) * 0.6;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
