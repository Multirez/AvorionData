#include "../version.inl"

uniform sampler2D platingTexture;
uniform samplerCube fogTexture;
uniform float maxFoggyness;
uniform float fogStrength;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;

uniform float glossyness;
uniform float specularity;

in vec4 color;
in vec3 position;
in vec3 normal;
in vec2 texWorld;
in vec3 ambientLight;

#include "../ambientlight.inl"

#ifdef SHADOW
#include "../shadow.inl"
#endif

#ifdef NORMAL_MAPPING
uniform sampler2D normalTexture;
in vec3 tangent;
in vec3 bitangent;
#endif // NORMAL_MAPPING

#ifdef REFLECTIONS
uniform float minReflectivity;
uniform float maxReflectivity;
uniform samplerCube skyTexture;
#endif // REFLECTIONS



void main()
{
    vec4 texBase = texture(platingTexture, texWorld);

#ifdef NORMAL_MAPPING
    mat3 tangentToWorld = mat3(
                              normalize(bitangent),
                              normalize(tangent),
                              normalize(normal)
                          );

    vec3 normalTex = texture(normalTexture, texWorld).zyx;
    vec3 normalRead = (normalTex - vec3(0.5)) * 2.0;
    vec3 nnormal = normalize(tangentToWorld * normalRead);
#else
    vec3 nnormal = normalize(normal);
#endif

    vec3 eyedir = normalize(position - eye);

    // direct lighting
    float lightIntensity = clamp(dot(nnormal, normalize(-lightDir)), 0.0, 1.0);
    vec3 lighting = lightIntensity * lightColor;

    // ambient lighting
    lighting += getAmbientLighting(nnormal);
    lighting += ambientLight;

    // shadow
#ifdef SHADOW
    float shadow = sampleShadow();
    lighting = lighting * shadow;
#endif // SHADOW

    outFragColor = color * vec4(lighting, 1.0) * 0.5;
    outFragColor.a = 0.7;

    // reflections
    vec3 rnormal = normalize(nnormal + ((vec3(1.0) - texBase.rgb) * aberration) - aberration / 2);
    vec3 eyeReflected = reflect(eyedir, rnormal);

    float reflectivity = 0.0;
#ifdef REFLECTIONS
    reflectivity = minReflectivity + (maxReflectivity - minReflectivity) * (1.0 - dot(-eyedir, nnormal));

#if !defined(DEFERRED)
    vec3 reflection = texture(skyTexture, eyeReflected).rgb;
    outFragColor.rgb += reflection * reflectivity;
#endif

#endif // REFLECTIONS

    // specular highlight
    float specular = clamp(dot(normalize(-lightDir), eyeReflected), 0.0, 1.0);
    specular = pow(specular, glossyness) * specularity * 3.0;
#ifdef SHADOW
    specular *= shadow;
#endif // SHADOW
    outFragColor.rgb += specular * texBase.r * lightColor;
    outFragColor.a = min(1.0, outFragColor.a);

#if defined(DEFERRED)
    outNormalColor.rgb = rnormal;
    outNormalColor.a = reflectivity;
    outPositionColor.rgb = position;
    outPositionColor.a = gl_FragCoord.z / gl_FragCoord.w;
#else
    // fog
    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogDistance = gl_FragCoord.z / gl_FragCoord.w;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-fogDistance * fogStrength));
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);
#endif

}

