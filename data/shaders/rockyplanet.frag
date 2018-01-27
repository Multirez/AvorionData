
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

    // cloud shadow
    float cloudShadow = max(0.3, 1.0f - texture(cloudMap, texCoord + tangent * 0.001).a);

    // normal lighting
    float lighting = 0.0f;
    lighting = clamp(dot(nnormal, -lightDir), 0.0, 1.0) * cloudShadow;

    // plain lighting
    float plainLighting = clamp(dot(normal, -lightDir), 0.0, 1.0);
    vec3 surfaceColor = texColor.rgb;

    outFragColor.rgb = surfaceColor * lighting;

#ifdef AMBIENT
    // ambient lighting
    outFragColor.rgb += surfaceColor * getAmbientLighting(nnormal);
#endif

    // night lights
    vec4 nightLightColor = texture(nightMap, texCoord);
    outFragColor.rgb += nightLightColor.rgb * pow(1.0f - plainLighting, 5.0);

    // clouds
    vec4 cloud = texture(cloudMap, texCoord);
    outFragColor.rgb = mix(outFragColor.rgb, cloud.rgb * plainLighting * (atmosphereColor * 0.3 + 0.8), cloud.a);

    // atmosphere
    float fresnelValue = 1.0f - clamp(dot(normalize(eye - position), normal), 0.0, 1.0);
    float fresnel = pow(fresnelValue * 1.3, 2.0);

    fresnelValue = 1.0f - clamp(dot(normalize(eye - position), nnormal), 0.0, 1.0);
    fresnel += pow(fresnelValue * 1.0, 2.0);

    if (atmosphereColor != vec3(0, 0, 0))
    {
        outFragColor.rgb = mix(outFragColor.rgb, atmosphereColor * plainLighting, 0.25 + fresnelValue * 0.5);
    }

    outFragColor.rgb += atmosphereColor * plainLighting * fresnel;

    //outFragColor.rgb = texColor.rgb;
    outFragColor.a = 1.0;
}
