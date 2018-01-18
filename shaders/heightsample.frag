#include "version.inl"

uniform sampler2D heightTexture;

uniform float sampleHeight;
uniform float sampleWidth;

uniform vec4 baseColor;
uniform vec4 color;

in vec2 texCoord;

void main()
{
    outFragColor = vec4(0); // to get rid of some pesky warnings

    float height = texture(heightTexture, texCoord * 0.2 + sampleHeight * 0.1f).x;
    float dist = abs(height - sampleHeight);

    if (dist <= 0.05)
    {
        float factor = dist / 0.05;

        outFragColor = mix(color * 2.0, baseColor, factor);
    }
    else if (height < sampleHeight)
    {
        discard;
    }
    else
    {
        outFragColor = baseColor;
    }

    outFragColor.rgb *= mix(0.0, 1.0, clamp(sampleHeight / 0.25, 0.0, 1.0));
}


