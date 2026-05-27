using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ControladorLuzPuntual : MonoBehaviour
{
    public Material[] Materiales_De_La_Escena_Luz_Puntual ;

    // Start is called before the first frame update
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
    }
}