Shader "Custom/ShaderProceduralBlinnPhong"
{
    Properties
    {
        _ColorLunares ("Color de los Lunares", Color) = (1, 1, 1, 1)     // Blancos por defecto
        _ColorFondo ("Color de Fondo", Color) = (0.8, 0.1, 0.2, 1)       // Rojo por defecto (Estilo Minnie Mouse)
        
        // Propiedades de Blinn-Phong
        _Shininess ("Shininess (Exponente)", Range(1.0, 128.0)) = 32.0
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        
        // Control del diseño procedural de lunares
        _Repeticion ("Cantidad de Lunares", Range(2.0, 30.0)) = 10.0
        _Radio ("Tamaño del Lunar", Range(0.05, 0.45)) = 0.25

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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            float4 _ColorLunares;
            float4 _ColorFondo;
            float _Shininess;
            float4 _SpecularColor;
            float _Repeticion;
            float _Radio;
            
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
                output.uv = v.uv;
                return output;
            }

            // Función de Iluminación clásica de Blinn-Phong
            float3 ComputeBlinnPhong(float3 N, float3 L, float3 V, float3 lightColor, float3 surfaceColor)
            {
                // Componente Difusa (Lambert)
                float NdotL = max(0.0, dot(N, L));
                float3 diffuse = surfaceColor * lightColor * NdotL;

                // Componente Especular (Blinn-Phong usa el vector medio H)
                float3 H = normalize(V + L);
                float NdotH = max(0.0, dot(N, H));
                float specularIntensity = pow(NdotH, _Shininess);
                float3 specular = _SpecularColor.rgb * lightColor * specularIntensity;

                return diffuse + specular;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // ==========================================
                // LÓGICA PROCEDURAL: LUNARES (POLKA DOTS)
                // ==========================================
                // 1. Multiplicamos las UV para crear una cuadrícula repetitiva
                float2 uvRepetida = i.uv * _Repeticion;

                // 2. Con frac() nos quedamos solo con la parte decimal. Cada celda va de (0,0) a (1,1)
                float2 uvCelda = frac(uvRepetida);

                // 3. Calculamos la distancia desde el centro de cada celda individual (0.5, 0.5)
                float distAlCentro = length(uvCelda - float2(0.5, 0.5));

                // 4. Si la distancia es menor que el radio, pintamos el lunar. Usamos step() para corte limpio.
                float esLunar = step(distAlCentro, _Radio);

                // Interpolamos entre el color del fondo y el color del lunar
                float3 colorProcedural = lerp(_ColorFondo.rgb, _ColorLunares.rgb, esLunar);
                // ==========================================

                // EVALUACIÓN DE LUCES (Blinn-Phong)
                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeBlinnPhong(normal, L1, viewDir, _DirLightColor.rgb, colorProcedural);

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeBlinnPhong(normal, L2, viewDir, lightPointColor, colorProcedural);

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
                    lightSpotResult = ComputeBlinnPhong(normal, L3, viewDir, lightSpotColor, colorProcedural);
                }

                // Suma final de radiancia
                float3 finalColor = lightDirResult + lightPointResult + lightSpotResult;

                return float4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}