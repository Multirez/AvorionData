
#include "version.inl"

#include "noise.frag"

uniform samplerCube texCube0;
uniform samplerCube texCube1;
uniform samplerCube texCube2;

uniform float waterLevel;

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
	vec4 nmValue = texture(texCube0, position);
	vec3 normal = (nmValue.rgb - 0.5f) * 2.0f;
	float height = texture(texCube1, position).r;
	float cloud = cloud(position, 1.0f);

	float snowColor = cloud * 0.3 + 0.7;
	vec4 snow = vec4(snowColor, snowColor, snowColor, 0.0);
	vec4 grass = vec4(0.05, 0.15, 0.05, 0.0) * (cloud + 0.5) / 1.3f;
	vec4 dirt = vec4(0.25, 0.25, 0.1, 0.0);
	vec4 rock = vec4(0.2, 0.2, 0.1, 0.0);
	vec4 water = vec4(0.05, 0.06, 0.15, 0.9f);
	vec4 turq = vec4(0, 0.3, 0.3, 0.9f);

	if(height < waterLevel)
	{
		float lerpFactor = clamp((height - 0.35f) / 0.15, 0.0, 1.0) / 3.0f * cloud;

		outFragColor = mix(water, turq, lerpFactor);
	}
	else
	{
		float factor = (height - 0.5f) * 2.0f;
		outFragColor = mix(grass, rock, factor);
		outFragColor = mix(outFragColor, rock, (1.0f - normal.z) * 5.0f);
		outFragColor = mix(outFragColor, dirt, cloud * cloud);

		outFragColor += mix(vec4(0), snow * 0.05, clamp(height - 0.9, 0.0, 1.0) / 0.1);
	}

	float poleSnowFactor = abs(dot(normalize(position), vec3(0, 1, 0))) * 1.5f - cloud;
	if(poleSnowFactor > 0.9)
	{
		float lerpFactor = clamp((poleSnowFactor - 0.9) / 0.1, 0.0, 1.0);

		outFragColor = mix(outFragColor, snow, lerpFactor);
	}

}

