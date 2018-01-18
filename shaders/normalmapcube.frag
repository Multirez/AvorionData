
#include "version.inl"

uniform samplerCube texCube0;
uniform samplerCube texCube1;
uniform samplerCube texCube2;

uniform float texelSize;
uniform float waterLevel;

in vec3 position;
in vec3 tangent;
in vec3 bitangent;



float readHeight(vec3 coords, vec3 normal)
{
	return max(waterLevel, texture(texCube0, coords).r);
}


void main()
{
	vec3 offX = tangent * texelSize;
	vec3 offY = bitangent * texelSize;

	vec3 inNormal = normalize(position);

	float height = readHeight(position, inNormal);

	float nx = readHeight(position - offX, inNormal);
	float px = readHeight(position + offX, inNormal);

	float ny = readHeight(position - offY, inNormal);
	float py = readHeight(position + offY, inNormal);

	float factor = 16.0 * texelSize;
	vec3 vx = vec3(factor, 0.0f, px) - vec3(-factor, 0.0f, nx);
	vec3 vy = vec3(0.0f, factor, py) - vec3(0.0f, -factor, ny);

	vec3 normal = normalize(cross(vx, vy));
	normal = normal * 0.5f + 0.5f;

	outFragColor = vec4(normal, 1.0f);
}

