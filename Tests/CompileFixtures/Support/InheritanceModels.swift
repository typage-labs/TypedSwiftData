import SwiftData

@available(macOS 26, iOS 26, *)
@Model class Venue {
    var name: String
    init(name: String) { self.name = name }
}

@available(macOS 26, iOS 26, *)
@Model final class Cafe: Venue {
    var seats: Int
    init(name: String, seats: Int) {
        self.seats = seats
        super.init(name: name)
    }
}
