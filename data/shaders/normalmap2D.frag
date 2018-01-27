#include "version.inl"

uniform sampler2D heightTexture;
uniform vec2 textureResolution;
uniform vec3 textureDimensions;

in vec2 texCoord;

void main()
{
	float nx = texture(heightTexture, texCoord - vec2(1.0 / textureResolution.x, 0)).r * textureDimensions.z;
	float px = texture(heightTexture, texCoord + vec2(1.0 / textureResolution.x, 0)).r * textureDimensions.z;

	float ny = texture(heightTexture, texCoord - vec2(0.0, 1.0 / textureResolution.y)).r * textureDimensions.z;
	float py = texture(heightTexture, texCoord + vec2(0.0, 1.0 / textureResolution.y)).r * textureDimensions.z;

	vec3 left = vec3(-1.0 / textureResolution.x * textureDimensions.x, 0, nx);
	vec3 right = vec3(1.0 / textureResolution.x * textureDimensions.x, 0, px);
	vec3 top = vec3(0, -1.0 / textureResolution.y * textureDimensions.y, ny);
	vec3 bottom = vec3(0, 1.0 / textureResolution.y * textureDimensions.y, py);

	vec3 vx = right - left;
	vec3 vy = bottom - top;

	vec3 normal = normalize(cross(vx, vy));
	normal = normal * 0.5f + 0.5f;

	outFragColor = vec4(normal, 1.0f);
}

