//
//  MZDarwinNotifyCenter.swift
//  MZDarwinNotifyCenter
//
//  Created by WangMike on 15/5/4.
//  Copyright (c) 2015年 WangMike. All rights reserved.
//

import Foundation

private func WormholeNotificationCenterCallback(notificationCenter:CFNotificationCenter!, observer:UnsafeMutablePointer<Void>, identifier:CFString!, _:UnsafePointer<Void>, _:CFDictionary!){
    if let center = unsafeBitCast(observer,UnsafeMutablePointer<AnyObject>.self).memory as? MZDarwinNotifyCenter{
        center.onRecvNotificationWithIdentifier(identifier as String)
    }
}

private struct HandlePair:Hashable{
    var object:NSObjectProtocol
    var block:(AnyObject?) -> Void
    init(object:NSObject,block:(AnyObject?) -> Void){
        self.object = object
        self.block = block
    }
    var hashValue: Int{
        get{
            return object.hash
        }
    }
    
}
private func == (lhs: HandlePair, rhs: HandlePair) -> Bool{
    return lhs.object.isEqual(rhs.object)
}

class MZDarwinNotifyCenter{
    private(set) var applicationGroupIdentifier:String
    private var directory:NSURL = NSURL()
    
    private var handlePairs:[String:Set<HandlePair>] = [:]
    
    private var fileManage:NSFileManager!
    
    internal class var defaultCenter:MZDarwinNotifyCenter{
        struct Store{
            static var store = MZDarwinNotifyCenter()
        }
        return Store.store
    }
    
    internal init?(applicationGroupIdentifier:String,directory:String?){
        self.applicationGroupIdentifier = applicationGroupIdentifier
        fileManage = NSFileManager()
        let dir = directory ?? "Wormhole"
        if let url = fileManage.containerURLForSecurityApplicationGroupIdentifier(applicationGroupIdentifier)?.URLByAppendingPathComponent(dir){
            fileManage.createDirectoryAtURL(url, withIntermediateDirectories: true, attributes: nil, error: nil)
            self.directory = url
        }else{
            return nil
        }
    }
    private init(){
        applicationGroupIdentifier = ""
    }
    private var isDefaultCenter:Bool{
        return self.applicationGroupIdentifier == MZDarwinNotifyCenter.defaultCenter.applicationGroupIdentifier
    }

    private func onRecvNotificationWithIdentifier(aName:String){
        var error:NSError?
        var object: AnyObject? = nil
        if !isDefaultCenter{
            if let data = NSData(contentsOfURL: directory.URLByAppendingPathComponent(aName), options: NSDataReadingOptions.MappedRead, error: &error){
                object = NSKeyedUnarchiver.unarchiveObjectWithData(data)
            }
        }
        var handles = handlePairs[aName] ?? Set<HandlePair>()
        for pair in handles{
            pair.block(object)
        }
    }
    
    internal func addObserver(observer: NSObject, selector aBlock: (AnyObject?) -> Void, name aName: String){
        var handles = handlePairs[aName] ?? Set<HandlePair>()
        handles.insert(HandlePair(object: observer,block: aBlock))
        handlePairs.updateValue(handles, forKey: aName)
        
        let callback =  unsafeBitCast(WormholeNotificationCenterCallback, CFNotificationCallback.self)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),unsafeAddressOf(self), callback, aName as CFString, nil, CFNotificationSuspensionBehavior.DeliverImmediately)
    }
    
    internal func postNotificationName(aName: String){
        postNotificationName(aName, userInfo: nil)
    }
    internal func postNotificationName(aName: String, userInfo aUserInfo: [NSObject : AnyObject]?){
        if aUserInfo != nil && !isDefaultCenter{
            let data = NSKeyedArchiver.archivedDataWithRootObject(aUserInfo!)
            if data.writeToURL(directory.URLByAppendingPathComponent(aName), atomically: true){
                CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), aName as CFStringRef, UnsafePointer<Void>(), nil, UInt( kCFNotificationDeliverImmediately | kCFNotificationPostToAllSessions))
            }
        }else{
            CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), aName as CFStringRef, UnsafePointer<Void>(), nil, UInt( kCFNotificationDeliverImmediately | kCFNotificationPostToAllSessions))
        }
    }
    
    internal func removeObserver(observer: AnyObject){
        for aName in handlePairs.keys{
            removeObserver(observer, name: aName)
        }
    }
    internal func removeObserver(observer: AnyObject, name aName: String){
        var handles = handlePairs[aName] ?? Set<HandlePair>()
        handles = Set<HandlePair>(filter(handles, { (item) -> Bool in
            return !item.object.isEqual(observer)
        }))
        if !handles.isEmpty{
        handlePairs.updateValue(handles, forKey: aName)
        }else{
            handlePairs.removeValueForKey(aName)
        }
    }
}