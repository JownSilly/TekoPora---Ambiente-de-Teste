Shader "Hidden/Hybrid_Kuwahara_Shader"
{
    Properties
    {
        _MainTex("Render Texture", 2D) = "white" {}
        _KernelSize("KernelSize (N)", Int) = 3
        _Sharpness("Sharpness", Float) = 8
        _Overlap("Overlap", Float) = 0
        _Scaling("Scaling", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Overlay" }

        Pass
        {
            Name "FullscreenPass"
            Tags { "LightMode" = "UniversalFullscreen" }

            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Declarar a textura da Render Texture
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            int _KernelSize;
            float _Overlap;
            float _Sharpness;
            float _Scaling;

            #define PI 3.14159265358979323846f

            float4 m[4];
            float3 s[4];

            float2 _MainTex_TexelSize;

            float gaussian(float x)
            {
                float sigmaSqu = 1;
                return (1 / sqrt(2 * PI * sigmaSqu)) * exp(-(x * x) / (2 * sigmaSqu));
            }

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            float4 frag(v2f input) : SV_Target
            {
                float2 uv = input.uv;

                int radius = _KernelSize / 2;
                float overlap = (radius * 0.5f) * _Overlap;
                float halfOverlap = overlap / 2.0f;

                float2 d = _MainTex_TexelSize.xy;

                // Sample da Render Texture
                float3 Sx = (
                    1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-d.x, -d.y)).rgb +
                    2.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-d.x, 0.0)).rgb +
                    1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-d.x, d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(d.x, -d.y)).rgb +
                    -2.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(d.x, 0.0)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(d.x, d.y)).rgb
                ) / 4.0f;

                float3 Sy = (
                    1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-d.x, -d.y)).rgb +
                    2.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0.0, -d.y)).rgb +
                    1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(d.x, -d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-d.x, d.y)).rgb +
                    -2.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0.0, d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(d.x, d.y)).rgb
                ) / 4.0f;

                float3 greyscaleWeights = float3(0.2126, 0.7152, 0.0722);
                float gradientX = dot(Sx, greyscaleWeights);
                float gradientY = dot(Sy, greyscaleWeights);

                float lineArt = abs(max(gradientX, gradientY));

                int2 offs[4] = { int2(-radius + overlap, -radius + overlap), int2(-radius + overlap, 0), int2(0, -radius + overlap), int2(0, 0) };

                float angle = atan2(gradientY, gradientX);

                float sinPhi = sin(angle);
                float cosPhi = cos(angle);

                for (int k = 0; k < 4; ++k)
                {
                    m[k] = float4(0,0,0,0);
                    s[k] = float3(0,0,0);
                }

                for (int x = 0; x < radius; ++x)
                {
                    for (int y = 0; y < radius; ++y)
                    {
                        for (int k = 0; k < 4; ++k)
                        {
                            float2 v = float2(x, y);
                            v += float2(offs[k]) - float2(halfOverlap, halfOverlap);
                            float2 offset = v * _MainTex_TexelSize.xy;
                            offset = float2(
                                offset.x * cosPhi - offset.y * sinPhi,
                                offset.x * sinPhi + offset.y * cosPhi
                            );
                            float3 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offset).rgb;
                            float w = gaussian(length(v) / 5.0f);
                            m[k] += float4(tex * w, w);
                            s[k] += tex * tex * w;
                        }
                    }
                }

                float4 result = float4(0, 0, 0, 0);
                for (int k = 0; k < 4; ++k)
                {
                    m[k].rgb /= m[k].w;
                    s[k] = abs((s[k] / m[k].w) - (m[k].rgb * m[k].rgb));
                    float sigma2 = s[k].r + s[k].g + s[k].b;
                    float w = 1.0f / (1.0f + pow(10000.0f * sigma2 * _Sharpness, 0.5f * _Sharpness));
                    result += float4(m[k].rgb * w, w);
                }

                result.rgb /= result.w;
                float3 final = lerp(result.rgb, lerp(float3(lineArt), lineArt * result.rgb, 0.85f) * 0.5f + result.rgb, _Scaling);
                return float4(final, 1.0f);
            }
            ENDHLSL

            // Configurações de renderização
            ZWrite Off
            ZTest Always
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha
        }
    }
}
