
varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    // Ignorando a conversão para preto e branco e definindo diretamente a cor vermelha
    vec4 redColor = vec4(1.0, 0.0, 0.0, texColor.a); // Cor vermelha com a mesma transparência da textura original

    gl_FragColor = redColor * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
