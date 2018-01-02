//
//  LibreOfficeKitIOSTests.swift
//  LibreOfficeKitIOSTests
//
//  Created by Jon Nermut on 30/12/17.
//  Copyright © 2017 LibreOffice. All rights reserved.
//

import XCTest
@testable import LibreOfficeKitIOS

class LibreOfficeKitIOSTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }


    
    func testLoadingSimpleDoc() {
        
        guard let lo = try? LibreOffice() else
        {
            XCTFail("Could not start LibreOffice")
            return
        }
        
        let b = Bundle.init(for: LibreOfficeKitIOSTests.self)
        guard let url = b.url(forResource: "test-page-format", withExtension: "docx") else
        {
            XCTFail("Failed to get url to test doc")
            return
        }
        
        var loCallbackCount = 0
        lo.registerCallback()
        {
            typ, payload in
            print(typ)
            print(payload)
            loCallbackCount += 1
        }
        
        guard let doc = try? lo.documentLoad(url: url.absoluteString) else
        {
            XCTFail("Could not load document")
            return
        }
        
        var docCallbackCount = 0
        doc.registerCallback()
        {
            typ, payload in
            print(typ)
            print(payload)
            docCallbackCount += 1
        }
        
        //let typ: LibreOfficeDocumentType = doc.getDocumentType()
        //XCTAssertTrue(typ == LibreOfficeDocumentType.LOK_DOCTYPE_TEXT)
        
        doc.initializeForRendering()
        let rects = doc.getPartRectanges()
        print(rects) // 284, 284, 12240, 15840; 284, 16408, 12240, 15840
        let tileMode = doc.getTileMode()
        print(tileMode) // 1
        let canvasWidth = 1024, canvasHeight = 1024

        
        let tilePosX: Int32 = 284
        let tilePosY: Int32 = 284
        let tileWidth: Int32 = 12240
        let tileHeight: Int32 = 12240
        
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: canvasWidth, height: canvasHeight), false, 1.0)
        
        let ctx = UIGraphicsGetCurrentContext()
        print(ctx!)
        let ptr = unsafeBitCast(ctx, to: UnsafeMutablePointer<UInt8>.self)
        print(ptr)
        doc.paintTile(pBuffer:ptr,
                      canvasWidth: Int32(canvasWidth),
                      canvasHeight: Int32(canvasHeight),
                      tilePosX: tilePosX,
                      tilePosY: tilePosY,
                      tileWidth: tileWidth,
                      tileHeight: tileHeight)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let i = image, let data = UIImagePNGRepresentation(i)
        {
            let filename = getDocumentsDirectory().appendingPathComponent("tile1.png")
            try? data.write(to: filename)
            print("Wrote tile to: \(filename)")
        }
    }

}

func getDocumentsDirectory() -> URL
{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}


