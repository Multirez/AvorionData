#include "../version.inl"

uniform sampler2D platingTexture;
uniform samplerCube fogTexture;
uniform float maxFoggyness;
uniform float fogStrength;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;
uniform vec3 innerEngineColor;

uniform float glossyness;
uniform float specularity;

in vec4 color;
in vec3 position;
in vec3 normal;
in vec4 util0;
in vec2 texCoord;
in vec2 texWorld;
in vec3 ambientLight;

#ifdef LOW
in float sideIndex;
#endif // LOW
#ifdef HIGH
flat in uint sideIndex;
#endif // HIGH

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

#ifdef OVERLAY
uniform sampler2D overlayTexture;
#endif // OVERLAY

#ifdef GLOW_TEXTURE
uniform sampler2D glowTexture;
#endif // GLOW_TEXTURE


void main()
{
    vec4 texBase = texture(platingTexture, texWorld);
    vec4 texColor = texBase * color;

#ifdef OVERLAY
    vec4 texOverlay = texture(overlayTexture, texWorld);

    texColor.rgb = mix(texColor.rgb, texOverlay.rgb, texOverlay.a);
    texBase.rgb = texColor.rgb;
#endif // OVERLAY

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

    // shadow
#ifdef SHADOW
    float shadow = sampleShadow();
    lighting = lighting * shadow;
#endif // SHADOW

    // ambient lighting
    lighting += getAmbientLighting(nnormal);
    lighting += ambientLight;

    outFragColor.rgb = texColor.rgb * lighting;

    // reflections
    vec3 rnormal = normalize(nnormal + ((vec3(1.0) - texBase.rgb) * aberration) - aberration / 2);
    vec3 eyeReflected = reflect(eyedir, rnormal);

    float reflectivity = 0.0;
#ifdef REFLECTIONS
    reflectivity = minReflectivity + (maxReflectivity - minReflectivity) * (1.0 - dot(-eyedir, nnormal));

#ifdef OVERLAY
    reflectivity += texOverlay.a * 0.3;
#endif // OVERLAY

#if !defined(DEFERRED)
    vec3 reflection = texture(skyTexture, eyeReflected).rgb;
    outFragColor.rgb += reflection * reflectivity;
#endif

#endif // REFLECTIONS

    // specular highlight
    float specular = clamp(dot(normalize(-lightDir), eyeReflected), 0.0, 1.0);
#ifdef OVERLAY
    specular = pow(specular, (glossyness + texOverlay.a * 1000.0)) * (specularity + texOverlay.a * 2.0);
#else
    specular = pow(specular, glossyness) * specularity;
#endif
#ifdef SHADOW
    specular *= shadow;
#endif // SHADOW
    outFragColor.rgb += specular * texBase.r * lightColor;

#ifdef GLOW_TEXTURE
    // glow
    vec4 glow = texture(glowTexture, texWorld);
    outFragColor.rgb = mix(outFragColor.rgb, glow.rgb * 2.0f, glow.a);
#endif // GLOW

#ifdef LOW
    if (sideIndex > 3.9 && sideIndex < 4.1)
#endif // LOW
#ifdef HIGH
        if (sideIndex == 4u)
#endif // HIGH
        {
            vec2 quad = 1.0 - (abs(texCoord.xy) - vec2(0.7, 0.7)) / 0.2;
            quad = min(vec2(1.0f), max(vec2(0.0f), quad));
            float outer = quad.x * quad.y;

            if (outer > 0.2)
            {
                quad = 1.0 - (abs(texCoord.xy * 1.5) - vec2(0.7, 0.7)) / 0.3;
                quad = min(vec2(1.0f), max(vec2(0.0f), quad));
                float inner = quad.x * quad.y;

                vec3 engineColor = outer * util0.rgb;
                engineColor += inner * innerEngineColor;

                outFragColor.rgb = mix(outFragColor.rgb, engineColor, outer);

#ifdef REFLECTIONS
                reflectivity = mix(reflectivity, 0, outer);
#endif
            }
        }

    outFragColor.a = 1;

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
