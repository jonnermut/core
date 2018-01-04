//
//  LOKitThread.swift
//  LibreOfficeLight
//
//  Created by Jon Nermut on 4/1/18.
//  Copyright © 2018 jani. All rights reserved.
//

import Foundation
import LibreOfficeKitIOS

/// Runs tasks in a serial way on a single thread.
/// Why wouldn't we just use DispatchQueue or NSOperationQueue to do this?
/// Because neither guarantee running their tasks on the same thread all the time.
/// And in fact DispatchQueue will try and run sync tasks on the current thread where it can.
/// Both classes try and abstract the thread away, whereas we have to use the same thread, or we end up with deadlocks in LOKit
/// TODO: move me to framework
class SingleThreadedQueue: Thread
{
    init(name: String)
    {
        super.init()
        self.name = name
        self.start()
    }
    
    override func main()
    {
        // You need the NSPort here because a runloop with no sources or ports registered with it
        // will simply exit immediately instead of running forever.
        let keepAlive = Port()
        let rl = RunLoop.current
        keepAlive.schedule(in: rl, forMode: .commonModes)
        
        rl.run()
    }
    
     /// Run the task on the serial queue, and return immediately
    func async( _ runnable: @escaping Runnable)
    {
        let operation = BlockOperation {
            runnable()
        }
        async(operation: operation)
    }
    
     /// Run the task on the serial queue, and return immediately
    func async( operation: Operation)
    {
        if ( Thread.current == self)
        {
            operation.start();
        }
        else
        {
            operation.perform(#selector(Operation.start), on: self, with: nil, waitUntilDone: false)
        }
    }
    
    public func sync<R>( _ closure: @escaping () -> R ) -> R
    {
        var ret: R! = nil
        let op = BlockOperation {
            ret = closure();
        }
        async(operation: op)
        op.waitUntilFinished()
        return ret
    }
    
}




/// Serves the same purpose as the LOKitThread in the Android project - sequentialises all access to LOKit on a background thread, off the UI thread.
/// It's a singleton, and keeps a single instance of LibreOfficeKit
/// Public methods may be called from any thread, and will dispatch their work onto the held sequential queue.
/// TODO: move me to framework
public class LOKitThread
{
    public static let instance = LOKitThread() // statics are lazy and thread safe in swift, so no need for anything more complex
    
    
    fileprivate let queue = SingleThreadedQueue(name: "LOKitThread.queue")
    
    /// singleton LibreOffice instance. Can only be accessed through the queue.
    var libreOffice: LibreOffice! = nil // initialised in didFinishLaunchingWithOptions

    
    private init()
    {

        async {
            self.libreOffice = try! LibreOffice() // will blow up the app if it throws, but fair enough
        }
    }
    
    /// Run the task on the serial queue, and return immediately
    public func async(_ runnable: @escaping Runnable)
    {
        queue.async( runnable)
    }
    
    /// Run the task on the serial queue, and block to get the result
    /// Careful of deadlocking!
    public func sync<R>( _ closure: @escaping () -> R ) -> R
    {
        let ret = queue.sync( closure )
        return ret
    }
    
    public func withLibreOffice( _ closure: @escaping (LibreOffice) -> ())
    {
        async {
            closure(self.libreOffice)
        }
    }
    
    /// Loads a document, and calls the callback with a wrapper if successful, or an error if not.
    public func documentLoad(url: String, callback: @escaping (DocumentHolder?, Error?) -> ())
    {
        withLibreOffice
        {
            lo in
            
            do
            {
                // this is trying to avoid null context errors which pop up on doc init
                // doesnt seem to fix
                UIGraphicsBeginImageContext(CGSize(width:1,height:1))
                let doc = try lo.documentLoad(url: url)
                print("Opened document: \(url)")
                doc.initializeForRendering()
                UIGraphicsEndImageContext()
                
                callback(DocumentHolder(doc: doc), nil)
            }
            catch
            {
                print("Failed to load document: \(error)")
                callback(nil, error)
            }
        }
    }
}

/**
 * Holds the document object so to enforce access in a thread safe way.
 */
public class DocumentHolder
{
    private let doc: Document
    
    init(doc: Document)
    {
        self.doc = doc
    }
    
    /// Gives async access to the document
    public func async(_ closure: @escaping (Document) -> ())
    {
        LOKitThread.instance.async
        {
            closure(self.doc)
        }
    }
    
    /// Gives sync access to the document - blocks until the closure runs.
    /// Careful of deadlocks.
    public func sync<R>( _ closure: @escaping (Document) -> R ) -> R
    {
        return LOKitThread.instance.sync
        {
            return closure(self.doc)
        }
    }
}
