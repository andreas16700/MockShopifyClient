//
//  MockShopifyStore.swift
//  
//
//  Created by Andreas Loizides on 14/12/2022.
//

import Foundation
import ShopifyClient

public actor MockShopifyStore
//: ShopifyClientProtocol
{
	public init(products: [SHProduct], locations: [SHLocation], inventoriesByLocationID: [Int : [InventoryLevel]]) {
		self.productsByID = products.reduce(into: [Int: SHProduct]()){dict, prod in
			dict[prod.id!]=prod
		}
		self.locations = locations
		self.inventoriesByLocationID = inventoriesByLocationID
	}
	
	var productsByID: [Int: SHProduct]
	var locations: [SHLocation]
	var inventoriesByLocationID: [Int: [InventoryLevel]]
	
	//MARK: Public
	public func deleteVariant(ofProductID productID: Int, variantID: Int) async -> Bool {
		guard let variantIndex = indexOfVariant(productID: productID, variantID: variantID) else {return false}
		productsByID[productID]!.variants.remove(at: variantIndex)
		return true
	}
	
	public func updateVariant(with update: SHVariantUpdate) async -> SHVariant? {
		guard let variantID = update.id else{
			reportError("Variant updated does not contain an id!")
			return nil
		}
		guard let (productID, variantIndex) = productIDAndIndexOfVariant(variantID: variantID)else{return nil}
		
		
		let existingVariant = productsByID[productID]!.variants[variantIndex]
		
		
		return nil
	}
	
	public func createNewVariant(variant: SHVariantUpdate, for productID: Int) async -> SHVariant? {
		nil
	}
	
	public func deleteProduct(id: Int) async -> Bool {
		return productsByID.removeValue(forKey: id) != nil
	}
	
	public func updateProduct(with update: SHProductUpdate) async -> SHProduct? {
		nil
	}
	
	public func createNewProduct(new given: SHProduct) async -> SHProduct? {
		var new = given
		if new.id == nil{
			let id = Int.random(in: 12345...99999)
			new.id=id
		}
		productsByID[new.id!] = new
		
		//TODO more processing
		
		return new
	}
	
	public func getAllProducts() async -> [SHProduct]? {
		return Array(productsByID.values)
	}
	
	public func getProduct(withHandle handle: String) async -> SHProduct? {
		nil
	}
	
	public func getProduct(withID id: Int) async -> SHProduct? {
		nil
	}
	
	public func getIDOfProduct(withHandle handle: String) async -> Int? {
		nil
	}
	
	public func updateInventory(current currentGiven: InventoryLevel, update: SHInventorySet) async -> InventoryLevel? {
		guard locations.contains(where: {$0.id == currentGiven.locationID}) else {
			reportError("Location \(currentGiven.locationID) does not exist on store")
			return nil
		}
		guard let locationInventories = inventoriesByLocationID[currentGiven.locationID]else{
			reportError("Location \(currentGiven.locationID) is empty!")
			return nil
		}
		
		guard let indexOfCurrent = locationInventories.firstIndex(where: {$0.inventoryItemID == currentGiven.inventoryItemID}) else{
			reportError("Location \(currentGiven.inventoryItemID) does not exist on location \(currentGiven.locationID)")
			return nil
		}
		inventoriesByLocationID[currentGiven.locationID]![indexOfCurrent].available = update.available
		return inventoriesByLocationID[currentGiven.locationID]![indexOfCurrent]
	}
	
	public func getInventory(of invItemID: Int) async -> InventoryLevel? {
		for (_, invs) in inventoriesByLocationID{
			if let found = invs.first(where: {$0.inventoryItemID == invItemID}){
				return found
			}
		}
		return nil
	}
	
	public func getAllInventories() async -> [InventoryLevel]? {
		return inventoriesByLocationID.values.reduce(into: [InventoryLevel](), {$0.append(contentsOf: $1)})
	}
	
	public func getAllInventories(of locationID: Int) async -> [InventoryLevel]? {
		return inventoriesByLocationID[locationID]
	}
	
	public func getAllLocations() async -> [SHLocation]? {
		return locations
	}
	
	//MARK: Private
	private func reportError(_ msg: String){
		print(msg)
	}
	private func productIDAndIndexOfVariant(variantID: Int)->(Int,Int)?{
		guard let productID = productsByID.first(where: {$0.value.variants.contains(where: {v in v.id == variantID})})?.key else {
			reportError("No variant with id \(variantID)")
			return nil
		}
		let variantIndex = productsByID[productID]!.variants.firstIndex(where: {$0.id == variantID})!
		return (productID,variantIndex)
	}
	
	private func indexOfVariant(productID: Int, variantID: Int)->Int?{
		if let product = productsByID[productID]{
			if let variantIndex = product.variants.firstIndex(where: {$0.id == variantID}){
				return variantIndex
			}
			reportError("product \(productID) has no variant \(variantID)")
		}
		reportError("no product with id \(productID)")
		return nil
	}
	
	//MARK: Variants
	private func applyUpdate(_ existing: SHVariant, _ update: SHVariantUpdate)->SHVariant?{
		var updated = existing
		func applyUpdate<T>(kp: WritableKeyPath<SHVariant,T?>, kp2: KeyPath<SHVariantUpdate,T?>){
			if let newP = update[keyPath: kp2]{
				updated[keyPath: kp]=newP
			}
		}
		func applyUpdate<T>(kp: WritableKeyPath<SHVariant,T>, kp2: KeyPath<SHVariantUpdate,T?>){
			if let newP = update[keyPath: kp2]{
				updated[keyPath: kp]=newP
			}
		}
		applyUpdate(kp: \.title, kp2: \.title)
		return updated
	}
	//MARK: General
	
	
	private func processCurrentAndReturnIfPossible<T: LastUpdated & Hashable>(get: ()async->T?, set: (T)async->T?, _ process: (inout T)async->())async ->T?{
		guard var thing = await get() else {return nil}
		let beforeProcessing = thing
		await process(&thing)
		
		if beforeProcessing != thing {thing.markHasBeenUpdated()}
		
		return await set(thing)
	}
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
