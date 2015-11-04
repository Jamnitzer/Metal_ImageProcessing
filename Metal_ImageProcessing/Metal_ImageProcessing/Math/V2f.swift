//------------------------------------------------------------------------------
// Copyright (c) 2014 Jim Wrenholt. All rights reserved.
//------------------------------------------------------------------------------
import Foundation

//------------------------------------------------------------------------------
struct V2f : CustomStringConvertible, CustomDebugStringConvertible
{
    var x:Float = 0.0
    var y:Float = 0.0

    //-------------------------------------------------------------------------
    init()
    {
        self.x = 0.0
        self.y = 0.0
    }
    //-------------------------------------------------------------------------
    init(_ x:Float, _ y:Float)
    {
        self.x = x
        self.y = y
    }
    //-------------------------------------------------------------------------
    subscript(index:Int) -> Float
        {
        get
        {
            assert((index >= 0) && (index < 2))
            if (index == 0)
            {
                return x
            }
            else
            {
                return y
            }
        }
        set
        {
            assert((index >= 0) && (index < 2))
            if (index == 0)
            {
                x = newValue
            }
            else
            {
                y = newValue
            }
        }
    }
    //-------------------------------------------------------------------------
    var description: String
        {
        get
        {
            let pt_f = ".2"
            return "(\(x.format(pt_f)),\(y.format(pt_f)))"
        }
    }
    //-------------------------------------------------------------------------
    var debugDescription: String
        {
        get
        {
            return "(\(x), \(y))"
        }
    }
    //-------------------------------------------------------------------------
    var Length : Float
    {
        return sqrt(x*x + y*y)
    }
    //-------------------------------------------------------------------------
    func Normalized() -> V2f  // const
    {
        let len : Float = Length
        var xx = self.x
        var yy = self.y
        if (len != 0.0)
        {
            xx = xx/len
            yy = yy/len
        }
        return V2f(xx, yy)
    }
}
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
prefix func - (vector: V2f) -> V2f
{
    // negation.
    return V2f(-vector.x, -vector.y)
}
//------------------------------------------------------------------------------

