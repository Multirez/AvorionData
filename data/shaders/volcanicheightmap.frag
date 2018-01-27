
#include "version.inl"

#include "noise.frag"

in vec2 texCoord;
in vec3 position;



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
	float roughHeight = cloud(position, 0.5) / 5.0 + 0.0;
	float n = cloud(position, 1.0);

	float height = abs(n - cloud(position + 500, roughHeight)) / 2.5;
	height = clamp(height, 0.0, 1.0);
	height += (abs(cloud(position + 1234, 4.0) / 2.0 - cloud(position + 2345, 0.8))) / 2.0;

	outFragColor = vec4(height, height, height, 1.0);
}

