
#include "version.inl"

#include "noise.frag"

in vec2 texCoord;
in vec3 position;

uniform float size;

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
	float plateauHeight = 0.4;

	float n = cloud(position, size);
	float height = n;

	float minimum = 0.2;
	float maximum = 0.22;

	if(height > minimum && height < maximum)
	{
		height = mix(height, plateauHeight, (height - minimum) * 1.0 / (maximum - minimum));
	}
	else if(height > maximum)
	{
        height = plateauHeight;
	}

	height = height - pow(cloud(position, 5.0f), 5) * 0.5;

	outFragColor = vec4(height, height, height, 1.0);
}

