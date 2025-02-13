Shader "Roundy/UnlitLightmapDetailHeight" {
    Properties {
        [Header(Textures)]
        _MainTex ("Texture 1", 2D) = "white" {}
        _DetailTex ("Texture 2", 2D) = "white" {}
        
        [Header(Blending Properties)]
        [Enum(R,0, G,1, B,2, A,3)] _HeightChannel ("Height Channel", Int) = 0
        _BlendFactor ("Base Blend Factor", Range(0,1)) = 0.5
        _HeightBlendDistance ("Height Blend Distance", Range(0.01, 1)) = 0.1
        _HeightBlendStrength ("Height Blend Strength", Range(0.01, 8)) = 1
        
        [Header(Color)]
        _Color ("Color", Color) = (1,1,1,1)
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
                UNITY_FOG_COORDS(2)
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD3;
                #endif
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _DetailTex;
            float4 _DetailTex_ST;
            float _BlendFactor;
            float _HeightBlendDistance;
            float _HeightBlendStrength;
            int _HeightChannel;

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uvMain = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 GetHeightBlend(float height1, float height2, float blendFactor) {
                // Adjust heights based on blend factor
                height1 = lerp(height1, 1 - height1, blendFactor);
                height2 = lerp(height2, 1 - height2, 1 - blendFactor);
                
                float maxH = max(height1, height2);
                float2 heights = float2(height1, height2);
                
                float2 heightBlend = saturate(1 - (maxH - heights) / _HeightBlendDistance);
                heightBlend = pow(heightBlend, _HeightBlendStrength);
                
                // Normalize the blend weights
                float sum = heightBlend.x + heightBlend.y;
                if (sum > 0) {
                    heightBlend /= sum;
                }
                
                return float4(heightBlend.x, heightBlend.y, 0, 0);
            }

            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // Sample textures
                fixed4 tex1 = tex2D(_MainTex, i.uvMain);
                fixed4 tex2 = tex2D(_DetailTex, i.uvDetail);
                
                // Get heights from red channel
                float height1 = tex1[_HeightChannel];
                float height2 = tex2[_HeightChannel];
                
                // Calculate height-based blend weights
                float4 heightBlend = GetHeightBlend(height1, height2, _BlendFactor);
                
                // Blend textures using calculated weights
                fixed4 blendedTex = tex1 * heightBlend.x + tex2 * heightBlend.y;
                fixed4 col = blendedTex * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                
                #ifdef LIGHTMAP_ON
                half3 bakedColorTex = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                col.rgb *= bakedColorTex;
                #endif
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}