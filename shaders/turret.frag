
#include "version.inl"

uniform sampler2D platingTexture;
uniform samplerCube skyTexture;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 eye;

in vec4 color;
in vec3 position;
in vec3 normal;
in vec2 texCoord;
in vec3 ambientLight;

#include "ambientlight.inl"

void main()
{
	vec4 texBase = texture(platingTexture, texCoord);
	vec4 texColor = texBase * color;

	vec3 nnormal = normalize(normal);
	vec3 eyedir = normalize(position - eye);

	// direct lighting
	float lightIntensity = clamp(dot(nnormal, normalize(-lightDir)), 0.0, 1.0);
	vec3 lighting = lightIntensity * lightColor;

	// ambient lighting
	lighting += getAmbientLighting(nnormal);
	lighting += ambientLight;

	outFragColor.rgb = texColor.rgb * lighting;

	// reflections
    vec3 rnormal = normalize(normal + ((vec3(1.0) - texColor.rgb) * 0.25) - 0.125);
    vec3 eyeReflected = reflect(eyedir, rnormal);

	outFragColor.rgb += texture(skyTexture, eyeReflected).rgb * 0.15;

	// specular highlight
	float specular = clamp(dot(normalize(-lightDir), eyeReflected), 0.0, 1.0);
	specular = pow(specular, 250) * 2.0;

	outFragColor.rgb += specular * texBase.r * lightColor;
	outFragColor.a = 1;

#if defined(DEFERRED)
    outNormalColor.rgb = rnormal;
    outNormalColor.a = 0.1;
    outPositionColor.rgb = position;
    outPositionColor.a = gl_FragCoord.z / gl_FragCoord.w;
#endif

}
