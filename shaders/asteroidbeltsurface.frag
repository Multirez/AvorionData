
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

in vec2 texCoord;



float cloud(vec2 pos, float size)
{
	vec2 p = pos + 240;
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
	float height = cloud(vec2(0, texCoord.y) + vec2(250.0), 5.0);

	vec3 color;
	if(height < 0.5)
	{
		color = mix(color0, color1, height * 2.0);
	}
	else
	{
		color = mix(color1, color2, (height - 0.5) * 2.0);
	}

	outFragColor = vec4(color, pow(height + 0.3, 4.5));

    float border = 0.05;
	outFragColor.a *= clamp(mix(0, 1, texCoord.y / border), 0, 1);
	outFragColor.a *= clamp(mix(0, 1, (1.0 - texCoord.y) / border), 0, 1);


}

