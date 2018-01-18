#include "version.inl"

uniform mat4 mWorldViewProjection;

uniform vec3 eye;
uniform float screenHeight;

out vec4 color;

void main(void)
{
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);
    gl_PointSize = screenHeight * vSize / gl_Position.w * 2.0f;

    color = vColor;
}

