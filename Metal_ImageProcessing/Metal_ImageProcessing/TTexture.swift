//------------------------------------------------------------------------------
//  Derived from Apple's WWDC example "MetalImageProcessing"
//  Created by Jim Wrenholt on 12/6/14.
//------------------------------------------------------------------------------
import Foundation
import UIKit
import Metal
import QuartzCore

//------------------------------------------------------------------------------
// Texture Loading classes for Metal.
// Includes examples of how to load a 2D, and Cubemap textures.
//------------------------------------------------------------------------------
class TTexture
{
    // Simple Utility class for creating a 2d texture
    var texture:MTLTexture?
    var width:Int = 0
    var height:Int = 0

    //------------------------------------------------------------
    init (device:MTLDevice, texStr:String, ext:String)
    {
        let path_str = texStr + "." + ext
        if let image = UIImage(named: path_str)
        {
            let imageRef = image.CGImage
            self.width = CGImageGetWidth(imageRef)
            self.height = CGImageGetHeight(imageRef)
            self.texture = textureForImage(image, device: device)
        }
    }
    //------------------------------------------------------------
}
//-----------------------------------------------------------------------------
//  TTexture.swift
//-----------------------------------------------------------------------------
func textureForImage(image:UIImage, device:MTLDevice) -> MTLTexture?
{
    let imageRef = image.CGImage

    let width = CGImageGetWidth(imageRef)
    let height = CGImageGetHeight(imageRef)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let rawData = calloc(height * width * 4, Int(sizeof(UInt8)))

    let bytesPerPixel: Int = 4
    let bytesPerRow: Int = bytesPerPixel * width
    let bitsPerComponent: Int = 8

    let options = CGImageAlphaInfo.PremultipliedLast.rawValue |
        CGBitmapInfo.ByteOrder32Big.rawValue

    let context = CGBitmapContextCreate(rawData,
        width,
        height,
        bitsPerComponent,
        bytesPerRow,
        colorSpace,
        options)

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0.0, CGFloat(height));
    CGContextScaleCTM(context, 1.0, -1.0);

    // Draw here
    CGContextDrawImage(context, CGRectMake(0, 0,
        CGFloat(width), CGFloat(height)), imageRef)

    CGContextRestoreGState(context);

    let textureDescriptor =
    MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm,
        width: Int(width),
        height: Int(height),
        mipmapped: true)
    let texture = device.newTextureWithDescriptor(textureDescriptor)

    let region = MTLRegionMake2D(0, 0, Int(width), Int(height))

    texture.replaceRegion(region,
        mipmapLevel: 0,
        slice: 0,
        withBytes: rawData,
        bytesPerRow: Int(bytesPerRow),
        bytesPerImage: Int(bytesPerRow * height))

    free(rawData)

    return texture
}
//------------------------------------------------------------------------------
