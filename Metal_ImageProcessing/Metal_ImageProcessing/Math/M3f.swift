//------------------------------------------------------------------------------
// Copyright (c) 2014 Jim Wrenholt. All rights reserved.
//------------------------------------------------------------------------------
import Foundation

//------------------------------------------------------------------------------
struct M3f : Printable, DebugPrintable
{
    var mat: Array<Float> = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0]
    //-------------------------------------------------------------------------
    init()
    {
        mat[0] = 1.0
        mat[1] = 0
        mat[2] = 0

        mat[3] = 0
        mat[4] = 1.0
        mat[5] = 0

        mat[6] = 0
        mat[7] = 0
        mat[8] = 1.0
    }
    //-------------------------------------------------------------------------
    init(data:[Float])
    {
        assert(data.count == 9)
        mat = data
    }
    //-------------------------------------------------------------------------
    subscript(index:Int) -> Float
    {
        get
        {
            assert((index >= 0) && (index < 9))
            return mat[index]
        }
        set
        {
            assert((index >= 0) && (index < 9))
            mat[index] = newValue
        }
    }
    //-------------------------------------------------------------------------
    subscript(row:Int, col:Int) -> Float
        {
        get
        {
            let index:Int = (row * 3) + col
            assert((index >= 0) && (index < 9))
            return mat[index]
        }
        set
        {
            let index:Int = (row * 3) + col
            assert((index >= 0) && (index < 9))
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
            for (var c:Int = 0; c < 3; ++c)
            {
                desc += "   "
                for (var r:Int = 0; r < 3; ++r)
                {
                    let elem = "\(self[r, c].format(pt_f))"
                    desc += elem
                    if (r != 2)
                    {
                        desc += ", "
                    }
                }
                if (c == 2)
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
            for (var r:Int = 0; r < 3; ++r)
            {
                desc += "   "
                for (var c:Int = 0; c < 3; ++c)
                {
                    let elem = "\(self[r, c].format(pt_f))"
                    desc += elem
                    if (c != 2)
                    {
                        desc += ", "
                    }
                }
                if (r == 2)
                {
                    desc += " ]"
                }
                desc += "\n"
            }
            return desc
        }
    }
    //-------------------------------------------------------------------------
}
//------------------------------------------------------------------------------

