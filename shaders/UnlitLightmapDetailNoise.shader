Shader "Roundy/UnlitLightmapDetailNoise" {
    Properties {
        _MainTex ("Texture 1", 2D) = "white" {}
        _MainTint ("Texture 1 Tint", Color) = (1,1,1,1)
        _DetailTex ("Texture 2", 2D) = "white" {}
        _DetailTint ("Texture 2 Tint", Color) = (1,1,1,1)
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _NoiseThreshold ("Noise Threshold Adjustment", Range(-0.5, 0.5)) = 0
        _BlendZoneWidth ("Blend Zone Width", Range(0, 0.5)) = 0
    }
    SubShader {
        Tags {"RenderType"="Opaque"}
        LOD 100
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_local _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float2 uvMain : TEXCOORD0;
                float2 uvDetail : TEXCOORD1;
                float2 uvNoise : TEXCOORD2;
                UNITY_FOG_COORDS(3)
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD4;
                #endif
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _DetailTex;
            float4 _DetailTex_ST;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float _NoiseThreshold;
            float _BlendZoneWidth;

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _MainTint)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _DetailTint)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                o.uvMain = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);
                o.uvNoise = TRANSFORM_TEX(v.uv, _NoiseTex);
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            inline fixed smoothTransition(fixed edge0, fixed edge1, fixed x) {
                x = saturate((x - edge0) / (edge1 - edge0));
                return x * x * (3 - 2 * x);
            }

            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                fixed noiseValue = tex2D(_NoiseTex, i.uvNoise).r;
                fixed threshold = 0.5 + _NoiseThreshold;
                
                fixed lowerBound = threshold - _BlendZoneWidth;
                fixed upperBound = threshold + _BlendZoneWidth;

                // Sample textures and apply their respective tints
                fixed4 mainTint = UNITY_ACCESS_INSTANCED_PROP(Props, _MainTint);
                fixed4 detailTint = UNITY_ACCESS_INSTANCED_PROP(Props, _DetailTint);
                
                fixed4 tex1 = tex2D(_MainTex, i.uvMain) * mainTint;
                fixed4 tex2 = tex2D(_DetailTex, i.uvDetail) * detailTint;
                
                fixed blendFactor = _BlendZoneWidth > 0 ? 
                    smoothTransition(lowerBound, upperBound, noiseValue) : 
                    step(threshold, noiseValue);
                
                fixed4 col = lerp(tex1, tex2, blendFactor);

                #ifdef LIGHTMAP_ON
                col.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                #endif

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}