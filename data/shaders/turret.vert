#include "version.inl"

uniform mat4 mWorldViewProjection[3];
uniform mat4 mWorld[3];

out vec4 color;
out vec3 normal;
out vec3 position;
out vec2 texCoord;
out vec3 ambientLight;

void main(void)
{
#ifdef NO_INT_ATTRIBUTES
    gl_Position = mWorldViewProjection[0] * vec4(vPosition, 1.0);

    position = vec3(mWorld[0] * vec4(vPosition, 1.0));
    normal = vec3(mWorld[0] * vec4(vNormal, 0.0));
#else
    gl_Position = mWorldViewProjection[int(vIndex)] * vec4(vPosition, 1.0);

    position = vec3(mWorld[int(vIndex)] * vec4(vPosition, 1.0));
    normal = vec3(mWorld[int(vIndex)] * vec4(vNormal, 0.0));
#endif
    color = vColor;
    texCoord = vTex;
    ambientLight = vLight;

}
