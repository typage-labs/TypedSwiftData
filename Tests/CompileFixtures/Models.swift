import SwiftData

@Model final class Restaurant {
    var name: String
    init(name: String) { self.name = name }
}

@Model final class Customer {
    var name: String
    init(name: String) { self.name = name }
}
