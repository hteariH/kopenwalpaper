#version 440
// Standard ShaderEffect pass-through vertex shader. Declaring qt_TexCoord0 as
// an explicit location-0 output makes the GL backend's stage linking match the
// fragment shaders' location-0 input (the default built-in VS does not, which
// triggers "input qt_TexCoord0 with explicit location has no matching output").
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    // CANONICAL UBO — must be byte-identical in every shader (GL links the
    // binding-0 block across all stages; any mismatch fails linking).
    float imageAspect;     // source image width/height (image shaders)
    float breatheAmount;   // living-image effect strengths (1.0 = default, 0 = off)
    float swayAmount;
    float aberration;
    float bokehAmount;
    float vignetteAmount;
};

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
