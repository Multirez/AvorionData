#include "version.inl"

uniform mat4 mWorldViewProjection;

out vec4 color;

void main(void)
{
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);
    gl_PointSize = vSize;

    color = vColor;
}

