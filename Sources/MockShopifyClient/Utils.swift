//
//  File.swift
//  
//
//  Created by Andreas Loizides on 26/04/2023.
//

import Foundation
class JIS: InputStream{
	static let encoder = JSONEncoder()
	init<T: Encodable>(thing: T) {
		let d = try! Self.encoder.encode(thing)
		super.init(data: d)
	}
}
class JSONInputStream: InputStream {
	private let data: Data
	private var position: Int = 0
	static let encoder = JSONEncoder()
	init<T: Encodable>(codable: T) {
		let d = try! Self.encoder.encode(codable)
		self.data = d
		super.init(data: d)
	}
	
	init(jsonData: Data) {
		self.data = jsonData
		super.init(data: jsonData)
	}

	override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
		let remainingBytes = data.count - position
		let bytesToRead = min(len, remainingBytes)
		guard bytesToRead > 0 else { return 0 }
		
		data.copyBytes(to: buffer, from: position..<position + bytesToRead)
		position += bytesToRead
		return bytesToRead
	}

	override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
		return false
	}

	override var hasBytesAvailable: Bool {
		return position < data.count
	}
}
