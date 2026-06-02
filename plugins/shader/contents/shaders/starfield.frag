#version 440
// Procedural drifting starfield with twinkle.
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
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 uv = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5);

    vec3 col = vec3(0.01, 0.02, 0.05); // deep space backdrop

    // A few parallax layers of stars.
    for (int layer = 0; layer < 3; layer++) {
        float fl = float(layer);
        float scale = 12.0 + fl * 18.0;
        float speed = 0.02 + fl * 0.015;
        vec2 gv = uv * scale + vec2(iTime * speed, iTime * speed * 0.3);
        vec2 id = floor(gv);
        vec2 f = fract(gv) - 0.5;

        float rnd = hash(id + fl * 19.7);
        float star = smoothstep(0.18, 0.0, length(f - (vec2(hash(id), hash(id + 7.1)) - 0.5) * 0.6));
        float twinkle = 0.5 + 0.5 * sin(iTime * (2.0 + rnd * 4.0) + rnd * 6.2831);
        float bright = step(0.92 - fl * 0.04, rnd);
        col += star * bright * twinkle * (0.6 + 0.4 * fl) * vec3(0.8, 0.9, 1.0);
    }
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
