Shader "Custom/ToonShader_Procedural"
{
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.4, 1)
        
        [Header(Toon Settings)]
        _Steps ("Cantidad de Bandas de Luz", Range(1, 4)) = 2
        _ToonThreshold ("Umbral de Sombra", Range(0.0, 1.0)) = 0.4
        _ToonSmoothness ("Suavizado de Bordes", Range(0.001, 0.1)) = 0.01

        [Header(Procedural Lines)]
        _LineDensity ("Densidad de Lineas", Range(10, 200)) = 100
        _LineThickness ("Grosor Maximo de Linea", Range(0.0, 1.0)) = 0.5
        _LineColor ("Color de las Lineas", Color) = (0, 0, 0, 1)

        [Header(Specular)]
        _Glossiness ("Tamaño Brillo (Especular)", Range(0.01, 1.0)) = 0.1
        _SpecIntensity ("Intensidad Brillo", Range(0.0, 1.0)) = 0.5

        [Header(Rim Lighting)]
        _RimColor ("Color de Contorno Interior (Rim)", Color) = (1, 1, 1, 1)
        _RimPower ("Poder del Rim", Range(0.5, 8.0)) = 3.0
        _RimThreshold ("Umbral del Rim", Range(0.0, 1.0)) = 0.5

        [Header(Outline)]
        _OutlineColor ("Color de la Linea de Contorno", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Grosor de la Linea", Range(0.0, 0.1)) = 0.015
        
        [Header(Lights Setup)]
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        // --- PASS 1: EL OUTLINE (Bordes externos fijados) ---
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

        // --- PASS 2: SOMBREADO CEL + LINEAS PROCEDURALES ---
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
                float4 screenPos : TEXCOORD2; // Necesario para las líneas proyectadas en pantalla
            };

            float4 _MainColor;
            float4 _ShadowColor;
            float _Steps;
            float _ToonThreshold;
            float _ToonSmoothness;
            
            float _LineDensity;
            float _LineThickness;
            float4 _LineColor;

            float _Glossiness;
            float _SpecIntensity;

            float4 _RimColor;
            float _RimPower;
            float _RimThreshold;

            float4 _DirLightDirection;
            float4 _DirLightColor;

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // Calculamos la posición en pantalla del píxel
                output.screenPos = ComputeScreenPos(output.position);
                return output;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 lightDir = normalize(-_DirLightDirection.xyz);

                // 1. DIFUSO TOON BASE
                float NdotL = dot(normal, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5; 
                
                float toonIntensity = floor(halfLambert * _Steps) / (_Steps - 1);
                toonIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, toonIntensity);
                
                float3 baseDiffuse = lerp(_ShadowColor.rgb, _MainColor.rgb, toonIntensity);

                // 2. PATRÓN DE LÍNEAS PROCEDURALES (Efecto Manga / Hatching)
                // Coordenadas UV de la pantalla para que las líneas mantengan un tamaño uniforme sin importar la distancia
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                screenUV.x *= (_ScreenParams.x / _ScreenParams.y); // Corrección de aspecto (evita que se estiren)

                // Rotamos 45 grados las coordenadas para crear líneas diagonales profesionales
                float2 rotatedUV = float2(
                    screenUV.x * 0.7071 - screenUV.y * 0.7071,
                    screenUV.x * 0.7071 + screenUV.y * 0.7071
                );

                // Generamos una onda senoidal procedural repetitiva basada en la densidad
                float linePattern = sin(rotatedUV.x * _LineDensity);
                // Remapeamos el seno de [-1, 1] a [0, 1]
                linePattern = linePattern * 0.5 + 0.5;

                // El grosor dinámico: a menos luz (halfLambert bajo), las líneas se vuelven más gruesas
                float dynamicThickness = (1.0 - halfLambert) * _LineThickness;

                // Umbral nítido para dibujar la línea física usando un smoothstep corto (evita aliasing)
                float lineMask = smoothstep(dynamicThickness - 0.02, dynamicThickness + 0.02, linePattern);

                // Mezclamos el color base difuso con el color de las líneas usando la máscara
                float3 finalDiffuse = lerp(_LineColor.rgb, baseDiffuse, lineMask);

                // 3. ESPECULAR ANIME
                float3 H = normalize(viewDir + lightDir);
                float NdotH = max(0.0, dot(normal, H));
                float specIntensity = pow(NdotH, (1.0 - _Glossiness) * 128.0);
                float specularToon = smoothstep(0.5 - 0.01, 0.5 + 0.01, specIntensity) * _SpecIntensity;
                float3 finalSpecular = specularToon * _DirLightColor.rgb;

                // 4. RIM LIGHTING
                float rimDot = 1.0 - max(0.0, dot(normal, viewDir));
                float rimIntensity = pow(rimDot, _RimPower);
                rimIntensity = smoothstep(_RimThreshold - 0.05, _RimThreshold + 0.05, rimIntensity) * max(0.0, NdotL);
                float3 finalRim = rimIntensity * _RimColor.rgb;

                // Combinación final total
                float3 finalColor = (finalDiffuse + finalSpecular + finalRim) * _DirLightColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}