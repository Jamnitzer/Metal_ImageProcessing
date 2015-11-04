//------------------------------------------------------------------------------
// Copyright (c) 2014 Jim Wrenholt. All rights reserved.
//------------------------------------------------------------------------------
import Foundation

//------------------------------------------------------------------------------
struct M4f : CustomStringConvertible, CustomDebugStringConvertible
{
    var mat: Array<Float> =
            [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]

    //-------------------------------------------------------------------------
    init()
    {
        mat = [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]
    }
    //-------------------------------------------------------------------------
    init(_ P:V4f, _ Q:V4f, _ R:V4f, _ S:V4f)
    {
        mat = [
            P.x, P.y, P.z, P.w,
            Q.x, Q.y, Q.z, Q.w,
            R.x, R.y, R.z, R.w,
            S.x, S.y, S.z, S.w ]
    }
    //-------------------------------------------------------------------------
    init(data:[Float])
    {
        assert(data.count == 16)
        mat = data
    }
    //-------------------------------------------------------------------------
    subscript(index:Int) -> Float
    {
        get
        {
            assert((index >= 0) && (index < 16))
            return mat[index]
        }
        set
        {
            assert((index >= 0) && (index < 16))
            mat[index] = newValue
        }
    }
    //-------------------------------------------------------------------------
    subscript(row:Int, col:Int) -> Float
    {
        get
        {
            let index:Int = (row * 4) + col
            assert((index >= 0) && (index < 16))
            return mat[index]
        }
        set
        {
            let index:Int = (row * 4) + col
            assert((index >= 0) && (index < 16))
            mat[index] = newValue
        }
    }
    //-------------------------------------------------------------------------
    var description: String
        {
        get
        {
            var desc:String = "[\n"
            let pt_f = ".3"
            for (var c:Int = 0; c < 4; ++c)
            {
                desc += "   "
                for (var r:Int = 0; r < 4; ++r)
                {
                    let elem = "\(self[r, c].format(pt_f))"
                    desc += elem
                    if (r != 3)
                    {
                        desc += ", "
                    }
                }
                if (c == 3)
                {
                    desc += " ]"
                }
                desc += "\n"
            }
            return desc
        }
    }
    //-------------------------------------------------------------------------
    var debugDescription: String
        {
        get
        {
            var desc:String = "[\n"
            let pt_f = ".3"
            for (var r:Int = 0; r < 4; ++r)
            {
                desc += "   "
                for (var c:Int = 0; c < 4; ++c)
                {
                    let elem = "\(self[r, c].format(pt_f))"
                    desc += elem
                    if (c != 3)
                    {
                        desc += ", "
                    }
                }
                if (r == 3)
                {
                    desc += " ]"
                }
                desc += "\n"
            }
            return desc
        }
    }
    //-------------------------------------------------------------------------
    static func TranslationMatrix(v:V3f) -> M4f
    {
        // create the translation matrix
        return M4f(data:[1.0, 0.0, 0.0, 0.0,        // column major
                        0.0, 1.0, 0.0, 0.0,
                        0.0, 0.0, 1.0, 0.0,
                        v[0], v[1], v[2], 1.0])
    }
    //-------------------------------------------------------------------------
}
//------------------------------------------------------------------------------
func * (left: M4f, right: M4f) -> M4f
{
    // multiply left * right
    var data = [Float](count:16, repeatedValue:0.0)
    for (var i:Int = 0; i < 16; ++i)
    {
        let r_idx:Int = (i / 4) * 4
        let r_rem:Int = i - r_idx
        var sub_tot:Float = 0.0
        for (var j:Int = 0; j < 4; ++j)
        {
            let j_idx:Int = j + r_idx
            let k_idx:Int = 4 * j + r_rem
            sub_tot += left[k_idx] * right[j_idx]
        }
        data[i] = sub_tot
    }
    return M4f(data:data)
}
//------------------------------------------------------------------------------
// mark Public - Transformations - LookAt
//------------------------------------------------------------------------------
let zeroVector4 = V4f(0.0, 0.0, 0.0, 0.0)


//------------------------------------------------------------------------------
func lookAt(eye:V3f, center:V3f, up:V3f) -> M4f
{
    let E:V3f = -eye

    let Na:V3f = center + E
    let N:V3f = Na.Normalized()

    let Ua = Cross(up, b: N)
    let U:V3f = Ua.Normalized()

    let Va = Cross(N, b: U)
    let V:V3f = Va.Normalized()

    var P:V4f = zeroVector4
    var Q:V4f = zeroVector4
    var R:V4f = zeroVector4
    var S:V4f = zeroVector4

    P.x = U.x; Q.x = U.y; R.x = U.z
    P.y = V.x; Q.y = V.y; R.y = V.z
    P.z = N.x; Q.z = N.y; R.z = N.z

    S.x = Dot(U, b: E)
    S.y = Dot(V, b: E)
    S.z = Dot(N, b: E)
    S.w = 1.0

    return M4f(P, Q, R, S)
}
//------------------------------------------------------------------------------
func frustum_oc(left:Float, right:Float, bottom:Float, top:Float,
    near:Float, far:Float) -> M4f
{
    let sWidth:Float = 1.0 / (right - left)
    let sHeight:Float = 1.0 / (top - bottom)
    let sDepth:Float = far / (far - near)
    let dNear:Float = 2.0 * near

    var P:V4f = zeroVector4
    var Q:V4f = zeroVector4
    var R:V4f = zeroVector4
    var S:V4f = zeroVector4

    P.x = dNear * sWidth
    Q.y = dNear * sHeight
    R.x = -sWidth * (right + left)
    R.y = -sHeight * (top + bottom)
    R.z = sDepth
    R.w = 1.0
    S.z = -sDepth * near

    return M4f(P, Q, R, S)
}
//------------------------------------------------------------------------------
