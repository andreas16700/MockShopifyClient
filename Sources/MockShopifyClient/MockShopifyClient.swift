//
//  MockShopifyStore.swift
//  
//
//  Created by Andreas Loizides on 14/12/2022.
//

import Foundation
import ShopifyKit
import SwiftLinuxNetworking

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Blank: Codable{}
struct Wrapper<T: Codable>: Codable{
	let content: T
}

public struct MockShClient: ShopifyClientProtocol{
	public init(baseURL: URL) {
		self.baseURL = baseURL
		let c = URLSessionConfiguration.default
		c.timeoutIntervalForRequest = .infinity
		c.timeoutIntervalForResource = .infinity
		self.session = .init(configuration: c)
	}
	let session: URLSession
	static let pageCapacity = 10000
	let baseURL: URL
	let encoder = JSONEncoder()
	let decoder = JSONDecoder()
	public func generateRandom()async -> Bool{
		await sendRequest(path: "generate", method: "GET")
	}
	public func reset()async -> Bool{
		await sendRequest(path: "reset", method: "GET")
	}
	//MARK: Variant
	public func deleteVariant(ofProductID productID: Int, variantID: Int) async -> Bool {
		return await sendRequest(path: "\(productID)/\(variantID)", method: "DELETE")
	}
	
	public func updateVariant(with update: SHVariantUpdate) async -> SHVariant? {
		return await sendRequest(path: "variants", method: "PUT", body: update, expect: SHVariant.self)
	}
	
	public func updateVariants(with updates: [SHVariantUpdate]) async -> [SHVariant]? {
		return await sendRequest(path: "variants/multiple", method: "PUT", body: updates, expect: [SHVariant].self)
	}
	
	public func createNewVariant(variant: SHVariantUpdate, for productID: Int) async -> SHVariant? {
		return await sendRequest(path: "\(productID)", method: "POST", body: variant, expect: SHVariant.self)
	}
	public func createNewViariants(variants: [SHVariantUpdate], for productID: Int) async -> [SHVariant]? {
		return await sendRequest(path: "\(productID)/multiple", method: "POST", body: variants, expect: [SHVariant].self)
	}
	//MARK: Product
	public func deleteProduct(id: Int) async -> Bool {
		return await sendRequest(path: "\(id)", method: "DELETE")
	}
	
	public func updateProduct(with update: SHProductUpdate) async -> SHProduct? {
		return await sendRequest(path: "products", method: "PUT", body: update, expect: SHProduct.self)
	}
	
	public func createNewProduct(new: SHProduct) async -> SHProduct? {
		return await sendRequest(path: "products", method: "POST", body: new, expect: SHProduct.self)
	}
	public func createNewProductsWithStocks(stuff: [ProductAndItsStocks])async -> Bool{
		return await sendRequest(path: "batchProductsAndStocks", method: "POST", body: stuff)
	}
	
	public func getCountOfAllResource(resource: Resource) async -> Int?{
		return await sendRequest(path: "\(resource.rawValue)/count", method: "GET", expect: Wrapper<Int>.self).map(\.content)
	}
	public func getProductsPage(pageNum: Int) async -> [SHProduct]?{
		return await sendRequest(path: "products/page/\(pageNum)", method: "GET", expect: [SHProduct].self)
	}
	public enum Resource: String{
		case products, inventories
	}
	public func getAllProducts() async -> [SHProduct]? {
		let countGetter = {return await getCountOfAllResource(resource: .products)}
		let pageGetter = getProductsPage
		return await getAllPaginated(resourceName: Resource.products.rawValue, countGetter: countGetter, pageGetter: pageGetter)
	}
	
	public func getProduct(withHandle handle: String) async -> SHProduct? {
		return await sendRequest(path: "handles/\(handle)", method: "GET", expect: SHProduct.self)
	}
	
	public func getProduct(withID id: Int) async -> SHProduct? {
		return await sendRequest(path: "\(id)", method: "GET", expect: SHProduct.self)
	}
	
	public func getIDOfProduct(withHandle handle: String) async -> Int? {
		return await sendRequest(path: "idbyhandle/\(handle)", method: "GET", expect: Wrapper<Int>.self).map(\.content)
	}
	//MARK: Inventory
	public func updateInventory(current: InventoryLevel, update: SHInventorySet) async -> InventoryLevel? {
		return await sendRequest(path: "inventories", method: "PUT", body: update, expect: InventoryLevel.self)
	}
	
	public func updateInventories(updates: [SHInventorySet]) async -> [InventoryLevel]? {
		return await sendRequest(path: "inventories/multiple", method: "PUT", body: updates, expect: [InventoryLevel].self)
	}
	
