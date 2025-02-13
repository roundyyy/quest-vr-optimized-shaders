Shader "Roundy/UnlitLightmapTopProjection" {
    Properties {
        _MainTex ("Main Texture", 2D) = "white" {}
        _TopTex ("Top Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _MaxAngle ("Max Angle", Range(0, 90)) = 45
        _BlendStrength ("Blend Strength", Range(0, 1)) = 0.5
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
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
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
            sampler2D _TopTex;
            float4 _MainTex_ST;
            float4 _TopTex_ST;
            float _MaxAngle;
            float _BlendStrength;
           
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)
   
            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
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
                
                // Calculate top projection UV
                float2 topUV = i.worldPos.xz * _TopTex_ST.xy + _TopTex_ST.zw;
                
                // Calculate blend factor based on normal and max angle
                float upDot = dot(normalize(i.worldNormal), float3(0, 1, 0));
                float angleBlend = saturate((upDot - cos(radians(_MaxAngle))) / (1 - cos(radians(_MaxAngle))));
                angleBlend = pow(angleBlend, 1 / _BlendStrength); // Adjust blend curve
                
                // Sample textures
                fixed4 mainTex = tex2D(_MainTex, i.uv);
                fixed4 topTex = tex2D(_TopTex, topUV);
                fixed4 col = lerp(mainTex, topTex, angleBlend) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
               
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