//
//  RvcWrapper.swift
//  rvcmac
//
//  Created by Nikita Titov on 23/09/2017.
//  Copyright © 2017 Ribose. All rights reserved.
//

import Foundation
import CoreData

// Swift wrappers for C library functions.
// Once C functions become mature enough and will do their own parsing from json string to data structures these wrappers could be eliminated.

class RvcWrapper {
    
    func list() -> [RvcConnection] {
        var buffer = [Int8]()
        var response: String!
        buffer.withUnsafeMutableBufferPointer { bptr in
            var ptr = bptr.baseAddress!
            rvc_list_connections(1, &ptr) // actual library call
            response = String(cString: ptr)
        }
        if let json = jsonObject(response), let envelope = try? RvcConnectionEnvelope.decode(json), envelope.code == 0 {
            return envelope.data
        }
        return [RvcConnection]()
    }
    
    func status(_ name: String) -> RvcStatus? {
        var buffer = [Int8]()
        var response: String!
        buffer.withUnsafeMutableBufferPointer { bptr in
            var ptr = bptr.baseAddress!
            rvc_get_status(name.cString(using: .utf8)!, 1, &ptr) // actual library call
            response = String(cString: ptr)
        }
        return createStatus(response)
    }
    
    func connect(_ name: String) -> RvcStatus? {
        var buffer = [Int8]()
        var response: String!
        buffer.withUnsafeMutableBufferPointer { bptr in
            var ptr = bptr.baseAddress!
            let name = name.cString(using: .utf8)!
            rvc_connect(name, 1, &ptr) // actual library call
            response = String(cString: ptr)
        }
        return createStatus(response)
    }
    
    func disconnect(_ name: String) -> RvcStatus? {
        var buffer = [Int8]()
        var response: String!
        buffer.withUnsafeMutableBufferPointer { bptr in
            var ptr = bptr.baseAddress!
            let name = name.cString(using: .utf8)!
            rvc_disconnect(name, 1, &ptr) // actual library call
            response = String(cString: ptr)
        }
        return createStatus(response)
    }
    
    private func createStatus(_ response: String) -> RvcStatus? {
        guard let json = jsonObject(response), let envelope = try? RvcStatusEnvelope.decode(json), envelope.code == 0 else {
            return nil
        }
        let status = envelope.data
        // Get isSelected from persistent storage
        let name = status.name
        let context = AppDelegate.shared.persistentContainer.viewContext
        if let connection = selectConnection(context, name: status.name) {
            status.isSelected = connection.isSelected
        } else {
            insertConnection(context, name: name)
        }
        return status
    }
    
    func selectConnection(_ context: NSManagedObjectContext, name: String) -> Connection? {
        let context = AppDelegate.shared.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Connection> = Connection.fetchRequest()
        let predicate = NSPredicate(format: "name = %@", name)
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        let items = try? context.fetch(fetchRequest)
        let item = items?.first
        return item
    }
    
    func insertConnection(_ context: NSManagedObjectContext, name: String) {
        let item = Connection(context: context)
        item.name = name
        item.isSelected = false
        do {
            try context.save()
        } catch let error {
            debugPrint("Error in saveRecords \(error.localizedDescription)")
        }
    }
    
    private func jsonObject(_ string: String) -> Any? {
        let data = string.data(using: .utf8)!
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }
}
