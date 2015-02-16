//------------------------------------------------------------------------------
// Copyright (c) 2014 Nordic Software, Inc. All rights reserved.
//------------------------------------------------------------------------------
import Foundation
import QuartzCore

//------------------------------------------------------------------------------
extension Float
{
    func format(f: String) -> String
    {
        if (self < 0.0)
        {
            return String(format: "%\(f)f", self)
        }
        else
        {
            return String(format: " %\(f)f", self)
        }
    }
}
//------------------------------------------------------------------------------
func DEG2RAD(ang_degrees:Float) -> Float
{
    let rescale = M_PI / 180.0
    let radians = Float(rescale) * ang_degrees
    return radians
}
//------------------------------------------------------------------------------
func IsNotZero(v:Float, eps:Float = 0.00001) -> Bool
{
    if (fabs(v) > eps)
    {
        return true
    }
    return false
}
//------------------------------------------------------------------------------

