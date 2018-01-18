#include "version.inl"

uniform vec2 pos;
uniform vec2 size;
uniform vec2 resolution;

out vec4 color;
out vec2 texCoord;
out vec3 position;

void main(void)
{
    vec2 outPos = (vPosition.xy * size + pos) / resolution;
    outPos = outPos * 2.0 - 1.0;
	gl_Position = vec4(outPos, vPosition.z, 1.0);

    color = vColor;
    texCoord = vTex;
	position = vPosition;
}

