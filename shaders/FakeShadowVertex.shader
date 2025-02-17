Shader "Roundy/FakeShadowVertex" {
    Properties {
        _MainTex ("Albedo", 2D) = "white" {}
        _Color0 ("Color 0", Color) = (0.4716981,0.4716981,0.4716981,0)
        _LightDirection ("Light Direction", Vector) = (30,30,30,0)
        _ShadowStrength ("Shadow Strength", Float) = 0.01
        _Max ("Max", Float) = 0.6
        _Min ("Min", Float) = -0.05
    }
    SubShader {
        Tags {"RenderType"="Opaque" "Queue"="Geometry+0"}
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
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 vertexColor : COLOR;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD2;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color0;
            float3 _LightDirection;
            float _ShadowStrength;
            float _Max;
            float _Min;

            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // Calculate fake shadow
                float3 normalizedLightDir = normalize(_LightDirection);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 normalizedWorldNormal = normalize(worldNormal);
                float NdotL = dot(normalizedLightDir, normalizedWorldNormal);
                float shadowFactor = smoothstep(_Min, _Max, NdotL);
                o.vertexColor = lerp(v.color, float4(_Color0.rgb, 0.0), shadowFactor + _ShadowStrength);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // Sample main texture
                fixed4 col = tex2D(_MainTex, i.uv);
                col *= i.vertexColor;

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
