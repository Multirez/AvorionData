
#include "version.inl"

uniform samplerCube surfaceTexture;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;
uniform vec3 atmosphereColor;

in vec3 position;
in vec3 normal;
in vec3 texCoord;

#ifdef AMBIENT
#include "ambientlight.inl"
#endif

void main()
{
    vec3 nnormal = normalize(normal);
    vec4 texColor = texture(surfaceTexture, texCoord);

    // normal lighting
    float lighting = 0.0f;
    lighting = clamp(dot(nnormal, -lightDir), 0.0, 1.0);

    // plain lighting
    float plainLighting = clamp(dot(normal, -lightDir), 0.0, 1.0);
    vec3 surfaceColor = texColor.rgb;

    outFragColor.rgb = surfaceColor * lighting;

#ifdef AMBIENT
    // ambient lighting
    outFragColor.rgb += surfaceColor * getAmbientLighting(nnormal);
#endif

    // atmosphere
    float fresnelValue = 1.0f - clamp(dot(normalize(eye - position), normal), 0.0, 1.0);
    float fresnel = pow(fresnelValue * 1.3, 2.0);

    fresnelValue = 1.0f - clamp(dot(normalize(eye - position), nnormal), 0.0, 1.0);
    fresnel += pow(fresnelValue * 1.0, 2.0);

    outFragColor.rgb += atmosphereColor * plainLighting * fresnel;
    outFragColor.a = 1.0;
}
