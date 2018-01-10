//
//  DocumentView.swift
//  LibreOfficeLight
//
//  Created by Jon Nermut on 4/1/18.
//  Copyright © 2018 jani. All rights reserved.
//

import UIKit
import QuartzCore


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
        var size = document.sync { $0.getDocumentSizeAsCGSize() }
        
        // avoid divide by zero crashes
        if (size.width == 0)
        {
            size.width = 1
        }
        if (size.height == 0)
        {
            size.height = 1
        }
        self.docSize = size
        initialScaleFactor = (docSize.width / initialSize.width)
        let scaledFrame = CGRect(x: 0, y: 0, width: frame.width, height: frame.width * (docSize.height / docSize.width))
        
        print("DocumentTiledView.init frame=\(frame.desc) \n  scaledFrame=\(scaledFrame.desc)\n  docSize=\(docSize) \n  initialScaleFactor=\(initialScaleFactor)")
        super.init(frame: scaledFrame)
        
        //self.contentScaleFactor = 1.0
        
        if let tiledLayer = self.layer as? CATiledLayer
        {
            tiledLayer.levelsOfDetail = 4
            tiledLayer.levelsOfDetailBias = 7
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
        
        print("drawLayer \(filename)\n  bounds=\(layer.bounds.desc)\n  ctm.a=\(ctm.a)\n  tileSize=\(tileSize)\n   box=\(box.desc)")
        
        //context.setFillColor(UIColor.white.cgColor)
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(box)
        context.saveGState()

        context.interpolationQuality = CGInterpolationQuality.high
        context.setRenderingIntent(CGColorRenderingIntent.defaultIntent)

        // This is where the magic happens
        
        let pageRect = box.applying(CGAffineTransform(scaleX: initialScaleFactor, y: initialScaleFactor ))
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
        
        if let img = image
        {
            // Debugging: write the file to disk
            /*
            if let data = UIImagePNGRepresentation(img)
            {
                let filename = getDocumentsDirectory().appendingPathComponent(filename)
                try? data.write(to: filename)
                print("Wrote tile to: \(filename)")
            }
            */
            
            // We use the UIImage draw function as it automatically handles the flipping of the co-ordinate system for us.
            UIGraphicsPushContext(context);
            img.draw(in: box)
            UIGraphicsPopContext()
        }
        
        context.restoreGState()
        

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
    
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat)
    {
        //self.setNeedsDisplay()
    }

    
//    override func pressesBegan
//    {
//    
//    }
}
