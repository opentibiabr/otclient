// Fragment Shader (GLSL 1.20)
// Text with black outline (classic style)
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
    
    // Multi-layer sampling for smooth black outline (same as gold but smaller)
    float outline = 0.0;
    float samples = 0.0;
    
    // Inner ring (0.6 pixels) - stronger weight
    for (float angle = 0.0; angle < 6.28318; angle += 0.785398) { // 8 samples at 45° intervals
        vec2 offset = vec2(cos(angle), sin(angle)) * 0.6;
        outline += texture2D(u_Tex0, v_TexCoord + offset * texelSize).a * 1.5;
        samples += 1.5;
    }
    
    // Outer ring (1.0 pixels) - softer weight for anti-aliasing
    for (float angle = 0.0; angle < 6.28318; angle += 0.785398) { // 8 samples
        vec2 offset = vec2(cos(angle), sin(angle)) * 1.0;
        outline += texture2D(u_Tex0, v_TexCoord + offset * texelSize).a * 0.8;
        samples += 0.8;
    }
    
    outline = min(outline / samples, 1.0);
    
    if (outline > 0.05) {
        // Black outline with smooth alpha blending but fully opaque where visible
        float alpha = smoothstep(0.05, 0.4, outline);
        gl_FragColor = vec4(0.0, 0.0, 0.0, alpha);
    } else {
        discard;
    }
}
