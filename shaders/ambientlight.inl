uniform samplerCube ambientTexture;
uniform float ambient;

vec3 getAmbientLighting(vec3 normal, vec3 dir)
{
    vec3 color = texture(ambientTexture, -dir).rgb; // darken a little, not all the light shall be used as a light source

    float intensity = clamp(dot(normal, -dir), 0.0, 1.0);

    return intensity * color;
}

vec3 getAmbientLighting(vec3 normal)
{
    vec3 result = vec3(0, 0, 0);

    result += getAmbientLighting(normal, vec3(1, 0, 0));
    result += getAmbientLighting(normal, vec3(-1, 0, 0));
    result += getAmbientLighting(normal, vec3(0, 1, 0));
    result += getAmbientLighting(normal, vec3(0, -1, 0));
    result += getAmbientLighting(normal, vec3(0, 0, 1));
    result += getAmbientLighting(normal, vec3(0, 0, -1));

    result *= 1.8f;

    float len = result.r * 0.21 + result.g * 0.71 + result.b * 0.08;

    // pseudo-desaturate
    result = mix(vec3(len, len, len), result, 0.6);

    return result + ambient;
}
