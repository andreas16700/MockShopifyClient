import XCTest
import ShopifyKit
@testable import MockShopifyClient

final class MockShopifyClientTests: XCTestCase {
	static let client = MockShClient(baseURL: URL(string: "http://localhost:8080")!)
	override func setUp() async throws {
		let r = try await XCTUnwrapAsync(await Self.client.generateRandom())
		XCTAssertTrue(r)
	}
	override func tearDown() async throws {
		let r = try await XCTUnwrapAsync(await Self.client.reset())
		XCTAssertTrue(r)
	}
	func testInventoryMethods()async throws{
		let counter = {return await Self.client.getCountOfAllResource(resource: .inventories)}
		let singler: (Int)async->InventoryLevel? = Self.client.getInventory
		let aller: () async -> [InventoryLevel]? = Self.client.getAllInventories
		try await testAllResourceMethods(countGetter: counter, singleGetter: singler, allGetter: aller, idPath: \.inventoryItemID)
	}
	func testProductMethods()async throws{
		let counter = {return await Self.client.getCountOfAllResource(resource: .products)}
		let singler: (Int)async->SHProduct? = Self.client.getProduct
		let aller = Self.client.getAllProducts
		try await testAllResourceMethods(countGetter: counter, singleGetter: singler, allGetter: aller, idPath: \.id!)
	}
	func testAllResourceMethods<T: Equatable, ID>(countGetter: ()async->Int?, singleGetter: (ID)async->T?, allGetter: ()async->[T]?, idPath: KeyPath<T,ID>) async throws{
		let count = try await XCTUnwrapAsync(await countGetter())
		let all = try await XCTUnwrapAsync(await allGetter())
		XCTAssertEqual(count, all.count)
		let randomItems = try Array(1...5).map{_ in try XCTUnwrap(all.randomElement())}
		for item in randomItems {
			let retrieved = try await XCTUnwrapAsync(await singleGetter(item[keyPath: idPath]))
			if retrieved != item{
				print("sigh")
			}
			XCTAssertEqual(retrieved, item)
		}
	}
	enum Resource: String{
		case items, models,stocks
	}
}
public func XCTUnwrapAsync<T>(_ expression: @autoclosure () async throws -> T?, _ message: @autoclosure () -> String = "")async throws->T{
	let expr = try await expression()
	let msg = message()
	return try XCTUnwrap(expr, msg)
}
