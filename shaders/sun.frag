
#include "version.inl"

uniform vec3 suncolor;

in vec2 texCoord;



void main()
{
	float light = 1.0f - clamp((distance(texCoord, vec2(0.5, 0.5)) - 0.08) * 2.0, 0.0, 1.0);
	light = light * light * light;

	outFragColor = vec4(suncolor * light, 1);
}
