Shader "Custom/ShaderBlinnPhongNormalMap"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
        _SpecularColor ("Color del Brillo (Ks)", Color) = (1,1,1,1)
        _Shininess ("Exponente de Brillo (n)", Range(1, 128)) = 32
       
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
            sampler2D _NormalMap;
            float4 _MainTex_ST;
            
            float4 _SpecularColor;
            float _Shininess;
            
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
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD3;
                float3 worldTangent : TEXCOORD4;
                float3 worldBitangent : TEXCOORD5;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // Calculamos y pasamos los vectores directos en World Space
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBitangent = cross(o.worldNormal, o.worldTangent) * v.tangent.w;

                return o;
            }

            // --- FUNCIÓN AUXILIAR BLINN-PHONG ---
            // Modifica los acumuladores de iluminación difusa y especular por cada luz instalada
            void ComputeBlinnPhong(float3 N, float3 L, float3 V, float3 lightColor, float shininess, 
                                   inout float3 totalDiffuse, inout float3 totalSpecular)
            {
                // Componente Difusa (Lambert)
                float dotNL = dot(N, L);
                float NdotL = max(0.0, dotNL);
                totalDiffuse += NdotL * lightColor;

                // Componente Especular (Blinn-Phong) con Filtro de Terminador Suave integrado
                if (NdotL > 0.0) {
                    float3 H = normalize(L + V);
                    float NdotH = max(0.0, dot(N, H));
                    
                    float spec = pow(NdotH, shininess);
                    float terminadorMask = smoothstep(0.0, 0.05, dotNL);
                    
                    totalSpecular += spec * lightColor * terminadorMask;
                }
            }

            fixed4 frag (v2f i) : SV_Target {
                // 1. Reconstruir la matriz Tangent-to-World para transformar la normal del mapa
                float3 T = normalize(i.worldTangent);
                float3 B = normalize(i.worldBitangent);
                float3 M = normalize(i.worldNormal);
                float3x3 tangentToWorldSpace = float3x3(T, B, M);

                // 2. Leer la normal del mapa y llevarla a World Space
                float3 normalFromMap = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3 normal = normalize(mul(normalFromMap, tangentToWorldSpace));

                // 3. Vector de vista en World Space
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Inicializadores de luz acumulada
                float3 totalDiffuse = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                // --- 1) LUZ DIRECCIONAL ---
                float3 L1 = normalize(-_DirLightDirection.xyz);
                ComputeBlinnPhong(normal, L1, viewDir, _DirLightColor.rgb, _Shininess, totalDiffuse, totalSpecular);

                // --- 2) LUZ PUNTUAL ---
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                ComputeBlinnPhong(normal, L2, viewDir, lightPointColor, _Shininess, totalDiffuse, totalSpecular);

                // --- 3) LUZ SPOT (REFLECTOR) ---
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);

                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    
                    // Suavizado del borde del cono de luz
                    float spotIntensity = smoothstep(cosAperture, cosAperture + 0.03, cosCurrentAngle);
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot * spotIntensity;
                    
                    ComputeBlinnPhong(normal, L3, viewDir, lightSpotColor, _Shininess, totalDiffuse, totalSpecular);
                }

                // --- COMPOSICIÓN DE TEXTURAS Y COLORES PROPIOS ---
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _MaterialColor.rgb;
                float3 ambient = 0.1 * albedo; // Luz ambiental estática básica

                // --- COMBINACIÓN FINAL ---
                fixed4 fragColor = fixed4(1, 1, 1, 1);
                fragColor.rgb = ambient + (totalDiffuse * albedo) + (totalSpecular * _SpecularColor.rgb);

                return fragColor;
            }
            ENDCG
        }
    }
}