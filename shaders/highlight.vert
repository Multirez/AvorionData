#include "version.inl"

uniform mat4 mWorldViewProjection;
uniform mat4 mWorld;

uniform vec3 highlightDir;
uniform float highlightThreshold;
uniform vec4 highlightColor;

out vec4 color;
out vec3 normal;
out vec3 position;
out vec2 texCoord;
out vec3 tangent;
out vec3 bitangent;

void main(void)
{
	gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);

	position = vec3(mWorld * vec4(vPosition, 1.0));
    normal = vec3(mWorld * vec4(vNormal, 0.0));
    tangent = vec3(mWorld * vec4(vTangent, 0.0));
    bitangent = vec3(mWorld * vec4(vBitangent, 0.0));

    color = vColor;
    texCoord = vTex;

    if (abs(dot(highlightDir, vNormal)) > highlightThreshold)
    {
        color = highlightColor;
    }


}


