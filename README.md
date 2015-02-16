# Metal_ImageProcessing

A conversion to Swift of WWDC's example MetalImageProcessing.

This sample extends the textured quad sample by adding a Metal compute encoder to convert the image to greyscale. Note the compute encoder is part of the same pass as the render encoder and hence demonstrates how you can use the same shared CPU/GPU data across compute and rendering.

***


![](https://raw.githubusercontent.com/Jamnitzer/Metal_ImageProcessing/master/screen.png)