	public func getInventory(of invItemID: Int) async -> InventoryLevel? {
		return await sendRequest(path: "inventory/\(invItemID)", method: "GET", expect: InventoryLevel.self)
	}
	public func getInventories(of invItemIDs: [Int]) async -> [InventoryLevel]? {
		return await sendRequest(path: "inventories/multiple", method: "POST", body: invItemIDs, expect: [InventoryLevel].self)
	}
	public func getInventoriesPage(pageNum: Int) async -> [InventoryLevel]?{
		return await sendRequest(path: "inventories/page/\(pageNum)", method: "GET", expect: [InventoryLevel].self)
	}
	public func getAllInventories() async -> [InventoryLevel]? {
		let countGetter = {return await getCountOfAllResource(resource: .inventories)}
		let pageGetter = getInventoriesPage
		return await getAllPaginated(resourceName: Resource.inventories.rawValue, countGetter: countGetter, pageGetter: pageGetter)
	}
	
	public func getAllInventories(of locationID: Int) async -> [InventoryLevel]? {
		let countGetter = {return await sendRequest(path: "inventoriesCount/\(locationID)", method: "GET", expect: Wrapper<Int>.self).map(\.content)}
		let pageGetter:(Int)async->[InventoryLevel]? = {return await sendRequest(path: "inventories/\(locationID)/page/\($0)", method: "GET", expect: [InventoryLevel].self)}

		return await getAllPaginated(resourceName: "inventories of location \(locationID)", countGetter: countGetter, pageGetter: pageGetter)
	}
	
	public func getAllLocations() async -> [SHLocation]? {
		return await sendRequest(path: "locations", method: "GET", expect: [SHLocation].self)
	}
	//MARK: Network Requests
	func sendRequest(path: String, method: String)async -> Bool{
		return await sendRequest(path: path, method: method, body: Blank(), expect: Bool.self) ?? false
	}
	
	func sendRequest<T2: Decodable>(path: String, method: String, expect: T2.Type)async -> T2?{
		return await sendRequest(path: path, method: method, body: Blank(), expect: T2.self)
	}
	
	func sendRequest<T: Encodable>(path: String, method: String, body: T)async -> Bool{
		return await sendRequest(path: path, method: method, body: body, expect: Bool.self) ?? false
	}
	
	func sendRequest<T: Encodable, T2: Decodable>(path: String, method: String, body: T, expect: T2.Type)async ->T2?{
		let url = baseURL.customAppendingPath(path: path)
		var r: URLRequest = .init(url: url)
		r.httpMethod = method
		do{
			if T.self != Blank.self{
				let data = try encoder.encode(body)
				r.httpBody = data
			}
			do{
				let (respData, response) = try await session.asyncData(with: r)
				let urlResp = response as! HTTPURLResponse
				let wentOK = urlResp.statusCode >= 200 && urlResp.statusCode <= 299
				guard wentOK else {
					print("Error \(urlResp.statusCode) for request at \(url)")
					if T2.self == Bool.self{
						return (false as! T2)
					}
					return nil
				}
				guard expect != Bool.self else {return (true as! T2)}
				guard expect != Blank.self else {return (Blank() as! T2)}
				do{
					let decoded = try decoder.decode(expect, from: respData)
					return decoded
				}catch{
					print("Error decoding response: \(error)")
					return nil
				}
			}catch{
				print("Error sending request to \(url): \(error)")
				return nil
			}
		}catch{
			print("Error encoding payload: \(error)")
			return nil
		}
		
	}
	//MARK: Pagination
	public func getAllPaginated<T>(resourceName: String, countGetter: () async -> Int?, pageGetter: @escaping (Int) async -> [T]?) async -> [T]? {
		guard let count = await countGetter() else {print("Nil count for resource \(resourceName)!"); return nil}
		guard count>0 else {return []}
		var pages = count / Self.pageCapacity
		if (count % Self.pageCapacity != 0){pages+=1}
		
		print("For \(count) \(resourceName) will request \(pages) pages each containing \(Self.pageCapacity) items")

		let stuff = await withTaskGroup(of: [T]?.self, returning: [T]?.self){taskGroup in
			for i in 1...pages{
				taskGroup.addTask{await pageGetter(i)}
			}
			return await taskGroup.reduce([T]()){
				$0 + $1!
			}
		}
		
		return stuff
	}
}


