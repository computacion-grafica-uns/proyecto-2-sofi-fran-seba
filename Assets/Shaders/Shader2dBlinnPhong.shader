Shader "Custom/Shader2dBlinnPhong"
{
    Properties
    {
        _MainColor ("Tint Color (Modifica la Textura)", Color) = (1, 1, 1, 1)
        _MainTex ("Base Texture (2D)", 2D) = "white" {} // <-- La propiedad para cargar tu imagen
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Shininess ("Shininess (Exponente Brillo)", Range(1.0, 500.0)) = 50.0
        
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
                float2 texcoord : TEXCOORD0; // 1. Recibimos las UV originales del modelo 3D
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1; 
                float2 uv : TEXCOORD2;        // 2. Pasamos las UV procesadas al fragment shader
            };

            float4 _MainColor;
            sampler2D _MainTex;          // Variable de textura
            float4 _MainTex_ST;          // Variable de Unity para Tiling y Offset
            float4 _SpecularColor;
            float _Shininess;
            
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
                
                // 3. Aplicamos la escala (Tiling) y desfasaje (Offset) configurados en el Inspector
                output.uv = TRANSFORM_TEX(v.texcoord, _MainTex); 
                
                return output;
            }

            // Función auxiliar Blinn-Phong para una luz individual
            // Devuelve float4: .rgb es la luz acumulada, .a es el factor difuso aislado para modular
            float3 ComputeBlinnPhong(float3 N, float3 L, float3 V, float3 lightColor, float attenuation, float3 surfaceColor)
            {
                // Componente Difusa (Lambert)
                float NdotL = max(0.0, dot(N, L));
                float3 diffuse = surfaceColor * lightColor * NdotL * attenuation;

                // Componente Especular (Blinn-Phong usando el vector medio H)
                float3 H = normalize(V + L);
                float NdotH = max(0.0, dot(N, H));
                float specIntensity = pow(NdotH, _Shininess);
                float3 specular = _SpecularColor.rgb * lightColor * specIntensity * attenuation * (NdotL > 0.0);

                return diffuse + specular;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // 4. MUESTREO DE TEXTURA: Leemos el color del píxel de la imagen en esa coordenada UV
                float4 texColor = tex2D(_MainTex, i.uv);
                
                // Modulamos (multiplicamos) la textura por el color base para poder teñirla desde el Inspector
                float3 albedo = texColor.rgb * _MainColor.rgb;

                float3 totalColor = float3(0, 0, 0);

                // --- 1. LUZ DIRECCIONAL ---
                float3 L1 = normalize(-_DirLightDirection.xyz);
                totalColor += ComputeBlinnPhong(normal, L1, viewDir, _DirLightColor.rgb, 1.0, albedo);

                // --- 2. LUZ PUNTUAL ---
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                totalColor += ComputeBlinnPhong(normal, L2, viewDir, _PointLightColor.rgb, attenPoint, albedo);

                // --- 3. LUZ SPOT ---
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    totalColor += ComputeBlinnPhong(normal, L3, viewDir, _SpotLightColor.rgb, attenSpot, albedo);
                }

                // Luz ambiental base para que las zonas oscuras no queden completamente negras
                float3 ambient = albedo * 0.15;
                totalColor += ambient;

                return float4(totalColor, _MainColor.a * texColor.a);
            }
            ENDCG
        }
    }
}