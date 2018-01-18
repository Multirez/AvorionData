#include "version.inl"

uniform sampler2D diffuseTexture;

uniform vec3 fogColor;
uniform float amplification;

in vec2 texCoord;

void main()
{
	vec4 texColor = texture(diffuseTexture, vec2(texCoord.x, 1.0 - texCoord.y));

	float grey = (texColor.r + texColor.g + texColor.b) * 1.0 / 3.0;

    outFragColor = vec4((fogColor.rgb + (grey + pow(grey + 0.75, 15)) * 1.5) * 0.55, clamp(grey * amplification, 0, 1));
}
