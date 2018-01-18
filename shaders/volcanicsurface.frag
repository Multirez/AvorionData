
#include "version.inl"

#include "noise.frag"

uniform samplerCube texCube0;
uniform samplerCube texCube1;
uniform samplerCube texCube2;

uniform vec3 tone;

in vec3 position;
in vec3 tangent;
in vec3 bitangent;

float cloud(vec3 pos, float size)
{
	vec3 p = pos + 240;
	p *= size;

	float n = noise(p);
	n = n + noise(p * 2.0f) / 2.0f;
	n = n + noise(p * 4.0f) / 4.0f;
	n = n + noise(p * 8.0f) / 8.0f;
	n = n + noise(p * 16.0f) / 16.0f;
	n = n + noise(p * 32.0f) / 32.0f;
	n = n + noise(p * 64.0f) / 64.0f;
	n = n + noise(p * 128.0f) / 128.0f;
	n = n + noise(p * 256.0f) / 256.0f;

	return 0.5 + 0.5 * n;
}

void main()
{
	vec3 ground = vec3(0.08 + 0.07 * abs(cloud(position + 765, 3.0) - cloud(position + 543, 0.6)));
	float specular = max(0.4 - texture(texCube1, position).r, 0.0);
	specular *= cloud(position + 321, 10.0);
	outFragColor = vec4(ground + tone, specular);
}

