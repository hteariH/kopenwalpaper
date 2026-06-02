#version 440
// Classic animated plasma. Qt6 RHI shader: the std140 block below is the
// fixed ShaderEffect contract — qt_Matrix/qt_Opacity first, then any custom
// properties (iTime, iResolution) mapped by name from the ShaderEffect item.
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
    // Aspect-correct so the pattern is not stretched on wide screens.
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5) * 6.0;
    float t = iTime;

    float v = sin(p.x + t);
    v += sin(0.5 * (p.y + t));
    v += sin(0.4 * (p.x + p.y + t));
    float cx = p.x + 0.5 * sin(t / 3.0);
    float cy = p.y + 0.5 * cos(t / 2.0);
    v += sin(sqrt(cx * cx + cy * cy) + t);

    vec3 col = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.188) + v + iTime * 0.2);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
