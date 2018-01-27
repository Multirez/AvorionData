
#include "version.inl"

#include "noise.frag"

uniform samplerCube starTexture;
uniform samplerCube darkenTexture;

in vec4 color;
in vec3 normal;
in vec3 position;



void main()
{
	vec3 p = position * 5.0 + 240;

	float n = noise(p);
	n = n + noise(p * 2.0f) / 2.0f;
	n = n + noise(p * 4.0f) / 4.0f;
	n = n + noise(p * 8.0f) / 8.0f;
	n = n + noise(p * 16.0f) / 16.0f;
	n = n + noise(p * 32.0f) / 32.0f;
	n = n + noise(p * 64.0f) / 64.0f;
	n = n + noise(p * 128.0f) / 128.0f;
	n = n + noise(p * 256.0f) / 256.0f;
	n = n * 0.5 + 0.5;

	n /= 15.0f + 0.05;

	vec4 texColor = texture(starTexture, position);

	outFragColor = vec4(texColor.xyz + n * color.rgb, 1);
	outFragColor.rgb += vec3(n / 3.0f);
}
