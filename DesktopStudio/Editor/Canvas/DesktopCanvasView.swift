import AppKit
import SwiftUI

struct DesktopCanvasView: View {
    @EnvironmentObject private var model: EditorModel
    var themeOverride: Theme?
    var isInteractive: Bool = true

    private var displayTheme: Theme { themeOverride ?? model.selectedTheme }

    @FocusState private var isFocused: Bool
    @State private var liveFrames: [UUID: ComponentFrame] = [:]
    @State private var gestureOrigin: ComponentFrame?
    @State private var activeGestureID: UUID?
    @State private var activeGuides: [AlignmentGuide] = []
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(
                width: displayTheme.canvas.width,
                height: displayTheme.canvas.height
            )
            let zoom = isInteractive ? CGFloat(model.canvasZoom) : 1
            let layout = CanvasLayout.fit(canvas: canvasSize, in: proxy.size, zoom: zoom)
            ScrollView([.horizontal, .vertical]) {
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
                        canvasFooter
                    }
                }
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
            activeGuides.removeAll()
        }
        .accessibilityIdentifier(StudioAccessibilityID.canvas)
    }

    private var canvasFooter: some View {
        HStack(spacing: 12) {
            Text("\(Int(displayTheme.canvas.width)) × \(Int(displayTheme.canvas.height)) canvas")
                .accessibilityLabel("Canvas layout, \(Int(displayTheme.canvas.width)) by \(Int(displayTheme.canvas.height)) points. Zoom does not change this size.")
            Spacer(minLength: 8)
            zoomControls
        }
        .font(.caption)
        .foregroundStyle(StudioPalette.textTertiary)
        .padding(.horizontal, 8)
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button {
                model.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Zoom out")
            .help("Zoom out. Command-minus.")

            Text("\(model.canvasZoomPercent)%")
                .monospacedDigit()
                .frame(minWidth: 44)
                .accessibilityLabel("Zoom \(model.canvasZoomPercent) percent")

            Button {
                model.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Zoom in")
            .help("Zoom in. Command-plus.")

            Button("Fit") {
                model.resetCanvasZoom()
            }
            .accessibilityLabel("Fit canvas")
            .help("Reset zoom to 100 percent. Command-0.")
        }
        .buttonStyle(.borderless)
    }

    private func desktop(_ layout: CanvasLayout) -> some View {
        let theme = displayTheme
        return ZStack(alignment: .topLeading) {
            wallpaper(theme, layout: layout)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isInteractive else { return }
                    model.select(nil)
                    isFocused = true
                }
            if isInteractive && model.showsGrid {
                let unit = EditorGeometry.grid * layout.displayScale
                GridOverlay(spacing: unit >= 6 ? unit : unit * 8)
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
            ForEach(orderedComponents(in: theme)) { component in
                placedComponent(component, layout: layout, theme: theme)
            }
            if isInteractive {
                AlignmentGuideOverlay(guides: activeGuides, layout: layout)
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

    private func orderedComponents(in theme: Theme) -> [DesktopComponent] {
        theme.components.sorted { lhs, rhs in
            if lhs.frame.zIndex == rhs.frame.zIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.frame.zIndex < rhs.frame.zIndex
        }
    }

    private func placedComponent(_ component: DesktopComponent, layout: CanvasLayout, theme: Theme) -> some View {
        let frame = liveFrames[component.id] ?? component.frame
        let rect = layout.displayRect(for: frame)
        let isSelected = isInteractive && model.selectedComponentID == component.id
        let appearance = StyleResolver.resolve(component, theme: theme)
        return ZStack {
            ComponentCardView(
                component: resolved(component, frame: frame),
                appearance: appearance,
                spacing: theme.globals.spacing,
                scale: layout.displayScale
            )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: appearance.cornerRadius * layout.displayScale, style: .continuous)
                            .strokeBorder(StudioPalette.accent, lineWidth: 2)
                    }
                }
                .gesture(moveGesture(component, layout: layout))
                .onTapGesture {
                    guard isInteractive else { return }
                    model.select(component.id)
                    isFocused = true
                }
        }
        .frame(width: rect.width, height: rect.height)
        .overlay(alignment: .topLeading) {
            if isInteractive && isSelected {
                resizeHandle(component, corner: .topLeading, layout: layout)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isInteractive && isSelected {
                resizeHandle(component, corner: .topTrailing, layout: layout)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isInteractive && isSelected {
                resizeHandle(component, corner: .bottomLeading, layout: layout)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isInteractive && isSelected {
                resizeHandle(component, corner: .bottomTrailing, layout: layout)
            }
        }
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
        .accessibilityHint(isInteractive ? "Selects this component. Drag to move it. Hold Option to ignore snapping." : "Preview of \(component.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Duplicate") { model.duplicateComponent(id: component.id) }
        .accessibilityAction(named: "Delete") { model.deleteComponent(id: component.id) }
        .accessibilityAction(named: "Bring Forward") { model.bringForward(component.id) }
        .accessibilityAction(named: "Send Backward") { model.sendBackward(component.id) }
    }

    private func resizeHandle(_ component: DesktopComponent, corner: ResizeCorner, layout: CanvasLayout) -> some View {
        ResizeHandle(label: corner.accessibilityLabel)
            .highPriorityGesture(resizeGesture(component, corner: corner, layout: layout))
    }

    private func resolved(_ component: DesktopComponent, frame: ComponentFrame) -> DesktopComponent {
        var copy = component
        copy.frame = frame
        return copy
    }

    private func moveGesture(_ component: DesktopComponent, layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard isInteractive else { return }
                if activeGestureID != component.id || gestureOrigin == nil {
                    activeGestureID = component.id
                    gestureOrigin = component.frame
                    isFocused = true
                }
                guard let origin = gestureOrigin else { return }
                let translation = layout.canvasTranslation(fromDisplay: value.translation)
                let freePosition = NSEvent.modifierFlags.contains(.option)
                let others = displayTheme.components
                    .filter { $0.id != component.id }
                    .map(\.frame)
                let result = LayoutAlignment.translated(
                    origin: origin,
                    dx: translation.x,
                    dy: translation.y,
                    others: others,
                    canvas: displayTheme.canvas,
                    snapToGrid: !freePosition,
                    align: !freePosition
                )
                liveFrames[component.id] = result.frame
                activeGuides = result.guides
            }
            .onEnded { _ in
                model.select(component.id)
                commitLiveFrame(for: component.id)
            }
    }

    private func resizeGesture(_ component: DesktopComponent, corner: ResizeCorner, layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isInteractive else { return }
                if activeGestureID != component.id || gestureOrigin == nil {
                    activeGestureID = component.id
                    gestureOrigin = liveFrames[component.id] ?? component.frame
                }
                guard let origin = gestureOrigin else { return }
                let translation = layout.canvasTranslation(fromDisplay: value.translation)
                let freePosition = NSEvent.modifierFlags.contains(.option)
                let others = displayTheme.components
                    .filter { $0.id != component.id }
                    .map(\.frame)
                let result = LayoutAlignment.resized(
                    origin: origin,
                    corner: corner,
                    dx: translation.x,
                    dy: translation.y,
                    others: others,
                    canvas: displayTheme.canvas,
                    snapToGrid: !freePosition,
                    align: !freePosition
                )
                liveFrames[component.id] = result.frame
                activeGuides = result.guides
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
        activeGuides.removeAll()
    }
}

private struct AlignmentGuideOverlay: View {
    var guides: [AlignmentGuide]
    var layout: CanvasLayout

    var body: some View {
        Canvas { context, size in
            for guide in guides {
                var path = Path()
                switch guide.axis {
                case .vertical:
                    let x = CGFloat(guide.canvasPosition) * layout.displayScale
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                case .horizontal:
                    let y = CGFloat(guide.canvasPosition) * layout.displayScale
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(StudioPalette.accent.opacity(0.95)), lineWidth: 1)
            }
        }
        .frame(width: layout.displaySize.width, height: layout.displaySize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GridOverlay: View {
    var spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            guard spacing > 2 else { return }
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
    var label: String

    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(StudioPalette.accent, lineWidth: 2))
            .frame(width: 12, height: 12)
            .padding(6)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .help("\(label). Hold Option to ignore snapping.")
    }
}
