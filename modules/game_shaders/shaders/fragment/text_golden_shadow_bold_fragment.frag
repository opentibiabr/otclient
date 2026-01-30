// Fragment Shader (GLSL 1.20)
// Text Outline with multi-sample anti-aliasing for smooth borders
uniform sampler2D u_Tex0;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

void main() {
    vec4 baseColor = texture2D(u_Tex0, v_TexCoord);
    
    // If this pixel is part of the text, render it normally
    if (baseColor.a > 0.1) {
        gl_FragColor = vec4(baseColor.rgb * u_Color.rgb, baseColor.a);
        return;
    }
    
    // Calculate texel size dynamically based on texture
    vec2 texelSize = vec2(1.0 / 512.0, 1.0 / 512.0);
    
    // Multi-layer sampling for smoother outline
    float outline = 0.0;
    float samples = 0.0;
    
    // Inner ring (0.7 pixels) - stronger weight
    for (float angle = 0.0; angle < 6.28318; angle += 0.785398) { // 8 samples at 45° intervals
        vec2 offset = vec2(cos(angle), sin(angle)) * 0.7;
        outline += texture2D(u_Tex0, v_TexCoord + offset * texelSize).a * 1.5;
        samples += 1.5;
    }
    
    // Outer ring (1.2 pixels) - softer weight for anti-aliasing
    for (float angle = 0.0; angle < 6.28318; angle += 0.785398) { // 8 samples
        vec2 offset = vec2(cos(angle), sin(angle)) * 1.2;
        outline += texture2D(u_Tex0, v_TexCoord + offset * texelSize).a * 0.8;
        samples += 0.8;
    }
    
    outline = min(outline / samples, 1.0);
    
    if (outline > 0.05) {
        // Gold outline color #ee8413 with smooth alpha blending
        vec3 outlineColor = vec3(0.933, 0.518, 0.075);
        float alpha = smoothstep(0.05, 0.4, outline);
        gl_FragColor = vec4(outlineColor, alpha * 0.95);
    } else {
        discard;
    }
}