
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
	float n = cloud(position, 1.0f);
	float height = n;

	if(height > 0.5 && height < 0.75)
	{
		height = mix(height, 1.0, (height - 0.5) * 4.0);
	}
	else if(height > 0.75)
	{
        height = 1.0f;
	}

	height = height - pow(cloud(position, 5.0f), 5) * 0.5;

	outFragColor = vec4(height, height, height, 1.0);
}

