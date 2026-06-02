#version 440
// Audio visualizer: concentric rings whose radius/brightness pulse with the
// bass/mid/treble bands, a bass-driven central glow and treble sparkle. Band
// levels (0..1) arrive in the canonical UBO from the kopen-audio helper.
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
};

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float d = length(p);
    float ang = atan(p.y, p.x);

    vec3 col = vec3(0.02, 0.02, 0.05);

    // Bass: warm central glow.
    col += audioBass * 0.9 * vec3(0.95, 0.25, 0.45) * exp(-d * 3.0);

    // One ring per band; radius and brightness track the level.
    float r1 = 0.18 + audioBass * 0.12;
    float r2 = 0.34 + audioMid * 0.12;
    float r3 = 0.52 + audioTreble * 0.12;
    float w = 0.014;
    col += vec3(1.0, 0.30, 0.50) * audioBass   * smoothstep(w, 0.0, abs(d - r1));
    col += vec3(0.30, 1.0, 0.60) * audioMid    * smoothstep(w, 0.0, abs(d - r2));
    col += vec3(0.40, 0.65, 1.0) * audioTreble * smoothstep(w, 0.0, abs(d - r3));

    // Treble sparkle around the outer ring.
    float spark = pow(0.5 + 0.5 * sin(ang * 40.0 + iTime * 3.0), 8.0) * audioTreble;
    col += spark * smoothstep(0.06, 0.0, abs(d - r3)) * vec3(0.6, 0.8, 1.0);

    // Faint rotating hue wash scaled by overall level.
    col += audioLevel * 0.15 * (0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.188) + ang + iTime));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
