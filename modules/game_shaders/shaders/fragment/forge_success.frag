varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    // Definindo a cor verde
    vec4 greenColor = vec4(0.0, 1.0, 0.0, texColor.a); // Cor verde com a mesma transparência da textura original

    gl_FragColor = greenColor * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
