#include "version.inl"

in vec4 color;
in vec3 position;
in vec3 normal;
in vec2 texCoord;

void main()
{
	vec3 lightDir = normalize(vec3(-1, -1, -1));

	vec3 nnormal = normalize(normal);

	// direct lighting
	float lightIntensity = clamp(dot(nnormal, -lightDir), 0.0, 1.0);
	outFragColor.rgb = color.rgb * min(1, lightIntensity + 0.6);

	outFragColor.a = 1;
}
