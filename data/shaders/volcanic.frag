
#include "version.inl"

uniform samplerCube surfaceTexture;
uniform samplerCube normalMap;
uniform samplerCube glowMap;

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
    float plainLighting = clamp(dot(normal, -lightDir), 0.0, 1.0);
    vec3 surfaceColor = texColor.rgb;

    outFragColor.rgb = surfaceColor * lighting;

    // specular
    float specular = clamp(dot(normalize(position - eye), normalize(reflect(-lightDir, nnormal))), 0.0, 1.0);
    specular = pow(specular, 25);

    outFragColor.rgb += lightColor * specular * texColor.a;

#ifdef AMBIENT
    // ambient lighting
    outFragColor.rgb += surfaceColor * getAmbientLighting(nnormal);
#endif

    // glow lights
    vec4 glowLightColor = texture(glowMap, texCoord);
    outFragColor.rgb += glowLightColor.rgb;

    // atmosphere
    float fresnelValue = 1.0f - clamp(dot(normalize(eye - position), normal), 0.0, 1.0);
    float fresnel = pow(fresnelValue * 1.5, 3.0);

    outFragColor.rgb += atmosphereColor * plainLighting * fresnel;
    outFragColor.a = 1.0;
}
