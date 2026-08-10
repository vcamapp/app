import Foundation
import Testing
import VCamEntity
@testable import VCamData

@Suite
struct ModelItemTests {
    @Test
    func equalityIncludesMutableContent() {
        let id = UUID()
        let model = Models.Model(
            id: id,
            name: "model",
            displayName: "Original",
            type: Models.modelType,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let original = ModelItem(model: model, status: .valid, thumbnail: Data([0]))

        var renamedModel = model
        renamedModel.displayName = "Renamed"
        let renamed = ModelItem(model: renamedModel, status: .valid, thumbnail: Data([0]))
        let missing = ModelItem(model: model, status: .missing, thumbnail: Data([0]))
        let changedThumbnail = ModelItem(model: model, status: .valid, thumbnail: Data([1]))

        #expect(original != renamed)
        #expect(original != missing)
        #expect(original != changedThumbnail)
        #expect(Set([original, renamed, missing, changedThumbnail]).count == 4)
    }
}
