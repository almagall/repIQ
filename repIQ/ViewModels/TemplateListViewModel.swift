import Foundation
import Supabase

@Observable
final class TemplateListViewModel {
    var templates: [Template] = []
    var isLoading = false
    var errorMessage: String?

    private let templateService = TemplateService()

    func loadTemplates() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            templates = try await templateService.fetchTemplates(userId: userId)
        } catch {
            errorMessage = "Failed to load templates."
        }
        isLoading = false
    }

    func deleteTemplate(at offsets: IndexSet) async {
        for index in offsets {
            let template = templates[index]
            do {
                try await templateService.deleteTemplate(id: template.id)
                templates.remove(at: index)
            } catch {
                errorMessage = "Failed to delete template."
            }
        }
    }

    func deleteTemplate(_ template: Template) async {
        do {
            try await templateService.deleteTemplate(id: template.id)
            templates.removeAll { $0.id == template.id }
        } catch {
            errorMessage = "Failed to delete template."
        }
    }

    func duplicateTemplate(_ template: Template) async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let copy = try await templateService.duplicateTemplate(templateId: template.id, userId: userId)
            templates.append(copy)
        } catch {
            errorMessage = "Failed to duplicate template."
        }
    }
}
