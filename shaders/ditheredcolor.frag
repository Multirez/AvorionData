
#include "version.inl"

in vec4 color;

uniform vec2 offset;
uniform sampler2D permTexture;

void main()
{
    vec3 dither = vec3(texture(permTexture, gl_FragCoord.xy / 256.0 + offset).a / 256.0);

    dither = dither + mod(gl_FragCoord.y, 2) * 0.065;

	outFragColor = vec4(min(vec3(1.0), max(vec3(0), color.rgb - dither)), color.a);
}
