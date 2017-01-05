//
//  Await.swift
//  Hydra
//
//  Created by Daniele Margutti on 05/01/2017.
//  Copyright © 2017 Daniele Margutti. All rights reserved.
//

import Foundation

/// Concurrent queue context in which awaits func works
let awaitContext = Context.custom(queue: DispatchQueue(label: "com.hydra.awaitcontext", attributes: .concurrent))

/// Awaits that the given promise fulfilled with its value or throws an error if the promise fails
///
/// - Parameter promise: target promise
/// - Returns: fufilled value of the promise
/// - Throws: exception if promise fails due to an error
@discardableResult
public func await<T>(_ promise: Promise<T>) throws -> T {
	return try awaitContext.await(promise)
}

/// Awaits that the given body is resolved. This is a shortcut which simply create a Promise; as for a Promise you need to
/// call `resolve` or `reject` in order to complete it.
///
/// - Parameters:
///   - context: context in which the body will be executed in
///   - body: closure to execute
/// - Returns: the value of the promise
/// - Throws: an exception if operation fails
@discardableResult
public func await<T>(_ context: Context = .background, _ body: @escaping ((_ fulfill: @escaping (T) -> (), _ reject: @escaping (Error) -> () ) throws -> ())) throws -> T {
	let promise = Promise<T>(context,body)
	return try await(promise)
}

public extension Context {
	
	///  Awaits that the given promise fulfilled with its value or throws an error if the promise fails.
	///
	/// - Parameter promise: target promise
	/// - Returns: return the value of the promise
	/// - Throws: throw if promise fails
	@discardableResult
	internal func await<T>(_ promise: Promise<T>) throws -> T {
		guard self.queue != DispatchQueue.main else {
			// execute a promise on main context does not make sense
			throw PromiseError.awaitOnMainQueue
		}
		
		var result: T?
		var error: Error?
		
		// Create a semaphore to block the execution of the flow until
		// the promise is fulfilled or rejected
		let semaphore = DispatchSemaphore(value: 0)
		
		promise.then(self) { value -> Void in
			// promise is fulfilled, fillup error and resume code execution
			result = value
			semaphore.signal()
		}.catch(context: self) { err in
			// promise is rejected, fillup error and resume code execution
			error = err
			semaphore.signal()
		}
	
		// Wait and block code execution until promise is fullfilled or rejected
		_ = semaphore.wait(timeout: DispatchTime(uptimeNanoseconds: UINT64_MAX))
		
		guard let promiseValue = result else {
			throw error!
		}
		return promiseValue
	}
}
