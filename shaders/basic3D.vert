#include "version.inl"

#ifdef NUM_INSTANCES
uniform mat4 mViewProjection;
uniform mat4 mWorld[NUM_INSTANCES];

#ifdef UNIFORM_COLOR
uniform vec3 uColors[NUM_INSTANCES];
#endif // UNIFORM_COLOR

#else

uniform mat4 mWorldViewProjection;
uniform mat4 mWorld;

#ifdef UNIFORM_COLOR
uniform vec3 uColor;
#endif // UNIFORM_COLOR
#endif // NUM_INSTANCES

out vec4 color;
out vec3 normal;
out vec3 position;
out vec2 texCoord;
out vec3 tangent;
out vec3 bitangent;

void main(void)
{
    color = vColor;

#ifdef NUM_INSTANCES
    int i = gl_InstanceID;

    gl_Position = mViewProjection * mWorld[i] * vec4(vPosition, 1.0);
    position = vec3(mWorld[i] * vec4(vPosition, 1.0));
    normal = vec3(mWorld[i] * vec4(vNormal, 0.0));
    tangent = vec3(mWorld[i] * vec4(vTangent, 0.0));
    bitangent = vec3(mWorld[i] * vec4(vBitangent, 0.0));

#ifdef UNIFORM_COLOR
    color = color * vec4(uColors[i], 1);
#endif

#else
	gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);

	position = vec3(mWorld * vec4(vPosition, 1.0));
    normal = vec3(mWorld * vec4(vNormal, 0.0));
    tangent = vec3(mWorld * vec4(vTangent, 0.0));
    bitangent = vec3(mWorld * vec4(vBitangent, 0.0));

#ifdef UNIFORM_COLOR
    color = color * vec4(uColor, 1);
#endif

#endif // NUM_INSTANCES

    texCoord = vTex;

}

