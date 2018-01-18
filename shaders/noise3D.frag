
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

	outFragColor = vec4(0.5 + 0.5 * vec3(n, n, n), 1.0);
}

