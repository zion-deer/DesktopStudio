import SwiftUI

struct InspectorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioPalette.textTertiary)
                .textCase(.uppercase)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InspectorSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var model: EditorModel
    var format: String = "%.0f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.callout)
                Spacer()
                Text(String(format: format, value))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(StudioPalette.textSecondary)
                    .accessibilityHidden(true)
            }
            Slider(value: $value, in: range, step: step) { editing in
                if !editing {
                    model.endContinuousEdit()
                }
            }
            .accessibilityLabel(title)
            .accessibilityValue(String(format: format, value))
        }
    }
}

struct InspectorNumberField: View {
    var title: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 92)
                .accessibilityLabel(title)
        }
        .font(.callout)
    }
}

struct ColorField: View {
    var title: String
    @Binding var color: ThemeColor
    @State private var hexDraft = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
            HStack(spacing: 8) {
                ColorPicker(title, selection: colorBinding, supportsOpacity: true)
                    .labelsHidden()
                    .accessibilityLabel(title)
                TextField("Hex", text: $hexDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .focused($hexFocused)
                    .onSubmit(commitHex)
                    .accessibilityLabel("\(title) hex")
            }
            Text(opacityLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(StudioPalette.textTertiary)
                .accessibilityHidden(true)
        }
        .onAppear { hexDraft = color.hex }
        .onChange(of: color.hex) { _, newValue in
            if !hexFocused {
                hexDraft = newValue
            }
        }
        .onChange(of: hexDraft) { _, newValue in
            guard hexFocused, let normalized = ThemeColor.normalize(newValue) else { return }
            let updated = ThemeColor(hex: normalized, opacity: color.opacity)
            if updated != color {
                color = updated
            }
        }
        .onChange(of: hexFocused) { _, focused in
            if !focused {
                commitHex()
            }
        }
    }

    private var opacityLabel: String {
        "Opacity \(Int((color.opacity * 100).rounded()))%"
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { color.color },
            set: { color = ThemeColor(color: $0) }
        )
    }

    private func commitHex() {
        if let normalized = ThemeColor.normalize(hexDraft) {
            let updated = ThemeColor(hex: normalized, opacity: color.opacity)
            if updated != color {
                color = updated
            }
            hexDraft = updated.hex
        } else {
            hexDraft = color.hex
        }
    }
}
