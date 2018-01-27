#include "../version.inl"

uniform sampler2D stoneTexture;
uniform samplerCube fogTexture;
uniform float maxFoggyness;
uniform float fogStrength;

uniform vec3 eye;
uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 materialColor;

in vec4 color;
in vec3 normal;
in vec3 position;
in vec2 texWorld;
in vec3 ambientLight;
in vec4 util0;

#include "../ambientlight.inl"

#ifdef SHADOW
#include "../shadow.inl"
#endif

#ifdef NORMAL_MAPPING
uniform sampler2D normalTexture;
in vec3 tangent;
in vec3 bitangent;
#endif // NORMAL_MAPPING

void main()
{
    float distanceToEye = gl_FragCoord.z / gl_FragCoord.w;
    float low = 0.25;
    float high = 1.25;
    float detail = 1.0f - min(1.0, max(0.5, distanceToEye / 40.0));

    vec4 texBase = texture(stoneTexture, texWorld * low);
    texBase = mix(texBase, texture(stoneTexture, texWorld * high), detail);

    vec4 texColor = texBase * color;

#ifdef NORMAL_MAPPING
    mat3 tangentToWorld = mat3(
                              normalize(bitangent),
                              normalize(tangent),
                              normalize(normal)
                          );

    vec3 normalTex = texture(normalTexture, texWorld * low).zyx;
    normalTex = mix(normalTex, texture(normalTexture, texWorld * high).zyx, detail);

    vec3 normalRead = (normalTex - vec3(0.5)) * 2.0;
    vec3 nnormal = normalize(tangentToWorld * normalRead);
#else
    vec3 nnormal = normalize(normal);
#endif
    vec3 eyedir = normalize(position - eye);

//    nnormal = normalize(normal);
//    outFragColor.rgb = nnormal.rgb / 2.0f + vec3(0.5);
//    outFragColor.a = 1.0;
//    return;

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
    vec3 rnormal = normalize(normal + ((vec3(1.0) - texBase.rgb) * 0.25) - 0.125);
    vec3 eyeReflected = reflect(eyedir, rnormal);

    // specular highlight
    float specular = clamp(dot(normalize(-lightDir), eyeReflected), 0.0, 1.0);
    specular = pow(specular, 250) * 1.0;
#ifdef SHADOW
    specular *= shadow;
#endif // SHADOW
#ifdef NUM_INSTANCES
    // with instancing, material color can't be passed as a uniform
    outFragColor.rgb += util0.rgb * util0.a * specular * texBase.a;
#else
    outFragColor.rgb += materialColor.rgb * specular * texBase.a;
#endif

    // material highlight
    float lightness = 1.0f - min(1.0, length(texBase.rgb + 0.15f) * 1.65f);
    // with instancing, material color can't be passed as a uniform
    outFragColor.rgb += util0.rgb * util0.a * 4.0 * pow(lightness, 1);

    vec3 fogColor = texture(fogTexture, eyedir).rgb;

    float fresnel = 1.0f - clamp(dot(-eyedir, nnormal), 0.0, 1.0);
    fresnel = pow(fresnel, 5);
    outFragColor.rgb += fresnel * fogColor * mix(texBase.a, 1.0, 0.5);
    outFragColor.a = 1;

#if defined(DEFERRED)
    outNormalColor.rgb = rnormal;
    outNormalColor.a = 0;
    outPositionColor.rgb = position;
    outPositionColor.a = gl_FragCoord.z / gl_FragCoord.w;
#else
    // fog
    float fogAmount = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength));
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);
#endif

}
