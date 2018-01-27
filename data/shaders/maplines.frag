#include "version.inl"

in vec4 color;
in vec2 texCoord;

void main()
{
    float base = 1.0 - (abs(texCoord.y - 0.5) / 0.5);

    float intensity = pow(base, 2.5) * 0.4;
    intensity += pow(base + 0.025, 10);
    intensity *= 0.6;


//	outFragColor = vec4(texCoord.x, texCoord.y, 0.0, 1.0) * vec4(1, 1, 1, 1);

    outFragColor = vec4(intensity, intensity, intensity, 1) * color;

}
