#include "version.inl"

out vec4 color;
out vec2 texCoord;
out vec3 position;

void main(void)
{
    gl_Position.xyz = vPosition;
    gl_Position.w = 1.0;

    color = vColor;
    texCoord = vTex;
    position = vPosition;
}

