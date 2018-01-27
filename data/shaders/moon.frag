
#include "version.inl"

uniform samplerCube surfaceTexture;
uniform samplerCube normalMap;
uniform samplerCube nightMap;
uniform samplerCube cloudMap;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;
uniform vec3 atmosphereColor;

in vec3 position;
in vec3 tangent;
in vec3 bitangent;
in vec3 normal;
in vec3 texCoord;

#ifdef AMBIENT
#include "ambientlight.inl"
#endif

void main()
{
    mat3 tangentToWorld = mat3(	normalize(tangent),
                                normalize(bitangent),
                                normalize(normal));

    vec3 normalRead = (texture(normalMap, texCoord).rgb - vec3(0.5f)) * 2.0f;
    vec3 nnormal = normalize(tangentToWorld * normalRead);

    vec4 texColor = texture(surfaceTexture, texCoord);

    // normal lighting
    float lighting = 0.0f;
    lighting = clamp(dot(nnormal, -lightDir), 0.0, 1.0);

    // plain lighting
    vec3 surfaceColor = texColor.rgb;

    outFragColor.rgb = surfaceColor * lighting;

#ifdef AMBIENT
    // ambient lighting
    outFragColor.rgb += surfaceColor * getAmbientLighting(nnormal);
#endif

    // night lights
    vec4 nightLightColor = texture(nightMap, texCoord);
    outFragColor.rgb += nightLightColor.rgb * pow(1.0f - lighting, 5.0);

    outFragColor.a = 1.0;
}
