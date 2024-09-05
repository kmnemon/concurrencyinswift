//
//  ScanActor.swift
//  Sky (iOS)
//
//  Created by ke on 2024/9/5.
//

import Foundation
import Distributed

distributed actor ScanActor {
  typealias ActorSystem = BonjourActorSystem
  
  private let nameValue: String
  init(name: String, actorSystem: ActorSystem) {
    self.nameValue = name
    self.actorSystem = actorSystem
  }
  
  distributed var name: String {
    nameValue
  }
  
  private var countValue = 0
  //the number of tasks the actor has currently committed to executing
  distributed var count: Int {
    countValue
  }
  
  distributed func commit() {
    countValue += 1
    
    NotificationCenter.default.post(name: .localTaskUpdate, object: nil, userInfo: [Notification.taskStatusKey: "Committed"])
  }
  
  distributed func run(_ task: ScanTask) async throws -> Data {
    var info: [String: Any] = [:]
    
    defer {
      countValue -= 1
      
      NotificationCenter.default.post(
        name: .localTaskUpdate,
        object: nil,
        userInfo: info
      )
    }
    
    do {
      let data = try await task.run()
      info[Notification.taskStatusKey] = "Task \(task.input) Completed"
      return data
    } catch {
      info[Notification.taskStatusKey] = "Task \(task.input) Failed"
      throw error
    }
  }
  
}
