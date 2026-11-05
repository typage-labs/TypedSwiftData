import TypedSwiftData

func wrong(_ customer: Customer) {
    let _: ModelID<Restaurant> = customer.typedID // expected-error: cannot (?:assign|convert) value of type 'ModelID<Customer>' to (?:expected argument )?type 'ModelID<Restaurant>'
}
