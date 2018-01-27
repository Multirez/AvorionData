#include "../version.inl"

in vec4 color;
in vec3 position;
in vec3 normal;

void main()
{
	outFragColor.rgb = color.rgb;
	outFragColor.a = 1.0;

#if defined(DEFERRED)
    outNormalColor = vec4(normal, 0);
    outPositionColor = vec4(position, gl_FragCoord.z / gl_FragCoord.w);
#endif

}


