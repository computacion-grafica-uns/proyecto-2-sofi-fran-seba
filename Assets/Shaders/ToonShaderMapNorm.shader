Shader "Custom/ToonShaderMapNorm_MultiLight"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
        _Glossiness ("Tamaño del Brillo Toon", Range(0.01, 1.0)) = 0.3
        _OutlineThickness ("Grosor del Borde Negro", Range(0.0, 0.5)) = 0.25

        [Header(Directional Light Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        [Header(Point Light Setup)]
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        [Header(Spot Light Setup)]
        _SpotLightPosition ("Spot Light Position", Vector) = (0, 3, 0, 1)
        _SpotLightDirection ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (0, 0, 1, 1)
        _Apertura ("Apertura (Angulo)", Range(0.0, 90.0)) = 30.0
        _SpotRange ("Spot Range", Float) = 10.0
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
            sampler2D _NormalMap;
            float4 _MainTex_ST;
            
            float _Glossiness;
            float _OutlineThickness;

            // Variables globales de iluminación
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
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3x3 worldToTangent : TEXCOORD3;
                float3 viewDirTangent : TEXCOORD6;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // Calculamos posiciones globales necesarias
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // Construcción de la matriz de espacio de tangente (TBN)
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w;
                float3x3 worldToTangentSpace = float3x3(worldTangent, worldBitangent, worldNormal);
                
                // Nos guardamos la matriz entera para transformar vectores de luz en el fragment
                o.worldToTangent = worldToTangentSpace;

                // Transformamos la dirección de la cámara al espacio de tangente
                float3 worldV = _WorldSpaceCameraPos - o.worldPos;
                o.viewDirTangent = mul(worldToTangentSpace, worldV);

                return o;
            }

            // Función unificada que calcula el Toon Shading (Cel Shading) por cada luz independiente
            float3 ComputeToon(float3 N, float3 L, float3 V, float3 lightColor, float glossiness)
            {
                // 1. Difusa Estilo Toon (Cortes discretos adaptados a tu código original)
                float NdotL = dot(N, L);
                float toonLambert = 0.2; 

                if (NdotL > 0.6) {
                    toonLambert = 1.0;
                } else if (NdotL > 0.2) {
                    toonLambert = 0.6;
                }

                // 2. Especular Estilo Toon
                float3 R = reflect(-L, N);
                float RdotV = max(0.0, dot(R, V));
                float spec = pow(RdotV, 32.0); 
                
                float toonSpecular = 0.0;
                if (spec > (1.0 - glossiness)) {
                    toonSpecular = 1.0;
                }

                // El resultado es la combinación de ambas componentes moduladas por el color real de esa luz
                return (toonLambert + toonSpecular * float3(1,1,1)) * lightColor;
            }

            fixed4 frag (v2f i) : SV_Target {
                // 1. Desempaquetar la normal del mapa de relieve (Ya vive en espacio de tangente)
                float3 N = normalize(UnpackNormal(tex2D(_NormalMap, i.uv)));
                
                // 2. Normalizar vector de visión
                float3 V = normalize(i.viewDirTangent);

                // --- DETECCIÓN DEL BORDE ESTILO CÓMIC (Outline interior) ---
                float NdotV = max(0.0, dot(N, V));
                float outlineMask = 1.0;
                if (NdotV < _OutlineThickness) {
                    outlineMask = 0.0;
                }

                // Acumulador final de iluminancia de la escena
                float3 totalLightResult = float3(0,0,0);

                // ========================================================
                // 1. LUZ DIRECCIONAL
                // ========================================================
                float3 worldL1 = normalize(-_DirLightDirection.xyz);
                float3 L1 = normalize(mul(i.worldToTangent, worldL1)); // Pasamos a espacio de tangente
                
                totalLightResult += ComputeToon(N, L1, V, _DirLightColor.rgb, _Glossiness);

                // ========================================================
                // 2. LUZ PUNTUAL
                // ========================================================
                float3 toPointWorld = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPointWorld);
                
                float3 L2 = normalize(mul(i.worldToTangent, toPointWorld)); // Pasamos a espacio de tangente
                
                float attenPoint = max(0.0, 1.0 - (distancePoint / max(0.001, _LightRange)));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                
                totalLightResult += ComputeToon(N, L2, V, lightPointColor, _Glossiness);

                // ========================================================
                // 3. LUZ FOCAL (Spot Light)
                // ========================================================
                float3 toSpotWorld = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpotWorld);
                
                float3 L3 = normalize(mul(i.worldToTangent, toSpotWorld)); // Pasamos a espacio de tangente
                float3 spotDirWorld = normalize(-_SpotLightDirection.xyz);
                
                // El cálculo de la apertura del cono se procesa en World Space de forma limpia
                float cosCurrentAngle = dot(normalize(toSpotWorld), spotDirWorld);
                float cosAperture = cos(radians(_Apertura));

                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / max(0.001, _SpotRange)));
                    
                    // Suavizado en el borde del cono para que no sea un corte serruchado áspero
                    float edgeSmoothing = smoothstep(cosAperture, cosAperture + 0.05, cosCurrentAngle);
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot * edgeSmoothing;
                    
                    totalLightResult += ComputeToon(N, L3, V, lightSpotColor, _Glossiness);
                }

                // ========================================================
                // COMPOSICIÓN FINAL
                // ========================================================
                // Leemos el albedo base del objeto y su color de propiedad
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _MaterialColor.rgb;
                
                // Multiplicamos la textura por el acumulado de iluminación obtenido y aplicamos el outline
                float3 colorIluminado = albedo * totalLightResult;
                
                fixed4 fragColor = fixed4(1,1,1,1);
                fragColor.rgb = colorIluminado * outlineMask;
                
                return fragColor;
            }
            ENDCG
        }
    }
}