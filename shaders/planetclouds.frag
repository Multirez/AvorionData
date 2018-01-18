
#include "version.inl"

uniform sampler2D diffuseTexture;

in vec3 position;

float pi = 3.14159265358979323846264;

void main()
{
	float hor = atan(position.z, position.x);
	float vert = atan(position.y, length(vec2(position.x, position.z)));

	hor = hor / pi * 0.5 + 0.5;
	vert = vert / pi + 0.5;

	float color = texture(diffuseTexture, vec2(hor, vert)).r;
	color = max(color, texture(diffuseTexture, vec2(hor + 0.33, vert)).r);
	color = max(color, texture(diffuseTexture, vec2(hor + 0.66, vert)).r);

	outFragColor = vec4(1, 1, 1, color);
}

