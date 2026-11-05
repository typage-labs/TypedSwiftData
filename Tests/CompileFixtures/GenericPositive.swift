import SwiftData
import TypedSwiftData

protocol NamedModel: PersistentModel { var name: String { get } }
extension Restaurant: NamedModel {}

func identifier<T: NamedModel>(_ model: T) -> ModelID<T> { model.typedID }

func consume<T: PersistentModel>(_ model: T, in context: ModelContext) {
    let id: ModelID<T> = model.typedID
    let _: T? = context.registeredModel(for: id)
}

func genericAndOpenedExistential(_ restaurant: Restaurant, context: ModelContext) {
    let _: ModelID<Restaurant> = identifier(restaurant)
    let erased: any PersistentModel = restaurant
    // The existential can be opened at a generic call site. The typed ID stays
    // inside consume(), where its concrete type is known to the compiler.
    consume(erased, in: context)
}
