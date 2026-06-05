varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;
uniform float u_Time; // Tempo em segundos

void main()
{
    // Reseta u_Time a cada 10.0 segundos
    float modTime = mod(u_Time, 10.0);

    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Calcula o período de piscada que diminui pela metade progressivamente
    float blinkPeriod = pow(2.0, -floor(log2(modTime)));
    
    // Calcula se estamos em um intervalo de piscada
    bool isBlinkInterval = mod(floor(modTime / blinkPeriod), 2.0) == 0.0;

    // Alternando entre preto e branco
    vec4 color = vec4(0.0, 0.0, 0.0, texColor.a); // Preto como cor padrão
    if (isBlinkInterval) {
        color = vec4(1.0, 1.0, 1.0, texColor.a); // Branco durante intervalos pares
    }

    gl_FragColor = color * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
