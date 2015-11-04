//------------------------------------------------------------------------------
//  Derived from Apple's WWDC example "MetalImageProcessing"
//  Created by Jim Wrenholt on 12/6/14.
//------------------------------------------------------------------------------
import Foundation
import UIKit
import Metal

let kInFlightCommandBuffers = Int(3)
let kSzBufferLimitsPerFrame = sizeof(Float)*16
let kSzSIMDFloat4x4 = UInt(sizeof(Float)*16)

let kUIInterfaceOrientation_LandscapeAngle = Float(35.0)
let kUIInterfaceOrientation_PortraitAngle = Float(50.0)

let kPrespectiveNear = Float(0.1)
let kPrespectiveFar = Float(100.0)

//------------------------------------------------------------------------------
class TRenderer : TViewControllerDelegate, TViewDelegate
{
    // Interface Orientation
    var mnOrientation = UIInterfaceOrientation.Unknown

    // Renderer globals
    var m_CommandQueue:MTLCommandQueue? = nil
    var m_ShaderLibrary:MTLLibrary? = nil
    var m_DepthState:MTLDepthStencilState? = nil

    //  Compute ivars
    var m_Kernel:MTLComputePipelineState? = nil
    var m_WorkgroupSize:MTLSize
    var m_LocalCount:MTLSize

    //  textured Quad
    var m_InTexture:TTexture? = nil
    var m_OutTexture:MTLTexture? = nil
    var m_PipelineState:MTLRenderPipelineState? = nil

    //  Quad representation
    var m_Quad:TQuad? = nil

    //  App control
    var m_InflightSemaphore:dispatch_semaphore_t

    //  Dimensions
    var m_Size:CGSize

    //  Viewing matrix is derived from an eye point, a reference point
    //  indicating the center of the scene, and an up vector.
    var m_LookAt:M4f

    //  Translate the object in (x, y, z) space.
    var m_Translate:M4f

    //  Quad transform buffers
    var m_Transform:M4f
    var m_TransformBuffer:MTLBuffer? = nil

    // renderer will create a default device at init time.
    var device:MTLDevice? = nil

    // this value will cycle from 0 to g_max_inflight_buffers
    // whenever a display completes ensuring renderer clients
    // can synchronize between g_max_inflight_buffers count buffers,
    // and thus avoiding a constant buffer from being overwritten between draws
    var constantDataBufferIndex:UInt

    // These queries exist so the View can initialize a framebuffer
    // that matches the expectations of the renderer
    var depthPixelFormat:MTLPixelFormat
    var stencilPixelFormat:MTLPixelFormat
    var sampleCount:Int

