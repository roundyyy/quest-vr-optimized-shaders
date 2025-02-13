Shader "Roundy/UnlitLightmapDetail" {
    Properties {
        _MainTex ("Texture 1", 2D) = "white" {}
        _DetailTex ("Texture 2", 2D) = "white" {}
        _BlendFactor ("Blend Factor", Range(0,1)) = 0.5
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

            // --- Changed: store separate UV for main and detail ---
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

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);

                // --- Changed: compute main and detail UVs separately ---
                o.uvMain   = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);

                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // Sample both textures with their independent UVs
                fixed4 tex1 = tex2D(_MainTex,   i.uvMain);
                fixed4 tex2 = tex2D(_DetailTex, i.uvDetail);

                // Blend textures using the blend factor
                fixed4 blendedTex = lerp(tex1, tex2, _BlendFactor);
                fixed4 col = blendedTex * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);

                #ifdef LIGHTMAP_ON
                // Sample the lightmap
                half3 bakedColorTex = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                col.rgb *= bakedColorTex;
                #endif

                // Apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
    }
}
