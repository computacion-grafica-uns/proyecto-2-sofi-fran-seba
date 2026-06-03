using System.Collections.Generic;
using UnityEngine;

public class ControladorLucesMateriales : MonoBehaviour
{
    [Header("Configuración de Materiales")]
    [SerializeField] private List<Material> materialesDeLaEscena = new List<Material>();

    [Header("Estado de la Luz")]
    [SerializeField] private Color colorEncendido = Color.white;
    private bool luzEstaEncendida = true;

    void Update()
    {
        // Detecta la tecla presionada
        if (Input.GetKeyDown(KeyCode.F1))
        {
            AlternarLuzDireccional();
        }
    }

    private void AlternarLuzDireccional()
    {
        // Invertimos el estado de la luz
        luzEstaEncendida = !luzEstaEncendida;

        // Definimos qué color mandar según el estado actual
        Color colorAEnviar = luzEstaEncendida ? colorEncendido : Color.black;

        // Recorremos la lista de materiales y actualizamos la propiedad del shader
        foreach (Material mat in materialesDeLaEscena)
        {
            if (mat != null)
            {
                // _DirLightColor es el nombre exacto de la variable en tus shaders Toon
                mat.SetColor("_DirLightColor", colorAEnviar);
            }
        }

        // Feedback opcional en la consola para saber si funcionó
        Debug.Log("-Luz Direccional: " + (luzEstaEncendida ? "ENCENDIDA" : "APAGADA"));
    }
}