    //-------------------------------------------------------------------------
    init()
    {
        //-----------------------------------------------------
        // initialize properties
        //-----------------------------------------------------
        sampleCount = 1
        depthPixelFormat = MTLPixelFormat.Depth32Float
        stencilPixelFormat = MTLPixelFormat.Invalid
        constantDataBufferIndex = 0

        //-----------------------------------------------------
        m_WorkgroupSize = MTLSizeMake(1, 1, 1)
        m_LocalCount = MTLSizeMake(1, 1, 1)
        m_Size = CGSizeMake(0, 0)

        m_LookAt = M4f()
        m_Translate = M4f()
        m_Transform = M4f()
        
        //-----------------------------------------------------
        // create a default system device
        //-----------------------------------------------------
        device = MTLCreateSystemDefaultDevice()
        if (device == nil)
        {
            //-----------------------------------------------------
            // assert here becuase if the default system device isn't
            // created, then we shouldn't continue
            //-----------------------------------------------------
            assert(false, ">> ERROR: Failed creating a device!")
        }

        //-----------------------------------------------------
        // create a new command queue
        //-----------------------------------------------------
        m_CommandQueue = device!.newCommandQueue()
        if (m_CommandQueue == nil)
        {
            //-----------------------------------------------------
            // assert here becuase if the command queue isn't created,
            // then we shouldn't continue
            //-----------------------------------------------------
            assert(false, ">> ERROR: Failed creating a command queue!")
        }

        m_ShaderLibrary = device!.newDefaultLibrary()
        if (m_ShaderLibrary == nil)
        {
            //-----------------------------------------------------
            // assert here becuase if the shader libary isn't loading,
            // then we shouldn't contiue
            //-----------------------------------------------------
            assert(false, ">> ERROR: Failed creating a default shader library!")
        }

        m_InflightSemaphore = dispatch_semaphore_create(kInFlightCommandBuffers)
    }
    //-------------------------------------------------------------------------
    func cleanup()
    {
        m_PipelineState = nil
        m_Kernel = nil
        m_ShaderLibrary = nil
        m_TransformBuffer = nil
        m_DepthState = nil
        m_CommandQueue = nil
        m_OutTexture = nil

        m_InTexture = nil
        m_Quad = nil
    }
    //-------------------------------------------------------------------------
    // mark Setup
    //-------------------------------------------------------------------------
    func configure(view:TView)
    {
        view.depthPixelFormat = depthPixelFormat
        view.stencilPixelFormat = stencilPixelFormat
        view.sampleCount = sampleCount
        
        //-----------------------------------------------------
        // we need to set the framebuffer only property of the layer to NO so we
        // can perform compute on the drawable's texture
        //-----------------------------------------------------
        let metalLayer:CAMetalLayer = view.layer as! CAMetalLayer
            metalLayer.framebufferOnly = false

        if !preparePipelineState()
        {
            assert(false, ">> ERROR: Failed creating a depth stencil state descriptor!")
        }
        if !prepareTexturedQuad("Default", ext:"jpg")
        {
            assert(false, ">> ERROR: Failed creating a textured quad!")
        }
        if !prepareCompute()
        {
            assert(false, ">> ERROR: Failed creating a compute stage!")
        }
        if !prepareDepthStencilState()
        {
            assert(false, ">> ERROR: Failed creating a depth stencil state!")
        }
        if !prepareTransformBuffer()
        {
            assert(false, ">> ERROR: Failed creating a transform buffer!")
        }

        //-----------------------------------------------------
        // Default orientation is unknown
        //-----------------------------------------------------
        mnOrientation = UIInterfaceOrientation.Unknown

        //-----------------------------------------------------
        // Create linear transformation matrices
        //-----------------------------------------------------
        prepareTransforms()
    }
    //-------------------------------------------------------------------------
    func prepareCompute() -> Bool
    {
        //-----------------------------------------------------
        // Create a compute kernel function
        //-----------------------------------------------------
        let function:MTLFunction? =
            m_ShaderLibrary!.newFunctionWithName("grayscale")
        if (function == nil)
        {
            print(">> ERROR: Failed creating a new function!")
        }

        //-----------------------------------------------------
        // Create a compute kernel
        //-----------------------------------------------------
        do {
            m_Kernel = try device!.newComputePipelineStateWithFunction(function!)
        }
        catch let pipelineError as NSError
        {
            m_Kernel = nil
            print("Failed creating a compute kernel:  \( pipelineError ) ")
            return false
        }


//        var kernel_err:NSError?
//        m_Kernel = device!.newComputePipelineStateWithFunction(function!,
//            error: &kernel_err)
//        if (m_Kernel == nil)
//        {
//            print(">> ERROR: Failed creating a compute kernel: ")
//            if (kernel_err != nil)
//            {
//                print(": \(kernel_err!)")
//            }
//            return false
//        }

        let pTexDesc = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            MTLPixelFormat.RGBA8Unorm,
            width:Int(m_Size.width),
            height:Int(m_Size.height),
            mipmapped:false)

        //if (pTexDesc == nil)
        //{
        //  println(">> ERROR: Failed creating a texture 2d descriptor with RGBA unnormalized pixel format!")
        //  return false
        //}

        m_OutTexture = device!.newTextureWithDescriptor(pTexDesc)
        if (m_OutTexture == nil)
        {
            print(">> ERROR: Failed creating an output 2d texture!")
            return false
        }

