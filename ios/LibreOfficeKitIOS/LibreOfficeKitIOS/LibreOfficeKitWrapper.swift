//
//  LibreOfficeKitWrapper.swift
//  LibreOfficeLight
//
//

import Foundation
import LibreOfficeKitPrivate

public struct LibreOfficeError: Error
{
    let message: String
    public init(_ message: String)
    {
        self.message = message
    }
}

open class LibreOffice
{
    private let pLok: UnsafeMutablePointer<LibreOfficeKit>
    private let lokClass: LibreOfficeKitClass

    public init() throws
    {
        let b = Bundle.init(for: LibreOffice.self)
        let path = b.bundlePath // not Bundle.main.bundlePath
        BridgeLOkit_Init(path)
        let pLok = BridgeLOkit_getLOK()
        if let lokClass = pLok?.pointee.pClass?.pointee
        {
            self.pLok = pLok!
            self.lokClass = lokClass
            return
        }
        throw LibreOfficeError("Unable to init LibreOfficeKit")
    }

    public func getVersionInfo() -> String?
    {
        if let pRet = lokClass.getVersionInfo(pLok)
        {
            return String(cString: pRet) // TODO: convert JSON
        }
        return nil
    }

    public func documentLoad(url: String) throws -> Document
    {
        if let pDoc = lokClass.documentLoad(pLok, url)
        {
            return Document(pDoc: pDoc)
        }
        throw LibreOfficeError("Unable to load document")
    }
}

open class Document
{
    private let pDoc: UnsafeMutablePointer<LibreOfficeKitDocument>
    private let docClass: LibreOfficeKitDocumentClass

    internal init(pDoc: UnsafeMutablePointer<LibreOfficeKitDocument>)
    {
        self.pDoc = pDoc
        self.docClass = pDoc.pointee.pClass.pointee
    }

    public func getDocumentType() -> Int32
    {
        return docClass.getDocumentType(pDoc)
    }

    public func initializeForRendering()
    {
        docClass.initializeForRendering(pDoc, "") // TODO: arguments??
    }

    public func getPartRectanges() -> String
    {
        if let rects = docClass.getPartPageRectangles(pDoc)
        {
            return String(cString: rects) // TODO: convert to CGRects? Comes out like "284, 284, 11906, 16838; 284, 17406, 11906, 16838; 284, 34528, 11906, 16838"
        }
        return ""
    }
}

