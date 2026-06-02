#version 440
// "Living image": animates ANY user-supplied picture (sampler `source`,
// binding 1) with gentle motion — breathing zoom, parallax sway, drifting
// bokeh and a breathing chromatic aberration. Generic: the real image aspect
// comes from the `imageAspect` uniform, so it cover-fits any photo/artwork.
// All motion is sine-driven, so the loop never jumps.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    // CANONICAL UBO — identical in every shader.
    float imageAspect;     // source image width / height
    float breatheAmount;   // effect strengths (1.0 = default, 0 = off)
    float swayAmount;
    float aberration;
    float bokehAmount;
    float vignetteAmount;
    float audioLevel;   // overall loudness 0..1 (audio-reactive)
    float audioBass;
    float audioMid;
    float audioTreble;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Soft drifting bokeh dots, additive, cool tint.
vec3 bokeh(vec2 uv, float scrAspect) {
    vec3 acc = vec3(0.0);
    vec2 p = vec2(uv.x * scrAspect, uv.y);
    for (int layer = 0; layer < 2; layer++) {
        float fl = float(layer);
        float scale = 5.0 + fl * 4.0;
        float drift = iTime * (0.03 + fl * 0.02);
        vec2 gv = p * scale + vec2(0.0, -drift); // float upward
        vec2 id = floor(gv);
        vec2 f = fract(gv) - 0.5;
        vec2 rnd = vec2(hash(id + fl * 11.3), hash(id + fl * 27.7));
        float d = length(f - (rnd - 0.5) * 0.7);
        float dot = smoothstep(0.35, 0.0, d);
        float twinkle = 0.4 + 0.6 * sin(iTime * (0.8 + rnd.x * 1.5) + rnd.y * 6.2831);
        float present = step(0.62, hash(id + fl * 5.1));
        acc += dot * present * twinkle * (0.05 + 0.04 * fl) * vec3(0.6, 0.78, 1.0);
    }
    return acc;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float scrAspect = iResolution.x / max(iResolution.y, 1.0);
    float imgAspect = max(imageAspect, 0.01);

    // --- cover-fit the source image onto the screen ---
    vec2 c = uv - 0.5;
    if (scrAspect > imgAspect) {
        c.y *= imgAspect / scrAspect;
    } else {
        c.x *= scrAspect / imgAspect;
    }

    // --- breathing zoom + slow parallax sway ---
    float breathe = 1.0 - 0.018 * breatheAmount * sin(iTime * 0.45);
    c *= breathe;
    vec2 tuv = c + 0.5;
    tuv += vec2(sin(iTime * 0.30), cos(iTime * 0.23)) * 0.004 * swayAmount;

    // --- breathing chromatic aberration along the radial direction ---
    vec2 dir = tuv - 0.5;
    float ca = (0.0010 + 0.0010 * sin(iTime * 0.8)) * aberration;
    vec3 col;
    col.r = texture(source, tuv + dir * ca).r;
    col.g = texture(source, tuv).g;
    col.b = texture(source, tuv - dir * ca).b;

    // --- drifting bokeh sparkles ---
    col += bokeh(uv, scrAspect) * bokehAmount;

    // --- gentle vignette to focus the centre ---
    float vig = smoothstep(1.18, 0.30, length((uv - 0.5) * vec2(scrAspect, 1.0)));
    col *= mix(1.0 - 0.15 * vignetteAmount, 1.0, vig);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
