#include "version.inl"

uniform vec3 lightDir;
uniform vec3 atmosphereColor;

in vec3 normal;
in vec4 color;

void main()
{
	vec3 nnormal = normalize(normal);

	float lighting = 0.0f;
	lighting = clamp(dot(nnormal, -lightDir), 0.0, 1.0);

    float intensity = color.r;

    intensity += 0.15f;
    intensity = pow(intensity, 10.0);

	outFragColor.rgb = atmosphereColor.rgb * intensity * lighting;
	outFragColor.a = color.a * lighting;
}

