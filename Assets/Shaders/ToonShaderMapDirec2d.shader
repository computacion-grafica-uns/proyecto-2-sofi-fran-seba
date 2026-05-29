Shader "Custom/ToonShaderMapeoDirec2d"
{
    Properties
    {
        _MaterialColor ("Color de Tinte", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo 2D)", 2D) = "white" {}
        
        _Glossiness ("Tamaño del Brillo Toon", Range(0.01, 1.0)) = 0.3
        
        // Parámetro para controlar el ancho de la línea negra exterior
        _OutlineThickness ("Grosor del Borde Negro", Range(0.0, 0.5)) = 0.25

        //======================== LUCES =============================
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        _SpotLightPosition ("Spot Light Position", Vector) = (0, 3, 0, 1)
        _SpotLightDirection ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (0, 0, 1, 1)
        _Apertura ("Apertura (Angulo)", Range(0.0, 90.0)) = 30.0
        _SpotRange ("Spot Range", Float) = 10.0
        //============================================================
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag 
            #include "UnityCG.cginc"

            float4 _MaterialColor;
            sampler2D _MainTex; 
            float4 _MainTex_ST;
            
            float _Glossiness;
            float _OutlineThickness;

            // Variables de Luces
            float4 _DirLightDirection;
            float4 _DirLightColor;
            
            float4 _PointLightPosition;
            float4 _PointLightColor;
            float _LightRange;
            
            float4 _SpotLightPosition;
            float4 _SpotLightDirection;
            float4 _SpotLightColor;
            float _Apertura;
            float _SpotRange;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL; 
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 normalWorld : TEXCOORD0; 
                float2 uv : TEXCOORD3;
                float3 worldPos : TEXCOORD1; 
            };

            v2f vert (appdata v) { 
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex); 
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o; 
            }

            // --- FUNCIÓN REUTILIZABLE TOON ---
            float3 ComputeToon(float3 N, float3 L, float3 V, float3 lightColor, float3 albedoColor, float glossiness)
            {
                // 1. DIFUSA ESTILO TOON (Escalones duros)
                float NdotL = dot(N, L);
                float toonLambert = 0.2; 

                if (NdotL > 0.6) {
                    toonLambert = 1.0;
                } else if (NdotL > 0.2) { 
                    toonLambert = 0.6;
                }

                // 2. ESPECULAR ESTILO TOON (Brillo seco)
                float3 R = reflect(-L, N); 
                float RdotV = max(0.0, dot(R, V)); 
                
                float spec = pow(RdotV, 32.0); 
                float toonSpecular = 0.0;
                if (spec > (1.0 - glossiness)) { 
                    toonSpecular = 1.0;
                }

                // Composición para esta fuente de luz individual
                float3 colorIluminado = (albedoColor * toonLambert) + (toonSpecular * float3(1, 1, 1)); 
                
                // Multiplicamos por la intensidad y color de la luz actual
                return colorIluminado * lightColor;
            }

            fixed4 frag (v2f i) : SV_Target { 
                // Vectores base en World Space
                float3 normal = normalize(i.normalWorld);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // --- DETECCIÓN DEL BORDE EXTERIOR (Independiente de las luces) --- 
                float NdotV = max(0.0, dot(normal, viewDir));
                float outlineMask = 1.0; 
                if (NdotV < _OutlineThickness) { 
                    outlineMask = 0.0;
                }

                // --- LEER TEXTURA 2D --- [cite: 49]
                float3 texColor = tex2D(_MainTex, i.uv).rgb;
                float3 albedo = texColor * _MaterialColor.rgb; 

                // 1) LUZ DIRECCIONAL
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeToon(normal, L1, viewDir, _DirLightColor.rgb, albedo, _Glossiness);

                // 2) LUZ PUNTUAL
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeToon(normal, L2, viewDir, lightPointColor, albedo, _Glossiness);

                // 3) LUZ SPOT (REFLECTOR)
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                float3 lightSpotResult = float3(0, 0, 0);
                if (cosCurrentAngle > cosAperture)
                {
                    // Se agrega atenuación basada en _SpotRange y un corte limpio toon para el foco
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    
                    // Suavizado sutil para que los escalones de la luz dentro del cono no rompan el estilo toon
                    float spotIntensity = smoothstep(cosAperture, cosAperture + 0.02, cosCurrentAngle);
                    
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot * spotIntensity;
                    lightSpotResult = ComputeToon(normal, L3, viewDir, lightSpotColor, albedo, _Glossiness);
                }

                // --- SUMA TOTAL Y MÁSCARA DE CONTORNO ---
                fixed4 fragColor = fixed4(0, 0, 0, 1);
                
                // Sumamos los aportes de iluminación acumulados
                float3 iluminacionTotal = lightDirResult + lightPointResult + lightSpotResult;
                
                // Aplicamos el outline al resultado final 
                fragColor.rgb = iluminacionTotal * outlineMask;

                return fragColor;
            }
            ENDCG
        }
    }
}