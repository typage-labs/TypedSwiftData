import SwiftData
import TypedSwiftData

func erased(_ model: any PersistentModel) {
    let _ = model.typedID // expected-error: member 'typedID' cannot be used on value of type 'any PersistentModel'; consider using a generic constraint instead
}
