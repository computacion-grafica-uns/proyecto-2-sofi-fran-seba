Shader "Custom/ShaderCookTorranceNormalMap"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
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

            // Variables del material
            float4 _MaterialColor;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            float4 _MainTex_ST;
            
            float _F0;
            float _Roughness;

            // Variables Globales de Luces
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
                float4 tangent : TANGENT; // Trae la dirección de la tangente y el signo w 
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                // Pasamos los vectores de la geometría base para armar el TBN en el frag
                float3 worldNormal : TEXCOORD3;
                float3 worldTangent : TEXCOORD4;
                float3 worldBitangent : TEXCOORD5;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // Calculamos y enviamos los vectores base en World Space 
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                
                // El Bitangente se calcula con el producto cruz de los anteriores y el signo w 
                o.worldBitangent = cross(o.worldNormal, o.worldTangent) * v.tangent.w;

                return o;
            }

            // --- FUNCIÓN AUXILIAR REUTILIZABLE DE COOK-TORRANCE ---
            float3 ComputeCookTorrance(float3 N, float3 L, float3 V, float3 lightColor, float roughness, float F0, float3 albedoColor)
            {
                float3 H = normalize(L + V); // Vector Medio 
                
                float dotNL = dot(N, L);
                float NdotL = max(0.0001, dotNL); // Evitamos división por cero 
                float NdotV = max(0.0001, dot(N, V));
                float NdotH = max(0.0, dot(N, H));
                float HdotV = max(0.0, dot(H, V));

                // --- Ecuación D (GGX) --- 
                float alpha2 = roughness * roughness;
                float denomD = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0; 
                float D = alpha2 / (3.14159265 * denomD * denomD); 

                // --- Ecuación F (Schlick) --- 
                float F = F0 + (1.0 - F0) * pow(1.0 - HdotV, 5.0);

                // --- Ecuación G (Schlick-GGX / Smith) --- 
                float k = roughness / 2.0;
                float G1_L = NdotL / (NdotL * (1.0 - k) + k); 
                float G1_V = NdotV / (NdotV * (1.0 - k) + k); 
                float G = G1_L * G1_V;

                // --- BRILLO ESPECULAR COOK-TORRANCE --- 
                float specularTerm = (D * F * G) / (4.0 * NdotL * NdotV);
                float3 specular = specularTerm * float3(1, 1, 1); 

                // --- COMPONENTE DIFUSA (Lambert) ---
                float realLambert = max(0.0, dotNL);
                float3 diffuse = realLambert * albedoColor;

                // --- FILTRO DEL TERMINADOR SUAVE ---
                // Evita que el specular flote de manera irreal en las micro-sombras del normal map 
                float terminadorMask = smoothstep(0.0, 0.05, dotNL);
                specular *= terminadorMask; 

                // El resultado final de esta luz es la suma afectada por su color/intensidad
                return (diffuse + specular) * lightColor;
            }

            fixed4 frag (v2f i) : SV_Target {
                // 1. Reconstruimos la matriz Tangent-to-World (TBN) en el fragment shader
                float3 T = normalize(i.worldTangent);
                float3 B = normalize(i.worldBitangent);
                float3 M = normalize(i.worldNormal);
                float3x3 tangentToWorldSpace = float3x3(T, B, M);

                // 2. Desempaquetamos la normal del mapa y la transformamos directamente a World Space
                float3 normalFromMap = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3 normal = normalize(mul(normalFromMap, tangentToWorldSpace));

                // 3. Vector de vista en World Space
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // 4. Color base del objeto (Albedo) 
                float3 texColor = tex2D(_MainTex, i.uv).rgb;
                float3 albedo = texColor * _MaterialColor.rgb;

                // --- 1) LUZ DIRECCIONAL ---
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeCookTorrance(normal, L1, viewDir, _DirLightColor.rgb, _Roughness, _F0, albedo);

                // --- 2) LUZ PUNTUAL ---
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeCookTorrance(normal, L2, viewDir, lightPointColor, _Roughness, _F0, albedo);

                // --- 3) LUZ SPOT (REFLECTOR) ---
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
                    
                    // Suavizado en el contorno del cono de luz para evitar bordes dentados
                    float spotIntensity = smoothstep(cosAperture, cosAperture + 0.04, cosCurrentAngle);
                    
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot * spotIntensity;
                    lightSpotResult = ComputeCookTorrance(normal, L3, viewDir, lightSpotColor, _Roughness, _F0, albedo);
                }

                // --- COMBINACIÓN FINAL ---
                fixed4 fragColor = fixed4(0, 0, 0, 1);
                
                // Acumulamos el impacto de todas las fuentes de iluminación analizadas
                fragColor.rgb = lightDirResult + lightPointResult + lightSpotResult;

                return fragColor;
            }
            ENDCG
        }
    }
}