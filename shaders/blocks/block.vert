#include "../version.inl"

#ifdef NUM_INSTANCES
uniform mat4 mViewProjection;
uniform mat4 mWorld[NUM_INSTANCES];

#ifdef SHADOW
uniform mat4 shadowVP;
#endif // SHADOW

#else
uniform mat4 mWorldViewProjection;
uniform mat4 mWorld;

#ifdef SHADOW
uniform mat4 shadowWVP;
#endif // SHADOW

#endif // NUM_INSTANCES

uniform vec3 eye;

out vec4 color;
out vec3 normal;
out vec3 tangent;
out vec3 bitangent;
out vec3 position;
out vec2 texCoord;
out vec2 texWorld;
out vec3 ambientLight;
out vec4 util0;

#ifdef SHADOW
out vec4 shadowCoord;
#endif // SHADOW

#ifdef LOW
out float sideIndex;
#endif
#ifdef HIGH
flat out uint sideIndex;
#endif // HIGH

void main(void)
{
#ifdef NUM_INSTANCES
    int i = int(vInstancedIndex);

    gl_Position = mViewProjection * mWorld[i] * vec4(vPosition, 1.0);
    position = vec3(mWorld[i] * vec4(vPosition, 1.0));
    normal = vec3(mWorld[i] * vec4(vNormal, 0.0));

#ifdef NORMAL_MAPPING
    tangent = vec3(mWorld[i] * vec4(vTangent, 0.0));
    bitangent = vec3(mWorld[i] * vec4(vBitangent, 0.0));
#endif
#ifdef SHADOW
    shadowCoord = (shadowVP * mWorld[i]) * vec4(vPosition, 1.0);
#endif // SHADOW

#else
    gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);
    position = vec3(mWorld * vec4(vPosition, 1.0));
    normal = vec3(mWorld * vec4(vNormal, 0.0));
#ifdef NORMAL_MAPPING
    tangent = vec3(mWorld * vec4(vTangent, 0.0));
    bitangent = vec3(mWorld * vec4(vBitangent, 0.0));
#endif

#ifdef SHADOW
    shadowCoord = shadowWVP * vec4(vPosition, 1.0);
#endif // SHADOW

#endif // NUM_INSTANCES

//    color = vColor * 0.6;
    color = vColor;

//    float h = (vPosition.y + 0.0) / 2.0;
//    color = vec4(h, h, h, 1.0);

//    color.rgb = vNormal.xzy * 0.5 + 0.5;


    texCoord = vTex;
    util0 = vUtil0;
    texWorld = vTexWorld * 0.1;
    ambientLight = vLight;

#ifdef LOW
    if (vNormal.x > 0.9)
    {
        sideIndex = 1.0f;
    }
    else if (vNormal.y < -0.9)
    {
        sideIndex = 2.0f;
    }
    else if (vNormal.y > 0.9)
    {
        sideIndex = 3.0f;
    }
    else if (vNormal.z < -0.9)
    {
        sideIndex = 4.0f;
    }
    else if (vNormal.z > 0.9)
    {
        sideIndex = 5.0f;
    }
    else
    {
        sideIndex = 0.0f;
    }
#else
    sideIndex = vIndex;
#endif
}

