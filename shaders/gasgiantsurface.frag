
#include "version.inl"

#include "noise.frag"

uniform samplerCube texCube0;
uniform samplerCube texCube1;
uniform samplerCube texCube2;

uniform float displacementStrength;
uniform float graininess;
uniform vec3 color0;
uniform vec3 color1;
uniform vec3 color2;

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
	float distortionX = cloud(position, graininess) * displacementStrength;
	float distortionZ = cloud(position + 150, graininess) * displacementStrength;

	float height = cloud(vec3(distortionX, position.y, distortionZ) + vec3(250.0), 0.50);

	vec3 color;
	if(height < 0.5)
	{
		color = mix(color0, color1, height * 2.0);
	}
	else
	{
		color = mix(color1, color2, (height - 0.5) * 2.0);
	}

	outFragColor = vec4(color, 0.0);
}

