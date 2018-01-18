
#include "version.inl"

uniform sampler2D diffuseTexture0;
uniform sampler2D diffuseTexture1;
uniform sampler2D diffuseTexture2;
uniform sampler2D diffuseTexture3;
uniform sampler2D diffuseTexture4;
uniform sampler2D diffuseTexture5;
uniform sampler2D diffuseTexture6;
uniform sampler2D diffuseTexture7;
uniform sampler2D diffuseTexture8;
uniform sampler2D diffuseTexture9;

uniform sampler2D positionsTexture;

uniform vec2 viewport = vec2(1920, 1080);

in vec4 color;
in vec2 texCoord;
in float size;

void main()
{
	if(color.a == 0.0) discard;

	vec4 texColor;
	int sizet = int(size);

	if(size > 8.9) texColor = texture(diffuseTexture9, texCoord);
	else if(size > 7.9) texColor = texture(diffuseTexture8, texCoord);
	else if(size > 6.9) texColor = texture(diffuseTexture7, texCoord);
	else if(size > 5.9) texColor = texture(diffuseTexture6, texCoord);
	else if(size > 4.9) texColor = texture(diffuseTexture5, texCoord);
	else if(size > 3.9) texColor = texture(diffuseTexture4, texCoord);
	else if(size > 2.9) texColor = texture(diffuseTexture3, texCoord);
	else if(size > 1.9) texColor = texture(diffuseTexture2, texCoord);
	else if(size > 0.9) texColor = texture(diffuseTexture1, texCoord);
	else texColor = texture(diffuseTexture0, texCoord);

    vec3 ncolor = texColor.rgb * color.rgb;

    if (ncolor.rgb == vec3(0)) discard;

    float depthAlpha = 1.2;

#if defined(VOLUMETRIC)
    vec2 tex = vec2(gl_FragCoord.x, gl_FragCoord.y) / viewport;
    float depth = texture(positionsTexture, tex).w;

    if (depth != 0)
    {
        float selfDepth = gl_FragCoord.z / gl_FragCoord.w;
        depthAlpha = clamp(abs(selfDepth - depth) * 0.1, 0, 1.2);
    }
#endif

	ncolor += pow(texColor.rgb * 2.0f, vec3(16.0, 16.0, 16.0)) * 0.02;
    outFragColor =  vec4(ncolor.rgb, texColor.r * depthAlpha * color.a);
    //outFragColor = vec4(1, 0, 0, 1);
}
