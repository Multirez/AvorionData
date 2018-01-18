
#include "version.inl"

uniform sampler2D diffuseTexture;

in vec4 color;
in vec2 texCoord;



void main()
{
	vec4 texColor = texture(diffuseTexture, texCoord);
	texColor.a *= 1.5f;

	vec4 offsetColor;
	vec4 outline = vec4(0);

	float offset = 0.0075;

	offsetColor = texture(diffuseTexture, texCoord + vec2(offset, offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(-offset, offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(offset, -offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(-offset, -offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(0.0, offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(0.0, -offset));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(offset, 0.0));
	outline = max(outline, offsetColor);

	offsetColor = texture(diffuseTexture, texCoord + vec2(-offset, 0.0));
	outline = max(outline, offsetColor);

	outFragColor = mix(outline * vec4(0, 0, 0, 1), color * texColor, min(1.0, texColor.a * 4.0f));
}
