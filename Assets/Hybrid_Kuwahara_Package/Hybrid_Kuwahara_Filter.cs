using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class Hybrid_Kuwahara_Filter : MonoBehaviour
{
    [SerializeField] private Shader shader;

    [SerializeField] [Range(1,20)] private int radiusSize = 1;
    [SerializeField] private bool radius2X = false;
    private int isRadius2X;

    [SerializeField][Range(1, 9.5f)] private float sharpness = 10;

    [SerializeField][Range(1, 3)] private int overlapSlider = 0;

    [SerializeField] private bool lineArt = false;
    [SerializeField][Range(0, 5)] private float lineArtIntensity = 1;

    private Material material;

    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(material!=null)
        {
            Graphics.Blit(source, destination, material);
        }
    }


    private void Update()
    {
        isRadius2X = (radius2X) ? 1 : 0;
        setShaderMaterial();
        setShaderProperties();
    }

    private void setShaderMaterial()
    {
        if(this.shader!=null)
        {
            this.material = new Material(shader);
        }
    }

    private void setShaderProperties()
    {
        material.SetInt("_KernelSize", radiusSize + radiusSize * isRadius2X + 1);
        material.SetFloat("_Sharpness", sharpness);
        material.SetFloat("_Overlap", Mathf.Pow(2, overlapSlider) * 0.1f + 0.01f);
        material.SetFloat("_Scaling", (lineArt) ? lineArtIntensity : 0);
    }


}
