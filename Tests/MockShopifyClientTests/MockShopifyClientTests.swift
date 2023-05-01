import XCTest
import ShopifyKit
@testable import MockShopifyClient

final class MockShopifyClientTests: XCTestCase {
	static let client = MockShClient(baseURL: URL(string: "http://localhost:8082")!)
	override func setUp() async throws {
		let r = try await XCTUnwrapAsync(await Self.client.generateRandom())
		XCTAssertTrue(r)
	}
	override func tearDown() async throws {
		let r = try await XCTUnwrapAsync(await Self.client.reset())
		XCTAssertTrue(r)
	}
	func testUpdateInventories()async throws{
		print("Will test some inventory methods. Will first find a product.")
		let handles = try await XCTUnwrapAsync(await Self.client.getProductsPage(pageNum: 1)).map(\.handle)
		let aHandle = try XCTUnwrap(handles.randomElement())
		print("Chose product with handle \(aHandle)")
		let product = try await XCTUnwrapAsync(await Self.client.getProduct(withHandle: aHandle))
		
		let invIDs = product.variants.map(\.inventoryItemID).map{$0!}
		print("Will retrieve its \(invIDs.count) inventories (IDs: \(invIDs.map({String($0)}).joined(separator: ","))")
		let currentInventories = try await XCTUnwrapAsync(await Self.client.getInventories(of: invIDs))
		XCTAssertEqual(invIDs.count, currentInventories.count)
		let countOfUpdates = Int.random(in: 1..<invIDs.count)
		let IDsToUpdate = invIDs[0..<countOfUpdates]
		print("Will attempt to update \(countOfUpdates) inventories. (IDs:\(IDsToUpdate.commaSepString())")
		let updates = currentInventories.map{$0.randomUpdate()}
		let achieved = try await XCTUnwrapAsync(await Self.client.updateInventories(updates: updates))
		for intendedUpdate in updates{
			let achievedUpdate = try XCTUnwrap(achieved.first(where:{$0.inventoryItemID == intendedUpdate.inventoryItemID}))
			XCTAssertEqual(intendedUpdate.available, achievedUpdate.available)
			XCTAssertEqual(intendedUpdate.locationID, achievedUpdate.locationID)
		}
	}
	func testInventoryMethods()async throws{
		let counter = {return await Self.client.getCountOfAllResource(resource: .inventories)}
		let singler: (Int)async->InventoryLevel? = Self.client.getInventory
		let aller: () async -> [InventoryLevel]? = Self.client.getAllInventories
		print("Resting retrieving all inventories..")
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
//	func testUpdatesVars
	func testUpdateVariants()async throws{
		print("Will test some variants methods. Will first find a product.")
		let handles = try await XCTUnwrapAsync(await Self.client.getProductsPage(pageNum: 1)).map(\.handle)
		let aHandle = try XCTUnwrap(handles.randomElement())
		print("Chose product with handle \(aHandle)")
		let product = try await XCTUnwrapAsync(await Self.client.getProduct(withHandle: aHandle))
		
		let variants = product.variants
		
		
		let countOfUpdates = Int.random(in: 1..<variants.count)
		let varsToUpdate = variants[0..<countOfUpdates]
		print("Will attempt to update \(countOfUpdates) variants. (IDs:\(varsToUpdate.map(\.id).commaSepString())")
//		return .init(id: self.id, option1: opt1, option2: opt2, option3: opt3, price: p, compare_at_price: c, sku: nil, title: nil, barcode: UUID().uuidString)
		let updates = varsToUpdate.map{$0.randomUpdate()}
		let achieved = try await XCTUnwrapAsync(await Self.client.updateVariants(with: updates))
		func testPriceString(o: String?, other: String?, tolerance: Double = 0.01)throws{
			if let o=o, let num = Double(o){
				let otherStr = try XCTUnwrap(other)
				let otherNum = try XCTUnwrap(Double(otherStr))
				let diff = abs(otherNum-num)
				XCTAssert(diff<=tolerance)
			}
		}
		for intendedUpdate in updates{
			let achievedUpdate = try XCTUnwrap(achieved.first(where:{$0.id == intendedUpdate.id}))
			XCTAssertEqual(intendedUpdate.option1, achievedUpdate.option1)
			XCTAssertEqual(intendedUpdate.option2, achievedUpdate.option2)
			XCTAssertEqual(intendedUpdate.option3, achievedUpdate.option3)
			try testPriceString(o: intendedUpdate.price, other: achievedUpdate.price)
			try testPriceString(o: intendedUpdate.compare_at_price, other: achievedUpdate.compareAtPrice)
			XCTAssertEqual(intendedUpdate.barcode, achievedUpdate.barcode)
		}
		let countOfNewVars = Int.random(in: 1..<variants.count)
		let newVarsRequests = variants[0..<countOfNewVars].map{$0.newRandomEntry()}
		let achievedNewVars = try await XCTUnwrapAsync(await Self.client.createNewViariants(variants: newVarsRequests, for: product.id!))
		for achievedUpdate in achievedNewVars {
			let intendedUpdate = try XCTUnwrap(newVarsRequests.first(where: {$0.sku == achievedUpdate.sku}))
			XCTAssertEqual(intendedUpdate.option1, achievedUpdate.option1)
			XCTAssertEqual(intendedUpdate.option2, achievedUpdate.option2)
			XCTAssertEqual(intendedUpdate.option3, achievedUpdate.option3)
			try testPriceString(o: intendedUpdate.price, other: achievedUpdate.price)
			try testPriceString(o: intendedUpdate.compare_at_price, other: achievedUpdate.compareAtPrice)
			XCTAssertEqual(intendedUpdate.barcode, achievedUpdate.barcode)
			XCTAssertEqual(intendedUpdate.title, achievedUpdate.title)
		}
	}
}
public func XCTUnwrapAsync<T>(_ expression: @autoclosure () async throws -> T?, _ message: @autoclosure () -> String = "")async throws->T{
	let expr = try await expression()
	let msg = message()
	return try XCTUnwrap(expr, msg)
}

extension Collection{
	func commaSepString()->String{
		return map({"\($0)"}).joined(separator: ",")
	}
}
extension InventoryLevel{
	func randomUpdate()->SHInventorySet{
		guard let previous = self.available else {fatalError()}
		return .init(locationID: self.locationID, inventoryItemID: self.inventoryItemID, available: previous.randomDifferent())
	}
	func randomDifferent()->Self{
		guard let previous = self.available else {fatalError()}
		var s = self
		s.available = previous.randomDifferent()
		return s
	}
}
extension Int{
	func randomDifferent()->Int{
		var r = self
		repeat{
			r = Int.random(in: 0...9999)
		}while (self != r)
		return r
	}
}
extension SHVariant{
	func newRandomEntry()->SHVariantUpdate{
		var u = randomUpdate()
		return .init(id: nil, option1: u.option1, option2: u.option2, option3: u.option3, price: u.price, compare_at_price: u.compare_at_price, sku: UUID().uuidString, title: "Some New Variant \(UUID().uuidString.prefix(4))", barcode: UUID().uuidString)
		
	}
	func randomUpdate()->SHVariantUpdate{
		func updateValueOnlyIfExists(getter: ()->String?, setter: (String)->()){
			if let exists = getter(){
				setter(exists+"-updated")
			}
		}
		var opt1: String? = nil
		var opt2: String? = nil
		var opt3: String? = nil
		updateValueOnlyIfExists(getter: {self.option1}, setter: {opt1=$0})
		updateValueOnlyIfExists(getter: {self.option2}, setter: {opt2=$0})
		updateValueOnlyIfExists(getter: {self.option3}, setter: {opt3=$0})
		var p: String? = nil
		if let doublePrice = Double(price){
			p = "\(doublePrice + Double.random(in: -50...6_000))"
		}
		var c: String? = nil
		if let comp = compareAtPrice, let doublePrice = Double(comp){
			c = "\(doublePrice + Double.random(in: -50...6_000))"
		}
		return .init(id: self.id, option1: opt1, option2: opt2, option3: opt3, price: p, compare_at_price: c, sku: nil, title: nil, barcode: UUID().uuidString)
	}
}
