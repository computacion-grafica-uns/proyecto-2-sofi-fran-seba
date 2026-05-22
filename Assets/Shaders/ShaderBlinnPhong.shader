Shader "Custom/ShaderBlinnPhong"
{
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        _SpecColor ("Specular Color", Color) = (1, 1, 1, 1) //para color del destello
        _Shininess ("Shininess (Exponente)", Range(1.0, 128.0)) = 32.0 //"N shiny"
        
        //direccional
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        //puntual
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        //spot
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
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1; 
            };

            // Variables Globales
            float4 _MainColor;
            float4 _SpecColor;
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
                return output;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                
                //vectro vista
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Inicializadores de luz acumulada
                float3 totalDiffuse = float3(0,0,0);
                float3 totalSpecular = float3(0,0,0);

                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                
                // Difuso (Lambert)
                float NdotL1 = max(0.0, dot(normal, L1));
                totalDiffuse += NdotL1 * _DirLightColor.rgb;
                
                //espcecular
                if (NdotL1 > 0.0) {
                    float3 H1 = normalize(L1 + viewDir); // Vector medio h 
                    float NdotH1 = max(0.0, dot(normal, H1));
                    totalSpecular += pow(NdotH1, _Shininess) * _DirLightColor.rgb;
                }

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                
                // Difuso
                float NdotL2 = max(0.0, dot(normal, L2));
                totalDiffuse += NdotL2 * _PointLightColor.rgb * attenPoint;
                
                // Especular
                if (NdotL2 > 0.0) {
                    float3 H2 = normalize(L2 + viewDir);
                    float NdotH2 = max(0.0, dot(normal, H2));
                    totalSpecular += pow(NdotH2, _Shininess) * _PointLightColor.rgb * attenPoint;
                }

                // spot
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);

                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    
                    // Difuso
                    float NdotL3 = max(0.0, dot(normal, L3));
                    totalDiffuse += NdotL3 * _SpotLightColor.rgb * attenSpot;
                    
                    // Especular
                    if (NdotL3 > 0.0) {
                        float3 H3 = normalize(L3 + viewDir);
                        float NdotH3 = max(0.0, dot(normal, H3));
                        totalSpecular += pow(NdotH3, _Shininess) * _SpotLightColor.rgb * attenSpot;
                    }
                }

                // unifiacion
                // El color difuso se multiplica por el color base del objeto
                // El color especular se suma de forma aditiva por encima (reflejo brillante)
                float3 finalColor = (totalDiffuse * _MainColor.rgb) + (totalSpecular * _SpecColor.rgb);

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}