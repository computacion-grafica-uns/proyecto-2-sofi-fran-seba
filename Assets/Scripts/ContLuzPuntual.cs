using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ControladorLuzPuntual : MonoBehaviour
{
    public Material[] Materiales_De_La_Escena_Luz_Puntual ;

    [Header("Estado de la Luz")]
    [SerializeField] private Color colorEncendido = new Color(255f / 255f, 197f / 255f, 143f / 255f); //Color calido
    private bool luzEstaEncendida = true;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        foreach (Material mat in Materiales_De_La_Escena_Luz_Puntual)
        {
            mat.SetVector("_PointLightPosition", transform.position);
        }

        // Detecta la tecla presionada
        if (Input.GetKeyDown(KeyCode.F2))
        {
            AlternarLuzPuntual();
        }
    }

    private void AlternarLuzPuntual()
    {
        // Invertimos el estado de la luz
        luzEstaEncendida = !luzEstaEncendida;

        // Definimos qué color mandar según el estado actual
        Color colorAEnviar = luzEstaEncendida ? colorEncendido : Color.black;

        // Recorremos la lista de materiales y actualizamos la propiedad del shader
        foreach (Material mat in Materiales_De_La_Escena_Luz_Puntual)
        {
            if (mat != null)
            {
                // _DirLightColor es el nombre exacto de la variable en tus shaders Toon
                mat.SetColor("_PointLightColor", colorAEnviar);
            }
        }

        // Feedback opcional en la consola para saber si funcionó
        Debug.Log("-Luz Puntual: " + (luzEstaEncendida ? "ENCENDIDA" : "APAGADA"));
    }   
}