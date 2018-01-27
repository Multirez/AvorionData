#include "version.inl"

uniform mat4 mWorldViewProjection;
uniform mat4 mWorld;

out vec3 normal;
out vec2 texCoord;
out vec2 texCoord2;

void main(void)
{
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);

    texCoord2 = vNormal.xy * 0.25;
    texCoord = vTex;
}

