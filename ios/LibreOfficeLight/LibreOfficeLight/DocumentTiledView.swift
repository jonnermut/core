//
//  DocumentView.swift
//  LibreOfficeLight
//
//  Created by Jon Nermut on 4/1/18.
//  Copyright © 2018 jani. All rights reserved.
//

import Foundation
import QuartzCore
import LibreOfficeKitIOS


public typealias Runnable = () -> ()

/// Runs the closure on a queued background thread
public func runInBackground(_ runnable: @escaping Runnable)
{
    DispatchQueue.global(qos: .background).async(execute: runnable)
}


/// Runs the closure on the UI (main) thread. Exceptions are caught and logged
public func runOnMain(_ runnable: @escaping () -> ())
{
    DispatchQueue.main.async(execute: runnable)
}

/// Returns true if we are on the Main / UI thread
public func isMainThread() -> Bool
{
    return Thread.isMainThread
}


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

class DocumentTiledLayer : CATiledLayer
{
    override class func fadeDuration() -> CFTimeInterval
    {
        return 0
    }
}

open class CachedRender
{
    open let x: CGFloat
    open let y: CGFloat
    open let scale: CGFloat
    open let image: CGImage
    
    public init(x: CGFloat, y: CGFloat, scale: CGFloat, image: CGImage)
    {
        self.x = x
        self.y = y
        self.scale = scale
        self.image = image
    }
}

/**
 * iOS friendly extensions of Document.
 * TODO: move me back to the framework.
 */
public extension Document
{
    public func getDocumentSizeAsCGSize() -> CGSize
    {
        let (x,y) = self.getDocumentSize()
        return CGSize(width: x, height: y)
    }
    
    public func paintTileToCurrentContext(canvasSize: CGSize,
                                          tileRect: CGRect)
    {
        let ctx = UIGraphicsGetCurrentContext()
        //print(ctx!)
        let ptr = unsafeBitCast(ctx, to: UnsafeMutablePointer<UInt8>.self)
        //print(ptr)
        
        self.paintTile(pBuffer:ptr,
                       canvasWidth: Int32(canvasSize.width),
                       canvasHeight: Int32(canvasSize.height),
                       tilePosX: Int32(tileRect.minX),
                       tilePosY: Int32(tileRect.minY),
                       tileWidth: Int32(tileRect.size.width),
                       tileHeight: Int32(tileRect.size.height))
    }
    
