
#include "version.inl"

#include "noise.frag"

uniform float size; // Used for texture animation

in vec2 texCoord;
in vec3 position;





void main( void )
{
    vec3 p = position + 240;

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

	//float n = noise(vec3(4.0 * v_texCoord3D.xyz * (2.0 + sin(0.5 * time))));

	//outFragColor = vec4(0.5 + 0.5 * vec3(n, n, n), 1.0);
	outFragColor = vec4(0.5 + 0.5 * vec3(n, n, n), 1.0);
	//outFragColor = vec4(1, 0, 1, 1);

	//outFragColor = vec4(position, 1);
}

