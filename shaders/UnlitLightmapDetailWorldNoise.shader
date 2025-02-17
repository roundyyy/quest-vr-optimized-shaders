Shader "Roundy/UnlitLightmapDetailNoiseWorld" {
    Properties {
        _MainTex ("Texture 1", 2D) = "white" {}
        _MainTint ("Texture 1 Tint", Color) = (1,1,1,1)
        _DetailTex ("Texture 2", 2D) = "white" {}
        _DetailTint ("Texture 2 Tint", Color) = (1,1,1,1)
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _NoiseScale ("Noise World Scale", Range(0.1, 10.0)) = 1.0
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
                float3 normal : NORMAL;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float2 uvMain : TEXCOORD0;
                float2 uvDetail : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
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
            float _NoiseScale;
            float _NoiseThreshold;
            float _BlendZoneWidth;

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _MainTint)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _DetailTint)
            UNITY_INSTANCING_BUFFER_END(Props)

            // Hash function for 3D noise
            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            // 3D noise function
            float noise3D(float3 x) {
                float3 i = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);

                return lerp(
                    lerp(
                        lerp(hash(i + float3(0, 0, 0)), hash(i + float3(1, 0, 0)), f.x),
                        lerp(hash(i + float3(0, 1, 0)), hash(i + float3(1, 1, 0)), f.x),
                        f.y),
                    lerp(
                        lerp(hash(i + float3(0, 0, 1)), hash(i + float3(1, 0, 1)), f.x),
                        lerp(hash(i + float3(0, 1, 1)), hash(i + float3(1, 1, 1)), f.x),
                        f.y),
                    f.z);
            }

            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                float4 worldPosition = mul(unity_ObjectToWorld, v.vertex);
                o.worldPos = worldPosition.xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                o.uvMain = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);
                
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

                // Sample 3D noise using world position
                float3 worldNoisePos = i.worldPos * _NoiseScale;
                fixed noiseValue = noise3D(worldNoisePos);

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