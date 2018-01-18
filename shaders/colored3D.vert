#include "version.inl"

uniform mat4 mWorldViewProjection;
uniform mat4 mWorld;

uniform vec4 in_color;

out vec4 color;
out vec3 normal;
out vec3 position;
out vec2 texCoord;

void main(void)
{
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);

    position = vec3(mWorld * vec4(vPosition, 1.0));
    normal = vec3(mWorld * vec4(vNormal, 0.0));
    color = vColor * in_color;
    texCoord = vTex;

}

