import Testing
@testable import BabyCare

struct BabyLimitTests {
    @Test func fourBabiesCanSwitchAndRetryButCannotAddFifth() throws {
        var db = CareDatabase()
        for i in 1...4 { db = try db.applying(.createBaby(BabyProfile(name: "Bé \(i)"))) }
        let first = try #require(db.babies.first?.profile)
        db = try db.applying(.createBaby(first))
        #expect(db.babies.count == 4)
        db = try db.applying(.selectBaby(first.id))
        #expect(db.selectedBabyID == first.id)
        #expect(throws: CareDataError.self) { try db.applying(.createBaby(BabyProfile(name: "Bé 5"))) }
        #expect(db.babies.count == 4)
    }
}
