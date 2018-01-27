
#include "version.inl"

in vec4 color;

void main()
{
	float light = 1.0 - clamp(dot(gl_PointCoord, vec2(0.5, 0.5)) * 2.0, 0.0, 1.0);

	light = light * light;

	outFragColor = vec4(light * color.rgb, 1);
}
