Shader "Roundy/Vegetation/LeafsWindOnly" {
    Properties {
        [MainTexture] _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff ("Alpha cutoff", Range(0.15,0.85)) = 0.5
        _AlphaCoverageStrength ("Alpha Coverage Strength", Range(0.1, 2.0)) = 1.0
        [Toggle(ALPHA_TO_COVERAGE)] _AlphaToCoverage("Alpha To Coverage", Float) = 1
        
        [Space(10)]
        [Header(Wind Settings)]
        _WindSpeed ("Wind Speed", Range(0, 10)) = 1
        _WindAmplitude ("Wind Amplitude", Range(0, 1)) = 0.1
        
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        [Enum(Off,0,Front,1,Back,2)] _CullMode ("Cull Mode", Float) = 0
    }

    SubShader {
        Tags {
            "Queue"="AlphaTest" 
            "RenderType"="TransparentCutout"
            "IgnoreProjector"="True"
        }
        Cull [_CullMode]
        ZWrite On
        
        Pass {
            AlphaToMask [_AlphaToCoverage]
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ ALPHA_TO_COVERAGE
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma target 3.0
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            static const half4x4 bayerMatrix = half4x4(
                0.0h, 0.5h, 0.125h, 0.625h,
                0.75h, 0.25h, 0.875h, 0.375h,
                0.1875h, 0.6875h, 0.0625h, 0.5625h,
                0.9375h, 0.4375h, 0.8125h, 0.3125h
            );

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float2 lightmapUV : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 screenPos : TEXCOORD2;
                float2 lightmapUV : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _Color;
            half _Cutoff;
            half _AlphaCoverageStrength;
            half _WindSpeed;
            half _WindAmplitude;

            inline half3 calculateWind(half3 vertex, half3 normal, half2 uv)
            {
                half windTime = _Time.y * _WindSpeed;
                half sine = sin(windTime + vertex.x);
                return normal * (sine * _WindAmplitude * uv.y);
            }
            v2f vert(appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                half3 windOffset = calculateWind(v.vertex.xyz, v.normal, v.uv);
                v.vertex.xyz += windOffset;
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.pos);
                
                // Initialize lightmapUV to zero by default
                o.lightmapUV = float2(0, 0);
                #ifdef LIGHTMAP_ON
                    o.lightmapUV = v.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                
                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }
            
            half4 frag(v2f i) : SV_Target {
                half4 col = tex2D(_MainTex, i.uv);
                
                #if defined(ALPHA_TO_COVERAGE)
                    half processedAlpha = pow(col.a * _Color.a, _AlphaCoverageStrength);
                    half alpha = (processedAlpha - _Cutoff) / max(fwidth(processedAlpha), 0.0001) + 0.5;
                #else
                    half alpha = col.a * _Color.a;
                    clip(alpha - _Cutoff);
                #endif

                #if defined(LOD_FADE_CROSSFADE)
                    half2 screenPos = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy * 0.5h;
                    uint2 ditherCoord = uint2(fmod(screenPos, 4));
                    half dither = bayerMatrix[ditherCoord.x][ditherCoord.y];
                    half fadeValue = unity_LODFade.x > 0 ? 
                        unity_LODFade.x - dither : 
                        unity_LODFade.x + dither;
                    
                    #if defined(ALPHA_TO_COVERAGE)
                        alpha *= saturate(fadeValue + 1);
                    #endif
                    
                    if (fadeValue < 0) {
                        discard;
                    }
                #endif

                #if defined(ALPHA_TO_COVERAGE)
                    if (alpha < 0) {
                        discard;
                    }
                #endif

                #ifdef LIGHTMAP_ON
                    half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV);
                    col.rgb *= DecodeLightmap(bakedColorTex) * 2.0h;
                #endif

                col.rgb *= _Color.rgb;
                col.a = alpha;
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
