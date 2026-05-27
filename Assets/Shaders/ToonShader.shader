/*
Shader "Custom/ToonShader"
{
    Properties
    {
        _MainColor ("Base Color (Diffuse)", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.2, 1) // Color de la zona de sombra
        
        // Propiedades del Toon-Shader
        _Glossiness ("Glossiness (Tamanio Brillo)", Range(0.01, 1.0)) = 0.5
        _ToonThreshold ("Toon Diffuse Threshold", Range(0.0, 1.0)) = 0.3
        _ToonSmoothness ("Toon Smoothness", Range(0.001, 0.5)) = 0.05

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
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1; 
            };

            float4 _MainColor;
            float4 _ShadowColor;
            float _Glossiness;
            float _ToonThreshold;
            float _ToonSmoothness;
            
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

            // Funci�n encargada de calcular el Toon Shading por cada luz
            float3 ComputeToon(float3 N, float3 L, float3 V, float3 lightColor)
            {
                // 1. Componente Difusa (Lambert cl�sico)
                float NdotL = dot(N, L);
                
                // Variaci�n Toon usando smoothstep para controlar el escal�n de la sombra de forma limpia
                // Si NdotL es mayor al umbral se vuelve 1 (iluminado), si es menor se vuelve 0 (sombra)
                float diffuseIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, NdotL);
                
                // Interpolamos entre el color de sombra y el color de luz pleno seg�n la intensidad calculada
                float3 diffuseTerm = lerp(_ShadowColor.rgb, lightColor, diffuseIntensity);

                // 2. Componente Especular (Brillo duro de estilo cel-shading)
                float3 H = normalize(V + L);
                float NdotH = max(0.0, dot(N, H));
                
                // El brillo especular solo aparece si la intensidad supera un umbral muy estricto basado en la rugosidad/glosiness
                float specularIntensity = pow(NdotH, _Glossiness * 128.0);
                float specularToon = smoothstep(0.5 - _ToonSmoothness, 0.5 + _ToonSmoothness, specularIntensity);
                float3 specularTerm = specularToon * lightColor;

                // El resultado final para esta luz es la combinaci�n de su sombra/luz plana + su brillo duro
                return (diffuseTerm + specularTerm) * max(0.0, NdotL);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeToon(normal, L1, viewDir, _DirLightColor.rgb);

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeToon(normal, L2, viewDir, lightPointColor);

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
                    lightSpotResult = ComputeToon(normal, L3, viewDir, lightSpotColor);
                }

                // Unificaci�n y modulaci�n con el color de la superficie
                float3 totalRadiance = lightDirResult + lightPointResult + lightSpotResult;
                float3 finalColor = totalRadiance * _MainColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}

Shader "Custom/ToonShader_Anime"
{
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.4, 1) 
        
        [Header(Toon Settings)]
        _Steps ("Cantidad de Bandas de Luz", Range(1, 4)) = 2
        _ToonThreshold ("Umbral de Sombra", Range(0.0, 1.0)) = 0.4
        _ToonSmoothness ("Suavizado de Bordes", Range(0.001, 0.1)) = 0.01

        [Header(Specular)]
        _Glossiness ("Tama�o Brillo (Especular)", Range(0.01, 1.0)) = 0.1
        _SpecIntensity ("Intensidad Brillo", Range(0.0, 1.0)) = 0.5

        [Header(Rim Lighting)]
        _RimColor ("Color de Contorno Interior (Rim)", Color) = (1, 1, 1, 1)
        _RimPower ("Poder del Rim", Range(0.5, 8.0)) = 3.0
        _RimThreshold ("Umbral del Rim", Range(0.0, 1.0)) = 0.5

        [Header(Outline)]
        _OutlineColor ("Color de la Linea", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Grosor de la Linea", Range(0.0, 0.1)) = 0.015
        
        [Header(Directional Light Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)

        [Header(Point Light Setup)]
        _PointLightPosition ("Point Light Position (XYZ)", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 1, 1, 1)
        _PointLightRadius ("Point Light Radius", Range(0.1, 50.0)) = 10.0

        [Header(Spot Light Setup)]
        _SpotLightPos ("Spot Light Position (XYZ)", Vector) = (0, 5, 0, 1)
        _SpotLightDir ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (1, 1, 1, 1)
        _SpotLightRange ("Spot Light Range", Range(0.1, 50.0)) = 15.0
        _SpotLightAngle ("Spot Light Angle (Cos Outer)", Range(0.0, 1.0)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        // --- PASS 1: EL OUTLINE (Dibuja los bordes negros) ---
        Pass
        {
            Cull Front 

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            float _OutlineWidth;
            float4 _OutlineColor;

            v2f vert (appdata v)
            {
                v2f o;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                worldPos.xyz += worldNormal * _OutlineWidth;
                
                o.pos = mul(UNITY_MATRIX_VP, worldPos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return _OutlineColor; 
            }
            ENDCG
        }

        // --- PASS 2: EL SOMBREADO CEL (Cuerpo del objeto con 3 Luces) ---
        Pass
        {
            Cull Back 

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

            float4 _MainColor;
            float4 _ShadowColor;
            float _Steps;
            float _ToonThreshold;
            float _ToonSmoothness;
            
            float _Glossiness;
            float _SpecIntensity;

            float4 _RimColor;
            float _RimPower;
            float _RimThreshold;

            // Variables de Luces
            float4 _DirLightDirection;
            float4 _DirLightColor;

            float4 _PointLightPosition;
            float4 _PointLightColor;
            float _PointLightRadius;

            float4 _SpotLightPos;
            float4 _SpotLightDir;
            float4 _SpotLightColor;
            float _SpotLightRange;
            float _SpotLightAngle;

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return output;
            }

            // Funci�n interna para calcular la iluminaci�n Toon por cada luz de forma id�ntica a tu l�gica original
            float3 CalculateToonLight(float3 normal, float3 viewDir, float3 lightDir, float3 lightColor, float atten)
            {
                // 1. DIFUSO TOON CON PASOS
                float NdotL = dot(normal, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5; 
                
                float toonIntensity = floor(halfLambert * _Steps) / (_Steps - 1);
                toonIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, toonIntensity);
                
                // Aplicamos la atenuaci�n directo a la intensidad toon para que la sombra act�e de forma fluida
                float3 diffuseColor = lerp(_ShadowColor.rgb, _MainColor.rgb, toonIntensity * atten);

                // 2. ESPECULAR ANIME
                float3 H = normalize(viewDir + lightDir);
                float NdotH = max(0.0, dot(normal, H));
                float specIntensity = pow(NdotH, (1.0 - _Glossiness) * 128.0);
                float specularToon = smoothstep(0.5 - 0.01, 0.5 + 0.01, specIntensity) * _SpecIntensity;
                float3 finalSpecular = specularToon * lightColor * atten;

                // 3. RIM LIGHTING
                float rimDot = 1.0 - max(0.0, dot(normal, viewDir));
                float rimIntensity = pow(rimDot, _RimPower);
                rimIntensity = smoothstep(_RimThreshold - 0.05, _RimThreshold + 0.05, rimIntensity) * max(0.0, NdotL);
                float3 finalRim = rimIntensity * _RimColor.rgb * atten;

                return (diffuseColor + finalSpecular + finalRim) * lightColor;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                
                float3 finalColor = float3(0,0,0);

                // ==========================================
                // 1. LUZ DIRECCIONAL (Sin Atenuaci�n por distancia)
                // ==========================================
                float3 dirLightDir = normalize(-_DirLightDirection.xyz);
                finalColor += CalculateToonLight(normal, viewDir, dirLightDir, _DirLightColor.rgb, 1.0);

                // ==========================================
                // 2. LUZ PUNTUAL (Point Light con atenuaci�n por distancia)
                // ==========================================
                float3 pointLightVec = _PointLightPosition.xyz - i.worldPos;
                float pointDist = length(pointLightVec);
                float3 pointLightDir = normalize(pointLightVec);
                
                // Atenuaci�n lineal/cuadr�tica simple basada en el radio configurado
                float pointAtten = saturate(1.0 - (pointDist / _PointLightRadius));
                pointAtten *= pointAtten; // Ca�da m�s suave
                
                finalColor += CalculateToonLight(normal, viewDir, pointLightDir, _PointLightColor.rgb, pointAtten);

                // ==========================================
                // 3. LUZ FOCAL (Spot Light con atenuaci�n de distancia y cono)
                // ==========================================
                float3 spotLightVec = _SpotLightPos.xyz - i.worldPos;
                float spotDist = length(spotLightVec);
                float3 spotLightDir = normalize(spotLightVec);
                
                // Atenuaci�n por distancia
                float spotDistAtten = saturate(1.0 - (spotDist / _SpotLightRange));
                spotDistAtten *= spotDistAtten;

                // Atenuaci�n por cono del Spot (�ngulo)
                float3 currentSpotDir = normalize(_SpotLightDir.xyz);
                float cosAngle = dot(-spotLightDir, currentSpotDir);
                
                // El corte del borde del cono se suaviza levemente estilo Toon
                float spotConeAtten = smoothstep(_SpotLightAngle, _SpotLightAngle + 0.1, cosAngle);
                float spotAtten = spotDistAtten * spotConeAtten;

                finalColor += CalculateToonLight(normal, viewDir, spotLightDir, _SpotLightColor.rgb, spotAtten);

                // ==========================================
                // Salida Final
                // ==========================================
                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
} */

