
#include "version.inl"

#include "noise.frag"

uniform samplerCube texCube0;
uniform samplerCube texCube1;
uniform samplerCube texCube2;

uniform vec3 tone;
uniform float lavaExponent;

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
	vec4 bright = vec4(1.0, 1.0, 1.0, 1.0);
	vec4 yellow = vec4(1.0, 0.9, 0.0, 1.0) + vec4(tone, 0.0);
	vec4 red = vec4(1.0, 0.2, 0.0, 1.0) + vec4(tone, 0.0);
	vec4 dark = vec4(0.5, 0.0, 0.0, 1.0) + vec4(tone, 0.0);
	vec4 black = vec4(0.0, 0.0, 0.0, 1.0);

	float lavaAmount = max(1.0 - texture(texCube0, position).r * 5.0, 0.0);
	lavaAmount = pow(lavaAmount, lavaExponent);

	outFragColor = mix(yellow, bright, (clamp(lavaAmount, 0.8, 1.0) - 0.8) / 0.2);
	outFragColor = mix(red, outFragColor, (clamp(lavaAmount, 0.6, 0.8) - 0.6) / 0.2);
	outFragColor = mix(dark, outFragColor, (clamp(lavaAmount, 0.4, 0.6) - 0.4) / 0.2);
	outFragColor = mix(black, outFragColor, clamp(lavaAmount, 0.0, 0.4) / 0.4);
}

