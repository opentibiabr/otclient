// Fragment Shader (GLSL 1.20)
// Text with soft glow effect
uniform sampler2D u_Tex0;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

void main() {
    vec4 baseColor = texture2D(u_Tex0, v_TexCoord);
    
    // If this pixel is part of the text, render it brighter
    if (baseColor.a > 0.1) {
        // Brighten the text slightly for glow effect
        vec3 brightColor = min(baseColor.rgb * u_Color.rgb * 1.2, vec3(1.0));
        gl_FragColor = vec4(brightColor, baseColor.a);
        return;
    }
    
    vec2 texelSize = vec2(1.0 / 512.0, 1.0 / 512.0);
    
    // Multi-sample for soft glow
    float glow = 0.0;
    float maxDist = 2.0; // Reduced glow radius
    
    for (float dist = 1.0; dist <= maxDist; dist += 1.0) {
        float weight = (maxDist - dist + 1.0) / maxDist;
        
        glow += texture2D(u_Tex0, v_TexCoord + vec2(-texelSize.x * dist, 0.0)).a * weight;
        glow += texture2D(u_Tex0, v_TexCoord + vec2(texelSize.x * dist, 0.0)).a * weight;
        glow += texture2D(u_Tex0, v_TexCoord + vec2(0.0, -texelSize.y * dist)).a * weight;
        glow += texture2D(u_Tex0, v_TexCoord + vec2(0.0, texelSize.y * dist)).a * weight;
    }
    
    glow = min(glow / 4.0, 1.0);
    
    if (glow > 0.05) {
        // Use text color for glow
        gl_FragColor = vec4(u_Color.rgb, glow * 0.5);
    } else {
        discard;
    }
}
