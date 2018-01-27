#include "version.inl"

uniform vec4 background;
uniform vec4 start;
uniform vec4 end;
uniform vec4 negative;
uniform float factor;

out vec4 color;
out vec3 position;

void main()
{
    gl_Position.xyz = vPosition;
    gl_Position.w = 1.0;
    position = vPosition;

    vec4 c1 = mix(negative, start, step(0, factor));
    vec4 c2 = mix(negative, end, step(0, factor));

    color = background;

    vec4 foreground = mix(c2, c1, vTex.x);

    float f = (factor - vTex.x) / (vTex.y - vTex.x);
    float fade = clamp(f, 0.0, 1.0);
    color = mix(background, foreground, fade);

}
