import Foundation
import SwiftData
import SwiftUI

@Model
class DocumentModel {
    var document: Document

    init(document: Document) {
        self.document = document
    }
}

extension DocumentModel: Identifiable {
    var id: UUID { document.id }
}

struct DocumentQueryModifier: ViewModifier {
    @Query private var documents: [DocumentModel]

    func body(content: Content) -> some View {
        content.onChange(of: documents) {}
    }
}
