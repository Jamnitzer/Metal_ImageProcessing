//------------------------------------------------------------------------------
//  Derived from Apple's WWDC example "MetalImageProcessing"
//  Created by Jim Wrenholt on 12/6/14.
//------------------------------------------------------------------------------
import UIKit
import Metal
import QuartzCore
import Foundation

// Keys for setting or getting indices
let kQuadIndexKeyVertex = UInt8(0)
let kQuadIndexKeyTexCoord = UInt8(1)
let kQuadIndexKeySampler = UInt8(2)
let kQuadIndexMax = UInt8(3)

//------------------------------------------------------------------------------
let kCntQuadTexCoords:Int = 6
let kSzQuadTexCoords:Int = kCntQuadTexCoords * sizeof(Float) * 2
let kCntQuadVertices:Int = kCntQuadTexCoords
let kSzQuadVertices:Int = kCntQuadVertices * sizeof(Float) * 4

//------------------------------------------------------------------------------
let kQuadVertices:[V4f] = [
    V4f(-1.0, -1.0, 0.0, 1.0 ),
    V4f( 1.0, -1.0, 0.0, 1.0 ),
    V4f(-1.0,  1.0, 0.0, 1.0 ),

    V4f( 1.0, -1.0, 0.0, 1.0 ),
    V4f(-1.0,  1.0, 0.0, 1.0 ),
    V4f( 1.0,  1.0, 0.0, 1.0 )  ]
//------------------------------------------------------------------------------
let kQuadTexCoords:[V2f] = [
    V2f(0.0, 0.0 ),
    V2f(1.0, 0.0 ),
    V2f(0.0, 1.0 ),

    V2f(1.0, 0.0 ),
    V2f(0.0, 1.0 ),
    V2f(1.0, 1.0 )  ]
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
class TQuad
{
    //-------------------------------------------------------------------------
    // Utility class for creating a quad.
    //-------------------------------------------------------------------------
    // Indices
    var mVertexIndex:Int = 0
    var mTexCoordIndex:Int = 1
    var mSamplerIndex:Int = 0

    // Dimensions
    var size = CGSizeMake(0, 0)          // Get the quad size
    var bounds = CGRectMake(0, 0, 0, 0)  // Get the bounding view rectangle
    var aspect = Float(1.0)              // Get the aspect ratio

    // textured Quad
    var m_VertexBuffer:MTLBuffer? = nil
    var m_TexCoordBuffer:MTLBuffer? = nil

    // Scale
    var m_Scale = V2f(1.0, 1.0)

    //-------------------------------------------------------------------------
    // Designated initializer
    //-------------------------------------------------------------------------
    init(device:MTLDevice)
    {
        m_VertexBuffer = device.newBufferWithBytes(
            UnsafePointer<Void>(kQuadVertices),
            length: kSzQuadVertices,
            options: MTLResourceOptions.OptionCPUCacheModeDefault)

        if (m_VertexBuffer == nil)
        {
            print(">> ERROR: Failed creating a vertex buffer for a quad!")
            return
        }
        m_VertexBuffer!.label = "quad vertices"

        m_TexCoordBuffer = device.newBufferWithBytes(
            UnsafePointer<Void>(kQuadTexCoords),
                            length: kSzQuadTexCoords,
            options: MTLResourceOptions.OptionCPUCacheModeDefault)

        if (m_TexCoordBuffer == nil)
        {
            print(">> ERROR: Failed creating a 2d texture coordinate buffer!")
            return
        }
        m_TexCoordBuffer!.label = "quad texcoords"
    }
    //-------------------------------------------------------------------------
    func setBounds(bounds:CGRect)
    {
        self.bounds = bounds
        self.aspect = Float(abs(bounds.size.width / bounds.size.height))
        let Aspect:Float = 1.0 / self.aspect

        let scale = V2f(
                    Aspect * Float(self.size.width / bounds.size.width),
                             Float(self.size.height / bounds.size.height ))

        //--------------------------------------------------
        // Did the scaling factor change
        //--------------------------------------------------
        let bNewScale:Bool = (scale.x != m_Scale.x) || (scale.y != m_Scale.y)

        //--------------------------------------------------
        // Set the (x, y) bounds of the quad
        //--------------------------------------------------
       if (bNewScale)
        {
            //--------------------------------------------------
            // Update the scaling factor
            //--------------------------------------------------
            m_Scale = scale

            //--------------------------------------------------
            // Update the vertex buffer with the quad bounds
            //--------------------------------------------------
            let pVertices =
            UnsafeMutablePointer<V4f>(m_VertexBuffer!.contents())

            if (pVertices != nil)
            {
                // First triangle
                pVertices[0].x = -m_Scale.x
                pVertices[0].y = -m_Scale.y

                pVertices[1].x = +m_Scale.x
                pVertices[1].y = -m_Scale.y

                pVertices[2].x = -m_Scale.x
                pVertices[2].y = +m_Scale.y

                // Second triangle
                pVertices[3].x = +m_Scale.x
                pVertices[3].y = -m_Scale.y

                pVertices[4].x = -m_Scale.x
                pVertices[4].y = +m_Scale.y

                pVertices[5].x = +m_Scale.x
                pVertices[5].y = +m_Scale.y
            }
        }
    }
    //-------------------------------------------------------------------------
    func encode(renderEncoder:MTLRenderCommandEncoder)
    {
        if (m_VertexBuffer == nil)
        {
            print("m_VertexBuffer == nil")
        }
        if (m_TexCoordBuffer == nil)
        {
            print("m_TexCoordBuffer == nil")
        }

        renderEncoder.setVertexBuffer(
            m_VertexBuffer!,
            offset: Int(0),
            atIndex: Int(mVertexIndex) )

        renderEncoder.setVertexBuffer(
            m_TexCoordBuffer!,
            offset: Int(0),
            atIndex: Int(mTexCoordIndex) )

    } // encode
    //-------------------------------------------------------------------------
}
////------------------------------------------------------------------------------
