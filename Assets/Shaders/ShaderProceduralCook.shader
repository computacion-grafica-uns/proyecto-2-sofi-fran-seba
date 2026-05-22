Shader "Custom/ShaderProceduralCook"
{
    Properties
    {
        _ColorA ("Color Principal (Lineas)", Color) = (0.8, 0.5, 0.2, 1)  // Color de los anillos
        _ColorB ("Color Secundario (Fondo)", Color) = (0.1, 0.1, 0.15, 1) // Fondo oscuro para contraste
        
        // Propiedades de Cook-Torrance
        _Roughness ("Roughness (rp)", Range(0.0, 1.0)) = 0.2
        _F0 ("Fresnel Reflectance (F0)", Color) = (0.5, 0.5, 0.5, 1)
        _RhoD ("Diffuse Coefficient (rho_d)", Range(0.0, 1.0)) = 0.6

        // Control del diseño procedural
        _Frecuencia ("Frecuencia de Anillos", Range(5.0, 50.0)) = 25.0

        _DirLightDirection ("Directional Light Direction", Vector) = (1, -0.5, 0.5, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        _PointLightPosition ("Point Light Position", Vector) = (-2, 0.5, 2, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        _SpotLightPosition ("Spot Light Position", Vector) = (2, 1, 2, 1)
        _SpotLightDirection ("Spot Light Direction", Vector) = (-1, -0.2, -1, 0)
        _SpotLightColor ("Spot Light Color", Color) = (0, 0, 1, 1)
        _Apertura ("Apertura (Angulo)", Range(0.0, 90.0)) = 30.0
        _SpotRange ("Spot Range", Float) = 10.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct vertexdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0; // Necesitamos las UVs para el cálculo procedural
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            float4 _ColorA;
            float4 _ColorB;
            float _Roughness;
            float4 _F0;
            float _RhoD;
            float _Frecuencia;
            
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

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                output.uv = v.uv; // Pasamos las UV del modelo al fragment shader
                return output;
            }

            // GGX (D)
            float NDF_GGX(float NdotH, float alpha)
            {
                float alpha2 = alpha * alpha;
                float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
                return alpha2 / (3.14159265 * denom * denom);
            }

            // G1
            float GeometrySchlickGGX(float NdotV, float k)
            {
                return NdotV / (NdotV * (1.0 - k) + k);
            }

            // G
            float GeometrySmith(float NdotV, float NdotL, float alpha)
            {
                float k = alpha / 2.0;
                float g1_v = GeometrySchlickGGX(NdotV, k);
                float g1_l = GeometrySchlickGGX(NdotL, k);
                return g1_v * g1_l;
            }

            // Reflectancia, Schlick (F)
            float3 FresnelSchlick(float VdotH, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(max(0.0, 1.0 - VdotH), 5.0);
            }

            // BRDF de Cook-Torrance
            float3 ComputeCookTorrance(float3 N, float3 L, float3 V, float3 lightColor, float alpha, float3 F0, float rhoD)
            {
                float3 H = normalize(V + L);

                float NdotL = max(0.001, dot(N, L));
                float NdotV = max(0.001, dot(N, V));
                float NdotH = max(0.001, dot(N, H));
                float VdotH = max(0.001, dot(V, H));

                float D = NDF_GGX(NdotH, alpha);
                float G = GeometrySmith(NdotV, NdotL, alpha);
                float3 F = FresnelSchlick(VdotH, F0);

                float3 specularNumerator = D * G * F;
                float specularDenominator = 4.0 * NdotL * NdotV;
                float3 f_s = specularNumerator / max(0.001, specularDenominator);

                float3 f_d = rhoD / 3.14159265;

                return (f_d + f_s) * lightColor * NdotL;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                float alpha = _Roughness * _Roughness;
                float3 F0 = _F0.rgb;

                // ==========================================
                // LÓGICA DE TEXTURA PROCEDURAL (ANILLOS)
                // ==========================================
                // 1. Calculamos la distancia desde el centro de la coordenada UV (0.5, 0.5)
                float2 centro = i.uv - float2(0.5, 0.5);
                float distancia = length(centro);

                // 2. Usamos una función seno multiplicada por la frecuencia para generar ondas repetitivas.
                // Usamos un filtro "sign" o "step" para volver el degradado en bordes definidos.
                float onda = sin(distancia * _Frecuencia);
                
                // Convertimos la onda sinusoidal en un patrón binario (0 o 1) con un corte limpio
                float patron = step(0.0, onda);

                // 3. Interpolamos entre tus dos colores usando el patrón procedural matemático
                float3 colorProcedural = lerp(_ColorA.rgb, _ColorB.rgb, patron);
                // ==========================================

                // CÁLCULO DE ILUMINACIÓN (Tu estructura Cook-Torrance intacta)
                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeCookTorrance(normal, L1, viewDir, _DirLightColor.rgb, alpha, F0, _RhoD);

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeCookTorrance(normal, L2, viewDir, lightPointColor, alpha, F0, _RhoD);

                // spot
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                float3 lightSpotResult = float3(0, 0, 0);
                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot;
                    lightSpotResult = ComputeCookTorrance(normal, L3, viewDir, lightSpotColor, alpha, F0, _RhoD);
                }

                // El resultado total de la radiancia se modula por nuestro Color Procedural en lugar de _MainColor
                float3 totalRadiance = lightDirResult + lightPointResult + lightSpotResult;
                float3 finalColor = totalRadiance * colorProcedural;

                return float4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}