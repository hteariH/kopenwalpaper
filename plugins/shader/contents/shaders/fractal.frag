#version 440
// Animated Julia set: the constant c orbits slowly so the fractal morphs;
// smooth (continuous) iteration count drives the colour.
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

const int MAX_ITER = 64;

vec3 pal(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void main() {
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 z = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) * 2.6;

    // c orbits a circle; radius wobbles a touch with bass.
    float rad = 0.7885 + audioBass * 0.05;
    vec2 c = rad * vec2(cos(iTime * 0.18), sin(iTime * 0.21));

    float it = 0.0;
    for (int i = 0; i < MAX_ITER; i++) {
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 16.0) {
            break;
        }
        it += 1.0;
    }

    vec3 col;
    if (it >= float(MAX_ITER)) {
        col = vec3(0.0);                      // inside the set
    } else {
        float sn = it - log2(max(log2(dot(z, z)), 1.0));  // smooth iteration
        col = pal(0.5 + sn * 0.025 + iTime * 0.03);
        col *= 0.4 + 0.6 * smoothstep(0.0, 8.0, sn);
    }
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