Shader "Custom/ToonShader_Anime_SpotFixed"
{
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.4, 1) 
        
        [Header(Toon Settings)]
        _Steps ("Cantidad de Bandas de Luz", Range(1, 4)) = 2
        _ToonThreshold ("Umbral de Sombra", Range(0.0, 1.0)) = 0.4
        _ToonSmoothness ("Suavizado de Bordes", Range(0.001, 0.1)) = 0.01

        [Header(Specular)]
        _Glossiness ("Tamaño Brillo (Especular)", Range(0.01, 1.0)) = 0.1
        _SpecIntensity ("Intensidad Brillo", Range(0.0, 1.0)) = 0.5

        [Header(Rim Lighting)]
        _RimColor ("Color de Contorno Interior (Rim)", Color) = (1, 1, 1, 1)
        _RimPower ("Poder del Rim", Range(0.5, 8.0)) = 3.0
        _RimThreshold ("Umbral del Rim", Range(0.0, 1.0)) = 0.5

        [Header(Outline)]
        _OutlineColor ("Color de la Linea", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Grosor de la Linea", Range(0.0, 0.1)) = 0.015
        
        [Header(Directional Light Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)

        [Header(Point Light Setup)]
        _PointLightPosition ("Point Light Position (XYZ)", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 1, 1, 1)
        _PointLightRadius ("Point Light Radius", Range(0.1, 50.0)) = 10.0

        [Header(Spot Light Setup)]
        _SpotLightPos ("Spot Light Position (XYZ)", Vector) = (0, 5, 0, 1)
        _SpotLightDir ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (1, 1, 1, 1)
        _SpotLightRange ("Spot Light Range", Range(0.1, 50.0)) = 15.0
        _SpotLightAngle ("Spot Light Angle (Cos Outer)", Range(0.0, 1.0)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        // --- PASS 1: EL OUTLINE ---
        Pass
        {
            Cull Front 

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; };
            struct v2f { float4 pos : SV_POSITION; };
            float _OutlineWidth; float4 _OutlineColor;

            v2f vert (appdata v) {
                v2f o;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                worldPos.xyz += worldNormal * _OutlineWidth;
                o.pos = mul(UNITY_MATRIX_VP, worldPos);
                return o;
            }
            fixed4 frag (v2f i) : SV_Target { return _OutlineColor; }
            ENDCG
        }

        // --- PASS 2: EL SOMBREADO CEL ---
        Pass
        {
            Cull Back 

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct vertexdata { float4 vertex : POSITION; float3 normal : NORMAL; };
            struct v2f { float4 position : SV_POSITION; float3 normal_w : TEXCOORD0; float3 worldPos : TEXCOORD1; };

            float4 _MainColor; float4 _ShadowColor;
            float _Steps; float _ToonThreshold; float _ToonSmoothness;
            float _Glossiness; float _SpecIntensity;
            float4 _RimColor; float _RimPower; float _RimThreshold;

            float4 _DirLightDirection; float4 _DirLightColor;
            float4 _PointLightPosition; float4 _PointLightColor; float _PointLightRadius;
            float4 _SpotLightPosition; float4 _SpotLightDirection; float4 _SpotLightColor; float _SpotLightRange; float _SpotLightAngle;

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return output;
            }

            // Calcula la máscara de intensidad Toon (0 a 1) para cada luz
            void GetToonLightMask(float3 normal, float3 viewDir, float3 lightDir, float atten, out float diffuseMask, out float specMask)
            {
                // Difuso con pasos
                float NdotL = dot(normal, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5; 
                float toonIntensity = floor(halfLambert * _Steps) / (_Steps - 1);
                diffuseMask = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, toonIntensity) * atten;

                // Especular nítido
                float3 H = normalize(viewDir + lightDir);
                float NdotH = max(0.0, dot(normal, H));
                float specIntensity = pow(NdotH, (1.0 - _Glossiness) * 128.0);
                specMask = smoothstep(0.5 - 0.01, 0.5 + 0.01, specIntensity) * _SpecIntensity * atten;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                
                // Acumuladores globales
                float totalDiffuseLight = 0.0;
                float3 totalSpecular = float3(0,0,0);
                float3 extraLightColorAdditive = float3(0,0,0);

                // ==========================================
                // 1. LUZ DIRECCIONAL (Base)
                // ==========================================
                float3 dirLightDir = normalize(-_DirLightDirection.xyz);
                float diffDir, specDir;
                GetToonLightMask(normal, viewDir, dirLightDir, 1.0, diffDir, specDir);
                
                totalDiffuseLight += diffDir;
                totalSpecular += specDir * _DirLightColor.rgb;

                // ==========================================
                // 2. LUZ PUNTUAL (Point Light)
                // ==========================================
                float3 pointLightVec = _PointLightPosition.xyz - i.worldPos;
                float pointDist = length(pointLightVec);
                float3 pointLightDir = normalize(pointLightVec);
                
                float pointAtten = saturate(1.0 - (pointDist / _PointLightRadius));
                pointAtten *= pointAtten; 
                
                float diffPoint, specPoint;
                GetToonLightMask(normal, viewDir, pointLightDir, pointAtten, diffPoint, specPoint);
                
                totalDiffuseLight += diffPoint; 
                totalSpecular += specPoint * _PointLightColor.rgb;
                // Guardamos el color de la luz para teñir las zonas iluminadas extra
                extraLightColorAdditive += diffPoint * _PointLightColor.rgb;

                // ==========================================
                // 3. LUZ FOCAL (Spot Light - CORREGIDA)
                // ==========================================
                // Vector que va de la LUZ al OBJETO
                float3 spotLightVec = i.worldPos - _SpotLightPosition.xyz; 
                float spotDist = length(spotLightVec);
                float3 dirToObj = normalize(spotLightVec);
                
                // Vector que va del OBJETO a la LUZ (para el cálculo de sombreado NdotL)
                float3 _SpotLightDirection = -dirToObj; 

                float spotDistAtten = saturate(1.0 - (spotDist / _SpotLightRange));
                spotDistAtten *= spotDistAtten;

                float3 currentSpotDir = normalize(_SpotLightDirection.xyz);
                
                // CORRECCIÓN: Comparamos la dirección del cono con el vector corregido hacia el objeto
                float cosAngle = dot(dirToObj, currentSpotDir);
                
                // Control del cono Toon
                float spotConeAtten = smoothstep(_SpotLightAngle - 0.05, _SpotLightAngle + 0.05, cosAngle);
                float spotAtten = spotDistAtten * spotConeAtten;

                float diffSpot, specSpot;
                GetToonLightMask(normal, viewDir, _SpotLightDirection, spotAtten, diffSpot, specSpot);
                
                totalDiffuseLight += diffSpot;
                totalSpecular += specSpot * _SpotLightColor.rgb;
                extraLightColorAdditive += diffSpot * _SpotLightColor.rgb;

                // ==========================================
                // COMPOSICIÓN FINAL DEL COLOR
                // ==========================================
                totalDiffuseLight = saturate(totalDiffuseLight);

                // Mezclamos la base de sombra y luz principal
                float3 baseDiffuse = lerp(_ShadowColor.rgb, _MainColor.rgb, totalDiffuseLight);
                
                // Añadimos el tinte de las luces extras (Point/Spot) de forma puramente aditiva
                float3 finalDiffuse = baseDiffuse + extraLightColorAdditive * _MainColor.rgb;

                // Efecto Rim 
                float rimDot = 1.0 - max(0.0, dot(normal, viewDir));
                float rimIntensity = pow(rimDot, _RimPower);
                rimIntensity = smoothstep(_RimThreshold - 0.05, _RimThreshold + 0.05, rimIntensity) * totalDiffuseLight;
                float3 finalRim = rimIntensity * _RimColor.rgb;

                // Multiplicamos por la luz ambiental/direccional general
                float3 finalColor = (finalDiffuse + totalSpecular + finalRim) * _DirLightColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}