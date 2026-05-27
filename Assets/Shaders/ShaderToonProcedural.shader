/*Shader "Custom/ShaderToonProcedural"
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

        [Header(Procedural Line Settings)]
        _OutlineColor ("Color de la Linea", Color) = (0, 0, 0, 1)
        _OutlineThickness ("Grosor de Linea", Range(0.0, 1.0)) = 0.4
        
        [Header(Directional Light Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)

        [Header(Point Light Setup)]
        _PointLightPos ("Point Light Position (XYZ)", Vector) = (0, 2, 0, 1)
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

            // Parámetros de la nueva línea fija
            float4 _OutlineColor;
            float _OutlineThickness;

            // Variables de Luces
            float4 _DirLightDirection;
            float4 _DirLightColor;

            float4 _PointLightPos;
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

            // Mantenemos intacta tu función de iluminación Toon por cada luz
            float3 CalculateToonLight(float3 normal, float3 viewDir, float3 lightDir, float3 lightColor, float atten)
            {
                float NdotL = dot(normal, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5; 
                
                float toonIntensity = floor(halfLambert * _Steps) / (_Steps - 1);
                toonIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, toonIntensity);
                
                float3 diffuseColor = lerp(_ShadowColor.rgb, _MainColor.rgb, toonIntensity * atten);

                float3 H = normalize(viewDir + lightDir);
                float NdotH = max(0.0, dot(normal, H));
                float specIntensity = pow(NdotH, (1.0 - _Glossiness) * 128.0);
                float specularToon = smoothstep(0.5 - 0.01, 0.5 + 0.01, specIntensity) * _SpecIntensity;
                float3 finalSpecular = specularToon * lightColor * atten;

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
                
                // ==========================================
                // NUEVO CÁLCULO DE LÍNEA FIJA POR DERIVADAS DE PANTALLA
                // ==========================================
                // Usamos fwidth para medir el cambio drástico de la normal en el espacio de la pantalla.
                // Esto detecta bordes filosos geométricos y siluetas de forma procedural e independiente de la distancia.
                float3 normalEdgeX = ddx(normal);
                float3 normalEdgeY = ddy(normal);
                float edgeDelta = length(normalEdgeX) + length(normalEdgeY);
                
                // Umbral adaptativo para pintar la línea fija nítida
                float outlineThreshold = (1.01 - _OutlineThickness) * 0.2;
                float outlineMask = step(edgeDelta, outlineThreshold);

                // ==========================================
                // CÁLCULO ACUMULADO DE LAS 3 LUCES
                // ==========================================
                float3 lightingColor = float3(0,0,0);

                // 1. Luz Direccional
                float3 dirLightDir = normalize(-_DirLightDirection.xyz);
                lightingColor += CalculateToonLight(normal, viewDir, dirLightDir, _DirLightColor.rgb, 1.0);

                // 2. Luz Puntual
                float3 pointLightVec = _PointLightPos.xyz - i.worldPos;
                float pointDist = length(pointLightVec);
                float3 pointLightDir = normalize(pointLightVec);
                float pointAtten = saturate(1.0 - (pointDist / _PointLightRadius));
                pointAtten *= pointAtten; 
                lightingColor += CalculateToonLight(normal, viewDir, pointLightDir, _PointLightColor.rgb, pointAtten);

                // 3. Luz Spot
                float3 spotLightVec = _SpotLightPos.xyz - i.worldPos;
                float spotDist = length(spotLightVec);
                float3 spotLightDir = normalize(spotLightVec);
                float spotDistAtten = saturate(1.0 - (spotDist / _SpotLightRange));
                spotDistAtten *= spotDistAtten;
                float3 currentSpotDir = normalize(_SpotLightDir.xyz);
                float cosAngle = dot(-spotLightDir, currentSpotDir);
                float spotConeAtten = smoothstep(_SpotLightAngle, _SpotLightAngle + 0.1, cosAngle);
                float spotAtten = spotDistAtten * spotConeAtten;
                lightingColor += CalculateToonLight(normal, viewDir, spotLightDir, _SpotLightColor.rgb, spotAtten);

                // ==========================================
                // MEZCLA FINAL
                // ==========================================
                float3 finalColor = lerp(_OutlineColor.rgb, lightingColor, outlineMask);

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}
*/
Shader "Custom/ShaderToonProcedural"
{
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color (Batik)", Color) = (0.2, 0.2, 0.4, 1) 
        
        [Header(Toon Settings)]
        _Steps ("Cantidad de Bandas de Luz", Range(1, 4)) = 2
        _ToonThreshold ("Umbral de Sombra", Range(0.0, 1.0)) = 0.4
        _ToonSmoothness ("Suavizado de Bordes", Range(0.001, 0.1)) = 0.01

        [Header(Batik Procedural Noise)]
        _BatikScale ("Escala de Manchas", Range(1.0, 100.0)) = 25.0
        _BatikIntensity ("Fuerza del Tenido", Range(0.0, 1.0)) = 0.6
        _BatikContrast ("Contraste de Manchas", Range(0.5, 4.0)) = 1.5

        [Header(Specular)]
        _Glossiness ("Tamano Brillo (Especular)", Range(0.01, 1.0)) = 0.1
        _SpecIntensity ("Intensidad Brillo", Range(0.0, 1.0)) = 0.5

        [Header(Rim Lighting)]
        _RimColor ("Color de Contorno Interior (Rim)", Color) = (1, 1, 1, 1)
        _RimPower ("Poder del Rim", Range(0.5, 8.0)) = 3.0
        _RimThreshold ("Umbral del Rim", Range(0.0, 1.0)) = 0.5
        
        [Header(Directional Light Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)

        [Header(Point Light Setup)]
        _PointLightPos ("Point Light Position (XYZ)", Vector) = (0, 2, 0, 1)
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

            // Parámetros del Batik Procedural
            float _BatikScale;
            float _BatikIntensity;
            float _BatikContrast;

            // Variables de Luces
            float4 _DirLightDirection;
            float4 _DirLightColor;

            float4 _PointLightPos;
            float4 _PointLightColor;
            float _PointLightRadius;

            float4 _SpotLightPos;
            float4 _SpotLightDir;
            float4 _SpotLightColor;
            float _SpotLightRange;
            float _SpotLightAngle;

            // --- Generador de Ruido Procedural Pseudo-Perlin de 3D para el efecto Batik ---
            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noiseProcedural(float3 x)
            {
                float3 p = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(lerp(hash(p + float3(0,0,0)), hash(p + float3(1,0,0)), f.x),
                                 lerp(hash(p + float3(0,1,0)), hash(p + float3(1,1,0)), f.x), f.y),
                            lerp(lerp(hash(p + float3(0,0,1)), hash(p + float3(1,0,1)), f.x),
                                 lerp(hash(p + float3(0,1,1)), hash(p + float3(1,1,1)), f.x), f.y), f.z);
            }

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return output;
            }

            // Función Toon modificada para inyectar la distorsión orgánica Batik
            float3 CalculateToonBatikLight(float3 normal, float3 viewDir, float3 lightDir, float3 lightColor, float atten, float batikNoise)
            {
                // 1. DIFUSO TOON CON INTERFERENCIA BATIK
                float NdotL = dot(normal, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5; 
                
                // Mezclamos la luz con el ruido matemático antes del escalonado (Cuantización)
                // Esto deforma la frontera de la sombra creando las "manchas de teñido"
                float lightWithNoise = lerp(halfLambert, halfLambert * batikNoise, _BatikIntensity);

                float toonIntensity = floor(lightWithNoise * _Steps) / (_Steps - 1);
                toonIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, toonIntensity);
                
                // Mezcla del color base y sombra distorsionada
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
                
                // ==========================================
                // GENERACIÓN DE LAS MANCHAS DE COLOR (Batik)
                // ==========================================
                // Usamos la posición del mundo multiplicada por la escala para que el patrón sea tridimensional y fijo sobre el modelo
                float3 batikCoords = i.worldPos * _BatikScale;
                float rawNoise = noiseProcedural(batikCoords);
                
                // Ajustamos el contraste del ruido para dar un look de manchas de tinta/cera líquida mas definido
                float batikPattern = saturate(pow(rawNoise, _BatikContrast) * 1.5);

                // ==========================================
                // CÁLCULO ACUMULADO DE LAS 3 LUCES (Con Sombreado Batik)
                // ==========================================
                float3 finalColor = float3(0,0,0);

                // 1. Luz Direccional
                float3 dirLightDir = normalize(-_DirLightDirection.xyz);
                finalColor += CalculateToonBatikLight(normal, viewDir, dirLightDir, _DirLightColor.rgb, 1.0, batikPattern);

                // 2. Luz Puntual
                float3 pointLightVec = _PointLightPos.xyz - i.worldPos;
                float pointDist = length(pointLightVec);
                float3 pointLightDir = normalize(pointLightVec);
                float pointAtten = saturate(1.0 - (pointDist / _PointLightRadius));
                pointAtten *= pointAtten; 
                finalColor += CalculateToonBatikLight(normal, viewDir, pointLightDir, _PointLightColor.rgb, pointAtten, batikPattern);

                // 3. Luz Spot
                float3 spotLightVec = _SpotLightPos.xyz - i.worldPos;
                float spotDist = length(spotLightVec);
                float3 spotLightDir = normalize(spotLightVec);
                float spotDistAtten = saturate(1.0 - (spotDist / _SpotLightRange));
                spotDistAtten *= spotDistAtten;
                float3 currentSpotDir = normalize(_SpotLightDir.xyz);
                float cosAngle = dot(-spotLightDir, currentSpotDir);
                float spotConeAtten = smoothstep(_SpotLightAngle, _SpotLightAngle + 0.1, cosAngle);
                float spotAtten = spotDistAtten * spotConeAtten;
                finalColor += CalculateToonBatikLight(normal, viewDir, spotLightDir, _SpotLightColor.rgb, spotAtten, batikPattern);

                // ==========================================
                // TINTE EXTRA AL COLOR GENERAL
                // ==========================================
                // Un sutil toque final que mezcla el patrón de manchas directamente sobre las texturas planas
                finalColor = lerp(finalColor, finalColor * _ShadowColor.rgb, (1.0 - batikPattern) * _BatikIntensity * 0.3);

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}