        //-----------------------------------------------------
        // Set the compute kernel's workgroup size and count
        //-----------------------------------------------------
        m_WorkgroupSize = MTLSizeMake(1, 1, 1)
        m_LocalCount = MTLSizeMake(Int(m_Size.width), Int(m_Size.height), 1)
        return true
    }
    //-------------------------------------------------------------------------
    func preparePipelineState() -> Bool
    {
        //-----------------------------------------------------
        // get the fragment function from the library
        //-----------------------------------------------------
        let fragmentProgram:MTLFunction? =
                m_ShaderLibrary!.newFunctionWithName("texturedQuadFragment")
        if (fragmentProgram == nil)
        {
            print(">> ERROR: Couldn't load fragment function from default library")
        }
        //-----------------------------------------------------
        // get the vertex function from the library
        //-----------------------------------------------------
        let vertexProgram = m_ShaderLibrary!.newFunctionWithName("texturedQuadVertex")
        if (vertexProgram == nil)
        {
            print(">> ERROR: Couldn't load vertex function from default library")
        }
        //-----------------------------------------------------
        // create a pipeline state for the quad
        //-----------------------------------------------------
        let pQuadStateDesc = MTLRenderPipelineDescriptor()
        //if (pQuadStateDesc == nil)
        //{
        //  println(">> ERROR: Failed creating a pipeline state descriptor!")
        //  return false
        //}

        pQuadStateDesc.depthAttachmentPixelFormat = depthPixelFormat
        pQuadStateDesc.stencilAttachmentPixelFormat = MTLPixelFormat.Invalid
        pQuadStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormat.BGRA8Unorm
        pQuadStateDesc.sampleCount = sampleCount
        pQuadStateDesc.vertexFunction = vertexProgram!
        pQuadStateDesc.fragmentFunction = fragmentProgram!

        do {
            self.m_PipelineState = try
                device!.newRenderPipelineStateWithDescriptor(pQuadStateDesc)
        }
        catch let pipelineError as NSError
        {
            self.m_PipelineState = nil
            print("Failed acquiring pipeline state \(pipelineError)")
            return false
        }


//        var pipeline_err:NSError?
//        m_PipelineState = device!.newRenderPipelineStateWithDescriptor(
//            pQuadStateDesc, error: &pipeline_err) // error:&pError]
//
//        if (m_PipelineState == nil)
//        {
//            print(">> ERROR: Failed acquiring pipeline state descriptor: \(pipeline_err)")
//            return false
//        }

        return true
    }
    //-------------------------------------------------------------------------
    func prepareDepthStencilState() -> Bool
    {
        let pDepthStateDesc:MTLDepthStencilDescriptor? = MTLDepthStencilDescriptor()
        if (pDepthStateDesc == nil)
        {
            print(">> ERROR: Failed creating a depth stencil descriptor!")
            return false
        }

        pDepthStateDesc!.depthCompareFunction = MTLCompareFunction.Always
        pDepthStateDesc!.depthWriteEnabled = true

        m_DepthState = device!.newDepthStencilStateWithDescriptor(pDepthStateDesc!)
        if (m_DepthState == nil)
        {
            return false
        }
        return true
    }
    //-------------------------------------------------------------------------
    func prepareTexturedQuad(texStr:String, ext:String) -> Bool
    {
        //-------------------------------------------------------
        m_InTexture = TTexture(device: device!, texStr: texStr, ext: ext)
        m_InTexture!.texture!.label = texStr

        m_Size.width = CGFloat(m_InTexture!.width)
        m_Size.height = CGFloat(m_InTexture!.height)

        //-------------------------------------------------------
        m_Quad = TQuad(device: device!)
        if (m_Quad == nil)
        {
            print(">> ERROR: Failed creating a quad object!")
            return false
        }
        m_Quad!.size = m_Size
        //-------------------------------------------------------
        return true
    }
    //-------------------------------------------------------------------------
    func prepareTransformBuffer() -> Bool
    {
        //-----------------------------------------------------
        // allocate regions of memory for the constant buffer
        //-----------------------------------------------------
        m_TransformBuffer = device!.newBufferWithLength(kSzBufferLimitsPerFrame,
            options:MTLResourceOptions.OptionCPUCacheModeDefault)
        if (m_TransformBuffer == nil)
        {
            return false
        }
        m_TransformBuffer!.label = "TransformBuffer"
        return true
    }
    //-------------------------------------------------------------------------
    func prepareTransforms()
    {
        //-----------------------------------------------------
        // Create a viewing matrix derived from an eye point, a reference point
        // indicating the center of the scene, and an up vector.
        //-----------------------------------------------------
        let eye = V3f(0, 0, 0)
        let center = V3f(0, 0, 1)
        let up = V3f(0, 1, 0)
        self.m_LookAt = lookAt(eye, center: center, up: up)

        //-----------------------------------------------------
        // Translate the object in (x, y, z) space.
        //-----------------------------------------------------
        self.m_Translate = M4f.TranslationMatrix(V3f(0, -0.25, 2.0))
    }
    //-------------------------------------------------------------------------
    // mark Render
    //-------------------------------------------------------------------------
    func compute(commandBuffer:MTLCommandBuffer)
    {
        let computeEncoder:MTLComputeCommandEncoder? =
            commandBuffer.computeCommandEncoder()

        if (computeEncoder != nil)
        {
            computeEncoder!.setComputePipelineState(m_Kernel!)
            computeEncoder!.setTexture(m_InTexture!.texture, atIndex:0)
            computeEncoder!.setTexture(m_OutTexture!, atIndex:1)

            computeEncoder!.dispatchThreadgroups(m_LocalCount,
                threadsPerThreadgroup:m_WorkgroupSize)
            computeEncoder!.endEncoding()
        }
    }
    //-------------------------------------------------------------------------
    func encode(renderEncoder:MTLRenderCommandEncoder)
    {
        assert(m_DepthState != nil, "m_DepthState == nil")
        assert(m_PipelineState != nil, "m_PipelineState == nil")
        assert(m_TransformBuffer != nil, "m_TransformBuffer == nil")
        assert(m_OutTexture != nil, "m_OutTexture == nil")

        //-----------------------------------------------------
        // set context state with the render encoder
        //-----------------------------------------------------
        renderEncoder.pushDebugGroup("encode quad")

        renderEncoder.setFrontFacingWinding(MTLWinding.CounterClockwise)
        renderEncoder.setDepthStencilState(m_DepthState!)
        renderEncoder.setRenderPipelineState(m_PipelineState!)

        //-----------------------------------------------------
        // Encode quad vertex and texture coordinate buffers
        //-----------------------------------------------------
        m_Quad!.encode(renderEncoder)
        renderEncoder.setVertexBuffer(m_TransformBuffer!, offset:0, atIndex:2)
        renderEncoder.setFragmentTexture(m_OutTexture!, atIndex:0)

        //-----------------------------------------------------
        // tell the render context we want to draw our primitives
        //-----------------------------------------------------
        renderEncoder.drawPrimitives(MTLPrimitiveType.Triangle,
            vertexStart:0,
            vertexCount:6,
            instanceCount:1)

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    //-------------------------------------------------------------------------
    //-------------------------------------------------------------------------
    @objc func reshape(view:TView)
    {
        //-----------------------------------------------------
        // To correctly compute the aspect ration determine
        // the device interface orientation.
        //-----------------------------------------------------
        let orientation =
        UIApplication.sharedApplication().statusBarOrientation

        //-----------------------------------------------------
        // Update the quad and linear _transformation matrices,
        // if and only if, the device orientation is changed.
        //-----------------------------------------------------
        if (mnOrientation != orientation)
        {
            //-----------------------------------------------------
            // Update the device orientation
            //-----------------------------------------------------
            mnOrientation = orientation

            //-----------------------------------------------------
            // Get the bounds for the current rendering layer
            //-----------------------------------------------------
            // m_Quad!.bounds = view.layer.frame
            m_Quad!.setBounds( view.layer.frame)

            //-----------------------------------------------------
            // Based on the device orientation, set the angle in 
            // degrees between a plane which passes through the 
            // camera position and the top of your screen and 
            // another plane which passes through the camera 
            // position and the bottom of your screen.
            //-----------------------------------------------------
            var dangle = Float(0.0)

            switch (mnOrientation)
            {
            case .LandscapeLeft:
                dangle = kUIInterfaceOrientation_LandscapeAngle
            case .LandscapeRight:
                dangle = kUIInterfaceOrientation_LandscapeAngle
            case .Portrait:
                dangle = kUIInterfaceOrientation_PortraitAngle
            case .PortraitUpsideDown:
                dangle = kUIInterfaceOrientation_PortraitAngle
            case .Unknown:
                break
            }
            //-----------------------------------------------------
            // Describes a tranformation matrix that produces 
            // a perspective projection
            //-----------------------------------------------------
            let near:Float = kPrespectiveNear
            let far:Float = kPrespectiveFar
            let rangle:Float = DEG2RAD(dangle)
            //-----------------------------------------------------
            let length:Float = near * tan(rangle)
            let right:Float = length / m_Quad!.aspect
            let left:Float = -right
            let top:Float = length
            let bottom:Float = -top

            let perspective = frustum_oc(left, right: right, bottom: bottom, top: top, near: near, far: far)
            //-----------------------------------------------------
            // Create a viewing matrix derived from an eye point, 
            // a reference point indicating the center of the scene, 
            // and an up vector.
            //-----------------------------------------------------
            m_Transform = m_LookAt * m_Translate

            //-----------------------------------------------------
            // Create a linear _transformation matrix
            //-----------------------------------------------------
            m_Transform = perspective * m_Transform

            //-----------------------------------------------------
            // Update the buffer associated with the linear 
            // transformation matrix
            //-----------------------------------------------------
            var pTransform:UnsafeMutablePointer<Void>?
                pTransform = m_TransformBuffer?.contents()

            memcpy(pTransform!, m_Transform.mat, Int(kSzSIMDFloat4x4))
        }
    }
    //-------------------------------------------------------------------------
    @objc func render(view:TView)
    {
        dispatch_semaphore_wait(m_InflightSemaphore, DISPATCH_TIME_FOREVER)

        let commandBuffer = m_CommandQueue!.commandBuffer()

        //-----------------------------------------------------
        // compute image processing on the (same) drawable texture
        //-----------------------------------------------------
        compute(commandBuffer)

        //-----------------------------------------------------
        // create a render command encoder 
        // so we can render into something
        //-----------------------------------------------------
        let renderPassDescriptor:MTLRenderPassDescriptor? =
            view.renderPassDescriptor()

        if (renderPassDescriptor != nil)
        {
            //-----------------------------------------------------
            // Get a render encoder
            //-----------------------------------------------------
            let renderEncoder =
                commandBuffer.renderCommandEncoderWithDescriptor(
                renderPassDescriptor!)

            //-----------------------------------------------------
            // render textured quad
            //-----------------------------------------------------
            encode(renderEncoder)

            //-----------------------------------------------------
            // Dispatch the command buffer
            //-----------------------------------------------------
            commandBuffer.addCompletedHandler{
                [weak self] commandBuffer in
                if let strongSelf = self
                {
                    dispatch_semaphore_signal(strongSelf.m_InflightSemaphore)
                }
                return  }
            //----------------------------------------------------------------

            //-----------------------------------------------------
            // Present and commit the command buffer
            //-----------------------------------------------------
            let drawable:CAMetalDrawable? = view.currentDrawable()
            commandBuffer.presentDrawable(drawable!)
            commandBuffer.commit()
        }
    }
    //-------------------------------------------------------------------------
    @objc func update(controller:TViewController)
    {
        // Note this method is called from the thread the main game loop is run
        // not used in this sample
    }
    //-------------------------------------------------------------------------
    @objc func viewController(controller:TViewController, willPause:Bool)
    {
        // called whenever the main game loop is paused,
        // such as when the app is backgrounded
        // not used in this sample
    }
    //-------------------------------------------------------------------------
}
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
