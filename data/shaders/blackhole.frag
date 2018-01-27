
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

void main()
{
    mat3 tangentToWorld = mat3(	normalize(tangent),
                                normalize(bitangent),
                                normalize(normal));

    vec3 normalRead = (texture(normalMap, texCoord).rgb - vec3(0.5f)) * 2.0f;
    vec3 nnormal = normalize(normal);

    vec4 texColor = texture(surfaceTexture, texCoord);

    // cloud shadow
    float cloudShadow = max(0.3, 1.0f - texture(cloudMap, texCoord + tangent * 0.002).a);

    // normal lighting
    float lighting = 0.0f;
    lighting = clamp(dot(nnormal, -lightDir), 0.0, 1.0) * cloudShadow;

    // plain lighting
    float plainLighting = clamp(dot(normal, -lightDir), 0.0, 1.0);
    vec3 surfaceColor = texColor.rgb;

    outFragColor.rgb = surfaceColor * lighting;

    // specular
    float specular = clamp(dot(normalize(position - eye), normalize(reflect(-lightDir, nnormal))), 0.0, 1.0);
    specular = pow(specular, 25);

    outFragColor.rgb += lightColor * specular * texColor.a * cloudShadow;

    // night lights
    vec4 nightLightColor = texture(nightMap, texCoord);
    outFragColor.rgb += nightLightColor.rgb * pow(1.0f - plainLighting, 5.0);

    // clouds
    vec4 cloud = texture(cloudMap, texCoord);
    outFragColor.rgb = mix(outFragColor.rgb, cloud.rgb * plainLighting * 0.8, cloud.a);

    // atmosphere
    float fresnelValue = 1.0f - clamp(dot(normalize(eye - position), normal), 0.0, 1.0);
    float fresnel = pow(fresnelValue * 1.1, 6.0);

    outFragColor.rgb += atmosphereColor * fresnel * 1.1;

    outFragColor.a = 1.0;
}
