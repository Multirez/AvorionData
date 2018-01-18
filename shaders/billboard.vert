#include "version.inl"

uniform mat4 mWorldViewProjection;

out vec4 color;
out vec2 texCoord;
out float size;

void main(void)
{
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);

    color = vColor;
    texCoord = vTex;
    size = vSize;

}

