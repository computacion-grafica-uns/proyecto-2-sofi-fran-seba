Shader "Custom/ShaderPhongActividad"
{
    Properties
    {
        _MaterialColor ("Color del Objeto", Color) = (1,1,1,1)
        _SpecularColor ("Color del Brillo (Ks)", Color) = (1,1,1,1)
        _Shininess ("Exponente (n)", Range(1, 128)) = 32
        
        _PointLightPos ("Posición de la Luz (Ip)", Vector) = (0, 3, 0, 1)
        _AmbientIntensity ("Intensidad Ambiente (Ia)", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _MaterialColor, _SpecularColor, _PointLightPos;
            float _Shininess, _AmbientIntensity;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 normalWorld : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float3 N = normalize(i.normalWorld);
                float3 toLight = _PointLightPos.xyz - i.worldPos;
                float dist = length(toLight);
                float3 L = normalize(toLight);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                // --- 1. FACTOR DE ATENUACIÓN (fat) ---
                // Como pide la fórmula: Ip * fat
                float fat = 1.0 / (1.0 + dist * 0.5); 

                // --- 2. AMBIENTE (Ka * Ia) ---
                float3 ambient = _AmbientIntensity * _MaterialColor.rgb;

                // --- 3. DIFUSA (Kd * fat * Ip * (L.N)) ---
                float diff = max(0, dot(N, L));
                float3 diffuse = _MaterialColor.rgb * fat * diff;

                // --- 4. ESPECULAR (Ks * fat * Ip * (R.V)^n) ---
                float3 R = reflect(-L, N);
                float spec = pow(max(0, dot(R, V)), _Shininess);
                float3 specular = _SpecularColor.rgb * fat * spec;

                // --- SUMA FINAL ---
                fixed4 fragColor = 1;
                fragColor.rgb = ambient + diffuse + specular;
                return fragColor;
            }
            ENDCG
        }
    }
}
