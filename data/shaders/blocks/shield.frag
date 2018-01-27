#include "../version.inl"

uniform sampler2D refractionTexture;
uniform sampler2D shieldTexture;
uniform samplerCube skyTexture;
uniform samplerCube fogTexture;
uniform float maxFoggyness;
uniform float fogStrength;

uniform vec2 offset;
uniform float intensity;
uniform float reflectivity;
uniform vec2 separation; // = vec2(0.005, 0.0);
uniform vec3 shieldColor; // = vec3(0.5, 0.90, 1.0) * 1.8;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;
uniform vec2 resolution;

in vec2 texWorld;
in vec3 position;
in vec3 tangent;
in vec3 bitangent;
in vec3 normal;

void main()
{
#if defined (LOW_SHIELDS)
    outFragColor.rgb = vec3(0.5, 0.8, 1.0);
    outFragColor.a = min(1.0, intensity * 2.0);
#else
    mat3 tangentToWorld = mat3(normalize(tangent),
                               normalize(bitangent),
                               normalize(normal));

    vec3 distortion = texture(shieldTexture, texWorld + offset).xyz;

    // distorted color
    vec2 texCoords = gl_FragCoord.xy / resolution + (distortion.xy - 0.5) * intensity;

    vec3 distortedColor;
    distortedColor.r = texture(refractionTexture, texCoords - separation).r;
    distortedColor.g = texture(refractionTexture, texCoords).g;
    distortedColor.b = texture(refractionTexture, texCoords + separation).b;

    float distanceToEye = gl_FragCoord.z / gl_FragCoord.w;
    vec3 fogColor = texture(fogTexture, position - eye).rgb;
    float foggyness = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength));

    outFragColor.rgb = distortedColor * mix(shieldColor.rgb, vec3(1), foggyness);
    outFragColor.a = 1;

    vec3 normalRead = (distortion - 0.5f) * 2.0f;
    vec3 nnormal = normalize(tangentToWorld * normalRead);
    vec3 eyedir = normalize(position - eye);

    // fresnel
    float fresnelValue = 1.0f - clamp(dot(normalize(eye - position), normal), 0.0, 1.0);
    float fresnel = pow(fresnelValue * 1.0, 2.0) + 0.01;

    // reflections
    vec3 eyeReflected = reflect(eyedir, nnormal);
    vec3 colorReflected = texture(skyTexture, eyeReflected).rgb * vec3(0.5, 0.8, 1.0);
    outFragColor.rgb += mix(colorReflected * fresnel * reflectivity * 0.5, vec3(0), foggyness);
#endif

}


