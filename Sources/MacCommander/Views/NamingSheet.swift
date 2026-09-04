import SwiftUI

struct NamingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prompt: NamingPrompt
    let submit: (String) -> Void
    @State private var value: String

    init(prompt: NamingPrompt, submit: @escaping (String) -> Void) {
        self.prompt = prompt
        self.submit = submit
        _value = State(initialValue: prompt.initialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt.title).font(.headline)
            Text(prompt.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            TextField("Name", text: $value)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
                .controlTooltip("Enter the new name", shortcut: "Return to save")
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlTooltip("Cancel without saving", shortcut: "Esc")
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlTooltip("Save the new name", shortcut: "Return")
            }
        }
        .padding(20)
        .frame(width: 430)
    }

    private func save() {
        submit(value)
        dismiss()
    }
}