func applyUpdate<Entry, Update, T>(on: inout Entry, using: WritableKeyPath<Entry,T?>, from: KeyPath<Update,T?>, from source:Update){
	if let updateProperty = source[keyPath: from]{
		on[keyPath: using] = updateProperty
	}
}
func applyUpdate<Entry, Update, T>(on: inout Entry, using: WritableKeyPath<Entry,T?>, from: KeyPath<Update,T>, from source:Update){
	on[keyPath: using] = source[keyPath: from]
}
func applyUpdate<Entry, Update, T>(on: inout Entry, using: WritableKeyPath<Entry,T>, from: KeyPath<Update,T?>, from source:Update){
	if let updateProperty = source[keyPath: from]{
		on[keyPath: using] = updateProperty
	}
}
func applyUpdate<Entry, Update, T>(on: inout Entry, using: WritableKeyPath<Entry,T>, from: KeyPath<Update,T>, from source:Update){
	on[keyPath: using] = source[keyPath: from]
}
let formatter = ISO8601DateFormatter()
protocol LastUpdated{
	var updatedAtOptional: String? {get set}
}
extension LastUpdated{
	mutating func markHasBeenUpdated(){
		self.updatedAtOptional = formatter.string(from: Date())
	}
}
extension SHVariant: LastUpdated{
	var updatedAtOptional: String?{
		get{updatedAt}
		set{updatedAt=newValue}
	}
}
extension SHProduct: LastUpdated{
	var updatedAtOptional: String?{
		get{updatedAt}
		set{updatedAt=newValue}
	}
}
extension SHLocation: LastUpdated{
	var updatedAtOptional: String?{
		get{updatedAt}
		set{if let newValue{updatedAt=newValue}}
	}
}
extension InventoryLevel: LastUpdated{
	var updatedAtOptional: String?{
		get{updatedAt}
		set{if let newValue{updatedAt=newValue}}
	}
}
extension SHVariant{
	mutating func applyUpdate(from update: SHVariantUpdate){
		func applyUpdate<T>(using: WritableKeyPath<SHVariant,T>, from: KeyPath<SHVariantUpdate,T?>){
			MockShopifyClient.applyUpdate(on: &self, using: using, from: from, from: update)
		}
		func applyUpdate<T>(using: WritableKeyPath<SHVariant,T?>, from: KeyPath<SHVariantUpdate,T?>){
			MockShopifyClient.applyUpdate(on: &self, using: using, from: from, from: update)
		}
		applyUpdate(using: \.title, from: \.title)
		applyUpdate(using: \.option1, from: \.option1)
		applyUpdate(using: \.option2, from: \.option2)
		applyUpdate(using: \.option3, from: \.option3)
		applyUpdate(using: \.barcode, from: \.barcode)
		applyUpdate(using: \.compareAtPrice, from: \.compare_at_price)
		applyUpdate(using: \.price, from: \.price)
		applyUpdate(using: \.sku, from: \.sku)
	}
}
extension SHVariant{
	init?(from: SHVariantUpdate, id: Int, prodID: Int, inventoryItemID: Int){
		guard let sku=from.sku else {return nil}
		self.init(id: id, productID: prodID, title: from.title ?? "default", price: from.price ?? "0", sku: sku, position: nil, inventoryPolicy: ._continue, compareAtPrice: from.compare_at_price, fulfillmentService: .manual, inventoryManagement: nil, option1: from.option1, option2: from.option2, option3: from.option3, createdAt: formatter.string(from: Date()), updatedAt: formatter.string(from: Date()), taxable: true, barcode: from.barcode, grams: nil, imageID: nil, weight: nil, weightUnit: nil, inventoryItemID: inventoryItemID, inventoryQuantity: nil, oldInventoryQuantity: nil, requiresShipping: nil, adminGraphqlAPIID: nil, inventoryLevel: nil)
	}
}
extension SHVariantUpdate{
	func numberOfOptions()->Int{
		var count = 0
		
		count += option1 != nil ? 1 : 0
		count += option2 != nil ? 1 : 0
		count += option3 != nil ? 1 : 0
		
		return count
	}
}
extension Array where Element == SHOption{
	mutating func applyUpdate(from update: Self, productID: Int, idGenerator: ()->Int){
		for optionUpdate in update{
			if let id = optionUpdate.id, let indexOfExisting = self.firstIndex(where: {$0.id == id}){
				MockShopifyClient.applyUpdate(on: &self[indexOfExisting], using: \.position, from: \.position, from: optionUpdate)
				MockShopifyClient.applyUpdate(on: &self[indexOfExisting], using: \.name, from: \.name, from: optionUpdate)
				MockShopifyClient.applyUpdate(on: &self[indexOfExisting], using: \.values, from: \.values, from: optionUpdate)
			}else{
				let new = SHOption(id: idGenerator(), productID: productID, name: optionUpdate.name, position: optionUpdate.position, values: optionUpdate.values)
				append(new)
			}
		}
	}
}
extension SHOption{
	mutating func applyUpdate(from: SHOption){
		
	}
}
public extension URL{
	func customAppendingPath(path: String)->Self{
		let u: URL = .init(string: path)!
		var s = self
		for p in u.pathComponents{
			s = s.appendingPathComponent(p)
		}
		return s
	}
}
