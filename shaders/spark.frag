
#include "version.inl"

in vec4 color;



void main()
{
	float light = 1.0f - clamp(distance(gl_PointCoord, vec2(0.5, 0.5)) * 2.0, 0.0, 1.0);
	light = light * light * light;
	light /= 1.5f;

	outFragColor = vec4(light, light, light, 1) * color;
}
