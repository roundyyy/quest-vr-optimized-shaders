Shader "Roundy/Vegetation/LeafsWindAmbientColor" {
    Properties {
        [MainTexture] _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
        
        [Space(10)]
        [Header(Wind Settings)]
        _WindSpeed ("Wind Speed", Range(0, 10)) = 1
        _WindAmplitude ("Wind Amplitude", Range(0, 1)) = 0.1
        
        [Space(10)]
        [Header(Directional Lighting)]
        _TopColor("Top (+Y)", Color) = (1,1,1,1)
        _BottomColor("Bottom (-Y)", Color) = (0.5,0.5,0.5,1)
        _FrontColor("Front (+Z)", Color) = (0.9,0.9,0.9,1)
        _BackColor("Back (-Z)", Color) = (0.5,0.5,0.5,1)
        _RightColor("Right (+X)", Color) = (0.8,0.8,0.8,1)
        _LeftColor("Left (-X)", Color) = (0.6,0.6,0.6,1)
        _AmbientStrength("Ambient Contrast", Range(0, 2)) = 1
        _Saturation("Saturation", Range(0, 2)) = 1
        _BlendFalloff("Blend Falloff", Range(0.1, 2)) = 1.0
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        
        [Space(10)]
        [Header(Render Settings)]
        [Toggle(USE_VIEW_DEPENDENT)] _UseViewDependent ("Use View-Based Ambient", Float) = 0
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
            AlphaToMask On
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma shader_feature USE_VIEW_DEPENDENT
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma target 3.0
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            // Optimized bayer matrix for half precision
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
                half3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                UNITY_FOG_COORDS(3)
                float2 lightmapUV : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                #if USE_VIEW_DEPENDENT
                    half3 viewDir : TEXCOORD6;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _Color;
            half _Cutoff;
            half _Saturation;
            half _WindSpeed;
            half _WindAmplitude;
            half4 _TopColor;
            half4 _BottomColor;
            half4 _FrontColor;
            half4 _BackColor;
            half4 _RightColor;
            half4 _LeftColor;
            half _AmbientStrength;
            half _BlendFalloff;

            // Optimized saturation calculation
            inline half3 AdjustSaturation(half3 color) {
                half grey = dot(color, half3(0.299h, 0.587h, 0.114h));
                return lerp(half3(grey, grey, grey), color, _Saturation);
            }

            // New wind calculation from CutoutLightmappedFakeShadow
            inline half3 calculateWind(half3 vertex, half3 normal, half2 uv)
            {
                half windTime = _Time.y * _WindSpeed;
                half sine = sin(windTime + vertex.x);
                return normal * (sine * _WindAmplitude * uv.y);
            }

            // Optimized blend calculation
            inline half SmoothBlend(half x) {
                x = saturate(x);
                half y = x * x * (3 - 2 * x);
                return y * _BlendFalloff;
            }

            // Moved ambient calculation to vertex shader where possible
            inline half3 GetAmbientContribution(half3 normal, half3 viewDir, half3 weights) {
                #if USE_VIEW_DEPENDENT
                    normal = reflect(-viewDir, normal);
                #endif
                
                half3 absNormal = abs(normal);
                half3 blendWeights = absNormal / max(dot(absNormal, half3(1,1,1)), 0.001h);
                
                // Combine colors based on direction
                half3 colorsX = lerp(_LeftColor.rgb, _RightColor.rgb, step(0, normal.x));
                half3 colorsY = lerp(_BottomColor.rgb, _TopColor.rgb, step(0, normal.y));
                half3 colorsZ = lerp(_BackColor.rgb, _FrontColor.rgb, step(0, normal.z));
                
                return colorsX * weights.x + colorsY * weights.y + colorsZ * weights.z;
            }

            v2f vert(appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // Apply wind using new calculation method
                half3 windOffset = calculateWind(v.vertex.xyz, v.normal, v.uv);
                v.vertex.xyz += windOffset;
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.screenPos = ComputeScreenPos(o.pos);
                
                #if USE_VIEW_DEPENDENT
                    o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
                #endif
                
                #ifdef LIGHTMAP_ON
                    o.lightmapUV = v.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                
                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }
            
            half4 frag(v2f i) : SV_Target {
                // Early texture sample and alpha test
                half4 col = tex2D(_MainTex, i.uv);
                
                if (col.a < _Cutoff) {
                    return 0;
                }
                
                #if defined(LOD_FADE_CROSSFADE)
                    half2 screenPos = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy * 0.5h;
                    uint2 ditherCoord = uint2(fmod(screenPos, 4));
                    half dither = bayerMatrix[ditherCoord.x][ditherCoord.y];
                    half fadeValue = unity_LODFade.x > 0 ? 
                        unity_LODFade.x - dither : 
                        unity_LODFade.x + dither;
                    if (fadeValue < 0) {
                        return 0;
                    }
                #endif

                half3 worldNormal = normalize(i.worldNormal);
                #if USE_VIEW_DEPENDENT
                    half3 viewDir = normalize(i.viewDir);
                #else
                    half3 viewDir = 0;
                #endif

                // Calculate weights once
                half3 absNormal = abs(worldNormal);
                half totalWeight = max(dot(absNormal, half3(1,1,1)), 0.001h);
                half3 weights = absNormal / totalWeight;
                weights = half3(
                    SmoothBlend(weights.x),
                    SmoothBlend(weights.y),
                    SmoothBlend(weights.z)
                );
                weights /= max(dot(weights, half3(1,1,1)), 0.001h);

                half3 ambient = GetAmbientContribution(worldNormal, viewDir, weights);
                
                // Efficient ambient adjustment
                half3 adjustedAmbient = (ambient - 0.5h) * _AmbientStrength + 0.5h;
                
                #ifdef LIGHTMAP_ON
                    half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV);
                    #ifdef DIRLIGHTMAP_COMBINED
                        fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV);
                        half3 bakedDir = bakedDirTex.xyz * 2.0h - 1.0h;
                        half dirMask = max(0, dot(worldNormal, bakedDir));
                        col.rgb *= adjustedAmbient * DecodeLightmap(bakedColorTex) * dirMask * 2.0h;
                    #else
                        col.rgb *= adjustedAmbient * DecodeLightmap(bakedColorTex) * 2.0h;
                    #endif
                #else
                    col.rgb *= adjustedAmbient * 2.0h;
                #endif
                
                col.rgb = AdjustSaturation(col.rgb) * _Color.rgb;
                col.a = 1;
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}