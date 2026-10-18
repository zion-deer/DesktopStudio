import AppKit
import SwiftUI

struct DesktopCanvasView: View {
    @EnvironmentObject private var model: EditorModel
    var isInteractive: Bool = true

    @FocusState private var isFocused: Bool
    @State private var liveFrames: [UUID: ComponentFrame] = [:]
    @State private var gestureOrigin: ComponentFrame?
    @State private var activeGestureID: UUID?
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(
                width: model.selectedTheme.canvas.width,
                height: model.selectedTheme.canvas.height
            )
            let layout = CanvasLayout.fit(canvas: canvasSize, in: proxy.size)
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: layout.displaySize.width + 18, height: layout.displaySize.height + 18)
                        .shadow(color: .black.opacity(0.35), radius: 28, y: 16)
                        .accessibilityHidden(true)
                    desktop(layout)
                }
                if isInteractive {
                    Text("\(Int(model.selectedTheme.canvas.width)) × \(Int(model.selectedTheme.canvas.height)) display preview")
                        .font(.caption)
                        .foregroundStyle(StudioPalette.textTertiary)
                        .accessibilityLabel("Display preview, \(Int(model.selectedTheme.canvas.width)) by \(Int(model.selectedTheme.canvas.height)) points")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(StudioPalette.stage)
        .focusable(isInteractive)
        .focused($isFocused)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard isInteractive else { return }
            let step = NSEvent.modifierFlags.contains(.shift) ? 8.0 : 1.0
            switch direction {
            case .left: model.nudgeSelected(dx: -step, dy: 0)
            case .right: model.nudgeSelected(dx: step, dy: 0)
            case .up: model.nudgeSelected(dx: 0, dy: -step)
            case .down: model.nudgeSelected(dx: 0, dy: step)
            }
        }
        .onDeleteCommand {
            guard isInteractive else { return }
            model.deleteSelectedComponent()
        }
        .onDisappear {
            liveFrames.removeAll()
        }
        .accessibilityIdentifier(StudioAccessibilityID.canvas)
    }

    private func desktop(_ layout: CanvasLayout) -> some View {
        let theme = model.selectedTheme
        return ZStack(alignment: .topLeading) {
            wallpaper(theme, layout: layout)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isInteractive else { return }
                    model.select(nil)
                    isFocused = true
                }
            if isInteractive && model.showsGrid {
                GridOverlay(spacing: 80 * layout.scale)
                    .frame(width: layout.displaySize.width, height: layout.displaySize.height)
                    .allowsHitTesting(false)
            }
            LinearGradient(
                colors: [.clear, .black.opacity(0.16)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: layout.displaySize.width, height: layout.displaySize.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            if theme.components.isEmpty && isInteractive {
                VStack(spacing: 6) {
                    Text("Drop a component here")
                        .font(.headline)
                    Text("Or choose one from the library.")
                        .font(.callout)
                }
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(width: layout.displaySize.width, height: layout.displaySize.height)
                .allowsHitTesting(false)
            }
            ForEach(model.orderedComponents) { component in
                placedComponent(component, layout: layout)
            }
        }
        .frame(width: layout.displaySize.width, height: layout.displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(isDropTargeted ? 0.7 : 0.1),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        }
        .dropDestination(for: String.self) { items, location in
            guard isInteractive, let rawValue = items.first, let type = ComponentType(rawValue: rawValue) else {
                return false
            }
            let logical = layout.logicalPoint(fromDisplay: location)
            model.addComponent(type, centeredAt: CGPoint(x: logical.x, y: logical.y))
            isFocused = true
            return true
        } isTargeted: { targeted in
            if isInteractive {
                isDropTargeted = targeted
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Desktop preview")
    }

    private func wallpaper(_ theme: Theme, layout: CanvasLayout) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Group {
            switch theme.canvas.style {
            case .solid:
                theme.canvas.background.color
            case .gradient:
                LinearGradient(
                    colors: [theme.canvas.background.color, theme.canvas.gradientEnd.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: layout.displaySize.width, height: layout.displaySize.height)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private func placedComponent(_ component: DesktopComponent, layout: CanvasLayout) -> some View {
        let frame = liveFrames[component.id] ?? component.frame
        let rect = layout.displayRect(for: frame)
        let isSelected = model.selectedComponentID == component.id
        return ZStack(alignment: .bottomTrailing) {
            ComponentCardView(component: resolved(component, frame: frame), scale: layout.scale)
                .overlay {
                    if isInteractive && isSelected {
                        RoundedRectangle(cornerRadius: component.appearance.cornerRadius * layout.scale, style: .continuous)
                            .strokeBorder(StudioPalette.accent, lineWidth: 2)
                    }
                }
                .gesture(moveGesture(component, scale: layout.scale))
                .onTapGesture {
                    guard isInteractive else { return }
                    model.select(component.id)
                    isFocused = true
                }
            if isInteractive && isSelected {
                ResizeHandle()
                    .highPriorityGesture(resizeGesture(component, scale: layout.scale))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contextMenu {
            if isInteractive {
                Button("Duplicate") { model.duplicateComponent(id: component.id) }
                Button("Bring Forward") { model.bringForward(component.id) }
                Button("Send Backward") { model.sendBackward(component.id) }
                Divider()
                Button("Delete", role: .destructive) { model.deleteComponent(id: component.id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(component.type.libraryTitle), \(component.name)")
        .accessibilityHint(isInteractive ? "Selects this component. Drag to move it. Hold Option to ignore the grid." : "Preview of \(component.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Duplicate") { model.duplicateComponent(id: component.id) }
        .accessibilityAction(named: "Delete") { model.deleteComponent(id: component.id) }
        .accessibilityAction(named: "Bring Forward") { model.bringForward(component.id) }
        .accessibilityAction(named: "Send Backward") { model.sendBackward(component.id) }
    }

    private func resolved(_ component: DesktopComponent, frame: ComponentFrame) -> DesktopComponent {
        var copy = component
        copy.frame = frame
        return copy
    }

    private func moveGesture(_ component: DesktopComponent, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard isInteractive else { return }
                if activeGestureID != component.id || gestureOrigin == nil {
                    activeGestureID = component.id
                    gestureOrigin = component.frame
                    isFocused = true
                }
                guard let origin = gestureOrigin else { return }
                var x = origin.x + Double(value.translation.width / scale)
                var y = origin.y + Double(value.translation.height / scale)
                if !NSEvent.modifierFlags.contains(.option) {
                    x = EditorGeometry.snap(x)
                    y = EditorGeometry.snap(y)
                }
                liveFrames[component.id] = ComponentFrame(
                    x: x,
                    y: y,
                    width: origin.width,
                    height: origin.height,
                    zIndex: origin.zIndex
                ).clamped(to: model.selectedTheme.canvas)
            }
            .onEnded { _ in
                model.select(component.id)
                commitLiveFrame(for: component.id)
            }
    }

    private func resizeGesture(_ component: DesktopComponent, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isInteractive else { return }
                if activeGestureID != component.id || gestureOrigin == nil {
                    activeGestureID = component.id
                    gestureOrigin = liveFrames[component.id] ?? component.frame
                }
                guard let origin = gestureOrigin else { return }
                var width = origin.width + Double(value.translation.width / scale)
                var height = origin.height + Double(value.translation.height / scale)
                if !NSEvent.modifierFlags.contains(.option) {
                    width = EditorGeometry.snap(width)
                    height = EditorGeometry.snap(height)
                }
                liveFrames[component.id] = ComponentFrame(
                    x: origin.x,
                    y: origin.y,
                    width: width,
                    height: height,
                    zIndex: origin.zIndex
                ).clamped(to: model.selectedTheme.canvas)
            }
            .onEnded { _ in
                commitLiveFrame(for: component.id)
            }
    }

    private func commitLiveFrame(for id: UUID) {
        if let frame = liveFrames[id] {
            model.setFrame(id: id, frame: frame)
        }
        liveFrames[id] = nil
        gestureOrigin = nil
        activeGestureID = nil
    }
}

private struct GridOverlay: View {
    var spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            guard spacing > 4 else { return }
            var x: CGFloat = 0
            while x <= size.width + 0.5 {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height + 0.5 {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ResizeHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(StudioPalette.accent, lineWidth: 2))
            .frame(width: 12, height: 12)
            .padding(8)
            .contentShape(Rectangle())
            .accessibilityLabel("Resize")
            .help("Drag to resize. Hold Option to ignore the grid.")
    }
}
