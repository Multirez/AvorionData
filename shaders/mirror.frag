
#include "version.inl"

in vec2 texCoord;
in vec2 texCoord2;

void main()
{
    vec3 c = vec3(0, 0, 0);

    c += step(mod(texCoord2.x * 2, 2), 0.02);
    c += step(mod(texCoord2.y * 2, 2), 0.02);
    c = max(min(c, vec3(1, 1, 1)), vec3(0, 0, 0));
    c *= 0.25;

    c += step(mod(texCoord2.x * 1, 2), 0.01);
    c += step(mod(texCoord2.y * 1, 2), 0.01);
    c = max(min(c, vec3(1, 1, 1)), vec3(0, 0, 0));
    c *= 0.75;

    c += step(mod(texCoord2.x * 0.1, 2), 0.003);
    c += step(mod(texCoord2.y * 0.1, 2), 0.003);
    c = max(min(c, vec3(1, 1, 1)), vec3(0, 0, 0));
    c *= 0.95;

	outFragColor.a = max(0, 0.75 * (0.5f - distance(texCoord, vec2(0.5, 0.5))));
    outFragColor.rgb = c.rgb;
}
