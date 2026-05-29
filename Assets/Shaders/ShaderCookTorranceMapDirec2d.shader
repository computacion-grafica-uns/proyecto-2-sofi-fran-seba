Shader "Custom/ShaderCookTorranceMapeo2D"
{
    Properties
    {
        _MaterialColor ("Color de Tinte", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo 2D)", 2D) = "white" {}
        
        _F0 ("Reflectancia Base (Fresnel F0)", Range(0.0, 1.0)) = 0.04
        _Roughness ("Rugosidad (Alpha)", Range(0.01, 1.0)) = 0.5
        

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
            
            float _F0;
            float _Roughness;

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
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD3;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            // --- FUNCIÓN REUTILIZABLE DE COOK-TORRANCE ---
            float3 ComputeCookTorrance(float3 N, float3 L, float3 V, float3 lightColor, float roughness, float F0, float3 albedoColor)
            {
                float3 H = normalize(L + V);
                
                float dotNL = dot(N, L);
                float NdotL = max(0.0001, dotNL);
                float NdotV = max(0.0001, dot(N, V));
                float NdotH = max(0.0, dot(N, H));
                float HdotV = max(0.0, dot(H, V));

                // Ecuación D (GGX)
                float alpha2 = roughness * roughness;
                float denomD = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
                float D = alpha2 / (3.14159265 * denomD * denomD);

                // Ecuación F (Schlick)
                float F = F0 + (1.0 - F0) * pow(1.0 - HdotV, 5.0);

                // Ecuación G (Schlick-GGX / Smith)
                float k = roughness / 2.0;
                float G1_L = NdotL / (NdotL * (1.0 - k) + k);
                float G1_V = NdotV / (NdotV * (1.0 - k) + k);
                float G = G1_L * G1_V;

                // Brillo Especular
                float specularTerm = (D * F * G) / (4.0 * NdotL * NdotV);
                float3 specular = specularTerm * float3(1, 1, 1);

                // Componente Difusa
                float realLambert = max(0.0, dotNL);
                float3 diffuse = realLambert * albedoColor;

                // Filtro del terminador suave para evitar artefactos en los bordes oscuros
                float terminadorMask = smoothstep(0.0, 0.05, dotNL);
                specular *= terminadorMask;

                // Multiplicamos el resultado total por el color/intensidad de esta luz en particular
                return (diffuse + specular) * lightColor;
            }

            fixed4 frag (v2f i) : SV_Target {
                // Vectores base del modelo de iluminación en World Space
                float3 normal = normalize(i.normalWorld);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Color base del objeto (Albedo)
                float3 texColor = tex2D(_MainTex, i.uv).rgb;
                float3 albedoColor = texColor * _MaterialColor.rgb;

                // 1) LUZ DIRECCIONAL
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirecResult = ComputeCookTorrance(normal, L1, viewDir, _DirLightColor.rgb, _Roughness, _F0, albedoColor);

                // 2) LUZ PUNTUAL
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                
                // Atenuación lineal por distancia basada en tu propuesta
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeCookTorrance(normal, L2, viewDir, lightPointColor, _Roughness, _F0, albedoColor);

                // 3) LUZ SPOT (REFLECTOR)
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                float3 lightSpotResult = float3(0, 0, 0);
                // Si está dentro del cono de apertura, calculamos su aporte
                if (cosCurrentAngle > cosAperture) {
                    // Combinamos la atenuación por distancia (usando _SpotRange) y por cono de apertura
                    float attenSpotDistance = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    
                    // Suavizado del borde del foco (opcional, pero mejora mucho visualmente)
                    float spotIntensity = smoothstep(cosAperture, cosAperture + 0.05, cosCurrentAngle);
                    
                    float3 finalSpotColor = _SpotLightColor.rgb * attenSpotDistance * spotIntensity;
                    lightSpotResult = ComputeCookTorrance(normal, L3, viewDir, finalSpotColor, _Roughness, _F0, albedoColor);
                }

                // --- SUMA TOTAL DE TODAS LAS LUCES ---
                fixed4 fragColor = fixed4(0, 0, 0, 1);
                fragColor.rgb = lightDirecResult + lightPointResult + lightSpotResult;

                return fragColor;
            }
            ENDCG
        }
    }
}