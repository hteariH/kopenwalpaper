#version 440
// Endless flying tunnel: rings rush inward, the whole thing twists slowly.
// Flight speed picks up with the bass when audio reactivity is on.
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
    float r = max(length(p), 1e-3);
    float a = atan(p.y, p.x);

    float speed = 0.5 + audioBass * 1.2;
    float depth = 0.30 / r + iTime * speed;     // moves inward
    float u = a / 6.28318 + iTime * 0.04;        // angular + slow twist

    float rings = 0.5 + 0.5 * sin(depth * 12.566);
    float stripes = 0.5 + 0.5 * sin(u * 40.0);

    vec3 c = pal(depth * 0.08 + u + iTime * 0.05);
    vec3 col = c * (0.25 + 0.75 * rings) * (0.6 + 0.4 * stripes);

    // Treble sparkle flickers on the ring crests.
    col += audioTreble * 0.5 * pow(rings, 6.0) * vec3(0.8, 0.9, 1.0);

    // Depth fog: dark at the vanishing point, fades in toward the rim.
    col *= smoothstep(0.0, 0.35, r);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
