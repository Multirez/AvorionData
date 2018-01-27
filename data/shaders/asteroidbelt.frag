#include "version.inl"

uniform sampler2D surfaceTexture;
uniform samplerCube ambientTexture;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;
uniform vec3 ambientColor;
uniform vec3 planetPosition;
uniform float planetRadius;
uniform float phase;

in vec3 position;
in vec3 normal;
in vec2 texCoord;

void main()
{
    if (phase >= 1.0)
    {
        if (distance(planetPosition, eye) > distance(position, eye)) discard;
    }
    else
    {
        if (distance(planetPosition, eye) <= distance(position, eye)) discard;
    }

    vec3 x1 = planetPosition;
    vec3 x2 = planetPosition + lightDir;
    vec3 x0 = position;

    vec4 textureColor = texture(surfaceTexture, texCoord);
    vec3 d = abs(cross(x2 - x1, x1 - x0)) / length(x2 - x1);

    float shadow = 1.0;
    float dist = length(d);

    shadow = dist / planetRadius;
    shadow = 1.0 - clamp(1.0 - (shadow - 0.95) / 0.05, 0.0, 1.0);
    shadow = max(0.1, shadow);

    vec3 lightOrigin = planetPosition - lightDir * 1000.0;
    if(length(lightOrigin - x0) < length(lightOrigin - planetPosition))
    {
        shadow = 1.0;
    }

#ifdef AMBIENT
    shadow = 1.0;
#endif

    vec3 eyedir = normalize(position - eye);
    vec3 nnormal = normalize(normal);
    vec3 eyeReflected = reflect(eyedir, nnormal);

    float specular = clamp(dot(normalize(-lightDir), eyeReflected), 0.0, 1.0);
    specular = pow(specular, 100.0) * 1.5;

    vec3 ambient = ambientColor * 0.1;
    vec3 ambientLight = mix(ambientColor, vec3(1, 1, 1), 0.5) * shadow;

    vec3 specularColor = vec3(specular) * lightColor * shadow;
    vec3 diffuse = textureColor.rgb * lightColor * shadow;

    outFragColor = vec4(ambient + diffuse * ambientLight + specularColor, textureColor.a);
}