    public func paintTileToImage(canvasSize: CGSize,
                                 tileRect: CGRect) -> UIImage?
    {
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 2.0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.scaleBy(x: 0.5,y: 0.5)
        let modSize = CGSize(width: canvasSize.width * 2, height:canvasSize.height * 2)
        self.paintTileToCurrentContext(canvasSize: modSize, tileRect: tileRect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

class DocumentTiledView: UIView
{
    var myScale: CGFloat
    
    weak var document: DocumentHolder? = nil
    
    let initialSize: CGSize
    let docSize: CGSize
    let initialScaleFactor: CGFloat
    
    var drawCount = 0
    
    let drawLock = NSLock()
    
    // Create a new view with the desired frame and scale.
    public init(frame: CGRect, document: DocumentHolder, scale: CGFloat)
    {

        
        self.document = document
       
        
        myScale = scale
        initialSize = frame.size
        docSize = document.sync { $0.getDocumentSizeAsCGSize() }
        initialScaleFactor = (docSize.width / initialSize.width)
        
        print("DocumentTiledView.init frame=\(frame.desc) docSize=\(docSize) initialScaleFactor=\(initialScaleFactor)")
        super.init(frame: frame)
        
        //self.contentScaleFactor = 1.0
        
        if let tiledLayer = self.layer as? CATiledLayer
        {
            //tiledLayer.levelsOfDetail = 4
            //tiledLayer.levelsOfDetailBias = 7
            tiledLayer.tileSize = CGSize(width: 1024.0, height: 1024.0)
            //tiledLayer.tileSize = CGSize(width: 512.0, height: 512.0)
        }
        
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override class var layerClass : AnyClass
    {
        return DocumentTiledLayer.self
    }
    
    
    override func draw(_ r: CGRect)
    {
        // UIView uses the existence of -drawRect: to determine if it should allow its CALayer
        // to be invalidated, which would then lead to the layer creating a backing store and
        // -drawLayer:inContext: being called.
        // By implementing an empty -drawRect: method, we allow UIKit to continue to implement
        // this logic, while doing our real drawing work inside of -drawLayer:inContext:
    }
    
    // Draw the CGPDFPageRef into the layer at the correct scale.
    override func draw(_ layer: CALayer, in context: CGContext)
    {
//        if self.superview == nil
//        {
//            // check that we are still active - ios is doing some really funny things where this method gets called after dealloc which causes bad bad karma
//            return
//        }
        guard let document = self.document else
        {
            return
        }
        
        guard let tiledLayer = layer as? CATiledLayer else { return }
        

        
        let tileSize: CGSize = tiledLayer.tileSize
        let box: CGRect = context.boundingBoxOfClipPath
        let ctm: CGAffineTransform = context.ctm

        drawLock.lock()
        defer { drawLock.unlock() }
        
        drawCount += 1
        let filename = "tile\(drawCount).png"
        
        print("drawLayer \(filename)\n  bounds=\(layer.bounds.desc)\n  ctm.a\(ctm.a)\n  tileSize=\(tileSize)\n   box=\(box.desc)")
        
        //context.setFillColor(UIColor.white.cgColor)
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(box)
        context.saveGState()

        context.interpolationQuality = CGInterpolationQuality.high
        context.setRenderingIntent(CGColorRenderingIntent.defaultIntent)

        // This is where the magic happens
        
        var pageRect = box.applying(CGAffineTransform(scaleX: initialScaleFactor, y: initialScaleFactor ))
        pageRect.size = CGSize(width: box.width * initialScaleFactor * 2, height: box.height * initialScaleFactor * 2)
        print("  pageRect: \(pageRect.desc)")
        
        // Figure out how many pixels we need for the dimensions of our tile
        // tileSize represents a "full size" one in pixels
        
        //let fullSizeTileInPoints = CGSize(width: CGFloat(tileSize.width) / ctm.a, height: CGFloat(tileSize.height) / ctm.a)
        //let cropRectTileFraction = CGSize(width: box.size.width / fullSizeTileInPoints.width, height: box.size.height / fullSizeTileInPoints.height)
        //let bitmapSize = CGSize(width: tileSize.width * cropRectTileFraction.width, height: tileSize.height * cropRectTileFraction.height)
        
        let canvasSize = tileSize; //CGSize(width:512, height:512) // FIXME - this needs to be calculated
        
        // we have to do the call synchronously, as the tile has to be painted now, on the current thread
        // TODO - cache the image, and check the cache before we do the sync call
        let image = document.sync {
            $0.paintTileToImage(canvasSize: canvasSize, tileRect: pageRect)
        }
        
        if let img = image, let cgImg = img.cgImage
        {
            // Debugging: write the file to disk
            if let data = UIImagePNGRepresentation(img)
            {
                let filename = getDocumentsDirectory().appendingPathComponent(filename)
                try? data.write(to: filename)
                print("Wrote tile to: \(filename)")
            }
            
            // Start with identity matrix
            let m1: CGAffineTransform = CGAffineTransform.identity
            
            //let m2 = m1.scaledBy(x: 1, y: -1)
            
            // Move it to the right location
            //let m3 = m2.translatedBy(x: box.origin.x, y: -box.origin.y )  // + bitmapSize.height / ctm.a
            
            // Scale it and flip in y axis
            //let scaleToUse = CGFloat(1.0) // TODO: 1 / ctm.a (??)
            //let m3 = m2.scaledBy(x: scaleToUse, y: -scaleToUse)
            
            // Apply it to the graphics context
            //context.concatenate(m2)
            
            // Finally, draw the image onto the context
            //context.draw(cgImg, in: box)
            UIGraphicsPushContext(context);
            img.draw(in: box)
            UIGraphicsPopContext()
        }
        
        context.restoreGState()
        

    }
    
    
    // ALWAYS have content scale factor be 1.0
    // The OS randomly setting this to 2.0 causes quite strange behaviour, particularly on
    // full screen transitions
    // This will probably need revisiting if valid values are ever other than 1.0 & 2.0
//    override var contentScaleFactor : CGFloat
//    {
//        get
//        {
//            return 1.0
//        }
//        set
//        {
//            // We want to return 1.0 anyway
//        }
//    }
    
    override func layoutSubviews()
    {

        super.layoutSubviews()

        //self.contentScaleFactor = 1.0
    }
    
    /*
    fileprivate func emptyCache()
    {
        cachedRenders.removeAll()
    }
    
    fileprivate func pruneCache()
    {
        let max = hasReceivedMemoryWarning ? CACHE_LOWMEM : CACHE_NORMAL
        while cachedRenders.count > max
        {
            cachedRenders.popFirst()
        }
    }
 */
    
    deinit
    {
        self.document = nil
        
    }
    
    override func setNeedsLayout()
    {
        super.setNeedsLayout()
    }
    

    
}
