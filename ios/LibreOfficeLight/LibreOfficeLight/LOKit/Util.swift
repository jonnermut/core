//
//  Util.swift
//  LibreOfficeLight
//
//  Created by Jon Nermut on 9/1/18.
//  Copyright © 2018 jani. All rights reserved.
//

import UIKit


func getDocumentsDirectory() -> URL
{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

public extension CGRect
{
    public var desc: String
    {
        return "(x: \(self.origin.x), y: \(self.origin.y), width: \(self.size.width), height: \(self.size.height), maxX: \(self.maxX), maxY: \(self.maxY))"
    }
}

public func toString(_ pointer: UnsafeMutablePointer<Int8>?) -> String?
{
    if let p = pointer
    {
        return String(cString: p)
    }
    return nil
}

public func toString(_ pointer: UnsafePointer<Int8>?) -> String?
{
    if let p = pointer
    {
        return String(cString: p)
    }
    return nil
}

