import TypedSwiftData

@available(macOS 26, iOS 26, *)
func wrong(_ cafe: Cafe) {
    let _: ModelID<Venue> = cafe.typedID // expected-error: cannot assign value of type 'ModelID<Cafe>' to type 'ModelID<Venue>'
}
