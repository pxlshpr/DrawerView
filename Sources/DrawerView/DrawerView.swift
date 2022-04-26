import SwiftUI
import SwiftHaptics
import SwiftUISugar

let CollapsedHeight = 98.0
let RegularHeight = 176.0

let RegularOffset = CollapsedHeight - RegularHeight
let CollapsedOffset = CollapsedHeight - CollapsedHeight

public enum DrawerViewDragSection {
    case collapsedRegular
    case regularExpanded
}

public enum DrawerViewState {
    case collapsed
    case regular
    case expanded
}

public class DrawerViewModel: ObservableObject {
    @Published public var isDragging: Bool = false
    @Published public var contentHeight: Double = 0.0
    
    @Published var drawerSection: DrawerViewDragSection = .collapsedRegular
    @Published var drawerProgress: Double = 0.0
    var isEnabled: Bool = true
//    var isIgnoringHorizontalDrag: Bool = false

    @Published var manualState: DrawerViewState = .collapsed
    
    public func setState(_ state: DrawerViewState) {
        self.manualState = state
    }
    
    public func toggleState() {
        guard !isDragging else { return }
        switch drawerSection {
        case .collapsedRegular:
            setState(.expanded)
        case .regularExpanded:
            if drawerProgress == 1.0 {
                setState(.collapsed)
            } else {
                setState(.expanded)
            }
        }
    }
    
    public init() {
        
    }
}

public struct DrawerView<Content: View>: View {
    @ObservedObject var vm: DrawerViewModel
    
    var content: () -> Content
    
    @Environment(\.scenePhase) var scenePhase

    @State var offset: CGFloat = 0
    @State var lastOffset: CGFloat = 0
    @GestureState var gestureOffset: CGFloat = 0
    @State var lastDragValue: DragGesture.Value? = nil
    
    @State var showHandle: Bool
    @State var isFullScreenWhenExpanded: Bool
    @State var roundedCorners: Bool
    
    var onStateChange: ((DrawerViewState) -> ())?
    
    public init(viewModel: DrawerViewModel,
                isFullScreenWhenExpanded: Bool = false,
                showHandle: Bool = true,
                roundedCorners: Bool = true,
                @ViewBuilder content: @escaping () -> Content,
                onStateChange: ((DrawerViewState) -> ())? = nil) {
        self.vm = viewModel
        
        self._showHandle = State(initialValue: showHandle)
        self._isFullScreenWhenExpanded = State(initialValue: isFullScreenWhenExpanded)
        self._roundedCorners = State(initialValue: roundedCorners)
        
        self.content = content
        self.onStateChange = onStateChange
    }
    
    public var body: some View {
        GeometryReader { proxy -> AnyView in
            
            let height = proxy.frame(in: .global).height
            return AnyView (
                ZStack {
                    background
                        .shadow(radius: 1.0)
                    VStack(spacing: 0) {
                        if showHandle {
                            handle
                        }
                        VStack(spacing: 0, content: content)
//                        Spacer()
//                        StatsView()
                    }
                    .clipped()
                    .frame(height: .infinity, alignment: .top)
                }
                    .offset(y: height - CollapsedHeight)
                    .offset(y: -offset > 0 ? -offset <= (height - CollapsedHeight) ? offset : -(height - CollapsedHeight) : 0)
                    .simultaneousGesture(dragGesture(height: height))
                    .onChange(of: scenePhase, perform: {
                        scenePhaseChanged($0, height: height)
                    })
                    .onAppear {
                        updateProgress(height: height)
                    }
            )
        }
        .ignoresSafeArea(.all, edges: isFullScreenWhenExpanded ? .all : .bottom)
        .onChange(of: vm.manualState) { newValue in
            changeState(to: newValue)
        }
    }
    
    func scenePhaseChanged(_ phase: ScenePhase, height: CGFloat) {
        switch phase {
        case .active: completeTransientStateChange(height: height)
        case .background:
            break
//            log.verbose("ScenePhase: background")
        case .inactive: completeTransientStateChange(height: height)
        @unknown default:
            break
//            log.verbose("ScenePhase: unexpected state")
        }
    }
    
    var background: some View {
        Spacer()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .if(roundedCorners, transform: { view in
                view.clipShape(CustomCorner(corners: [.topLeft, .topRight], radius: 18))
            })
    }
    
    var handle: some View {
        Capsule()
            .fill(Color("Handle"))
            .frame(width: 36, height: 5)
            .padding(.vertical, 5)
    }
    
    func getBlurRadius() -> CGFloat {
        let offset = offset + 73.0
        let progress = -offset / (UIScreen.main.bounds.height - 100)
//        log.verbose("progress: \(progress) for offset: \(offset)")
        return progress * 20
    }
}

public extension DrawerViewModel {
    
    func dynamicValue(collapsed: CGFloat, regular: CGFloat, expanded: CGFloat) -> CGFloat {
        let lower: CGFloat
        let range: CGFloat
        if drawerSection == .collapsedRegular {
            lower = collapsed
            range = regular-collapsed
        } else {
            lower = regular
            range = expanded-regular
        }
        
        return lower + (drawerProgress * range)
    }
    
    /// Shorthand for getting a dynamic value where order of values are (collapsed, regular, expanded)
    func dv(_ values: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        dynamicValue(collapsed: values.0, regular: values.1, expanded: values.2)
    }
    
    /// Shorthand for getting a dynamic value where collapsed and regular are the same
    func dv(_ values: (CGFloat, CGFloat)) -> CGFloat {
        dynamicValue(collapsed: values.0, regular: values.0, expanded: values.1)
    }
}
