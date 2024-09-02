/// Copyright (c) 2023 Kodeco Inc
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

class ScanModel: ObservableObject {
  // MARK: - Private state
  private var counted = 0
  private var started = Date()
  
  // MARK: - Public, bindable state
  
  /// Currently scheduled for execution tasks.
  @MainActor @Published var scheduled = 0
  
  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond: Double = 0
  
  /// Completed scan tasks.
  @MainActor @Published var completed = 0
  
  @Published var total: Int
  
  @MainActor @Published var isCollaborating = false
  
  // MARK: - Methods
  
  init(total: Int, localName: String) {
    self.total = total
  }
  
  //1.collect all result
  func runAllTasksAndCollectAll() async throws {
    started = Date()
    
    let scans = await withTaskGroup(of: String.self) { [unowned self] group -> [String] in
      for number in 0..<total {
        group.addTask {
          await self.worker(number: number)
        }
      }
      
      return await group
        .reduce(into: [String]()) { result, string in
          result.append(string)
        }
    }
    
    print(scans)
  }
  
  //2.run tasks and handle single result
  func runAllTasksAndHandleSingleOne() async throws {
    started = Date()
    
    await withTaskGroup(of: String.self) { [unowned self] group in
      for number in 0..<total {
        group.addTask {
          await self.worker(number: number)
        }
      }
      
      for await result in group {
        print("Completed: \(result)")
      }
      print("Done.")
    }
  }
  
  //3.run all tasks with limit
  func runAllTasksWithLimit() async throws {
    started = Date()
    
    try await withThrowingTaskGroup(of: String.self) { [unowned self] group in
      let batchSize = 4
      
      for index in 0..<batchSize {
        group.addTask {
          try await self.workerWithError(number: index)
        }
      }
      
      var index = batchSize
      
      for try await result in group {
        print("Completed: \(result)")
        
        if index < total {
          group.addTask { [index] in
            try await self.workerWithError(number: index)
          }
          index += 1
        }
      }
    }
  }
  
  //4.run all tasks with Result Type
  func runAllTasks() async throws {
    started = Date()
    
    try await withThrowingTaskGroup(of: Result<String, Error>.self) { [unowned self] group in
      let batchSize = 4
      
      for index in 0..<batchSize {
        group.addTask {
          await self.workerWithResultType(number: index)
        }
      }
      
      var index = batchSize
      
      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failure(let error):
          print("Failed: \(error.localizedDescription)")
        }
        
        if index < total {
          group.addTask { [index] in
            await self.workerWithResultType(number: index)
          }
          index += 1
        }
      }
    }
  }
  
  func worker(number: Int) async -> String {
    await onScheduled()
    
    let task = ScanTask(input: number)
    let result = await task.run()
    
    await onTaskCompleted()
    return result
  }
  
  func workerWithError(number: Int) async throws -> String {
    await onScheduled()
    
    let task = ScanTask(input: number)
    let result = try await task.runWithError()
    
    await onTaskCompleted()
    return result
  }
  
  func workerWithResultType(number: Int) async -> Result<String, Error> {
    await onScheduled()
    
    let task = ScanTask(input: number)
    
    let result: Result<String, Error>
    do {
      result = try .success(await task.runWithError())
      await onTaskCompleted()
    } catch {
      result = .failure(error)
      await onTaskCompletedWithError()
    }
    
    
    return result
  }
}

// MARK: - Tracking task progress.
extension ScanModel {
  @MainActor
  private func onTaskCompleted() {
    completed += 1
    counted += 1
    scheduled -= 1
    
    countPerSecond = Double(counted) / Date().timeIntervalSince(started)
  }
  
  @MainActor
  private func onTaskCompletedWithError() {
    counted += 1
    scheduled -= 1
    
    countPerSecond = Double(counted) / Date().timeIntervalSince(started)
  }
  
  @MainActor
  private func onScheduled() {
    scheduled += 1
  }
}
