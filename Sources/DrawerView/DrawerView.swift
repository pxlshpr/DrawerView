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

public struct DrawerView<Content: View>: View {

    class ViewModel: ObservableObject {
        @Published var isIgnoringHorizontalDrag: Bool = false
    }
    
    @StateObject var vm: ViewModel = ViewModel()

    @Binding var drawerSection: DrawerViewDragSection
    
    @Binding var drawerProgress: Double
    @Binding var isDragging: Bool
    @Binding var isEnabled: Bool
    @Binding var drawerContentHeight: Double
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
    
    public init(drawerSection: Binding<DrawerViewDragSection>,
                drawerProgress: Binding<Double>,
                drawerContentHeight: Binding<Double>,
                isDragging: Binding<Bool>,
                isEnabled: Binding<Bool> = .constant(true),
                isFullScreenWhenExpanded: Bool = false,
                showHandle: Bool = true,
                roundedCorners: Bool = true,
                @ViewBuilder content: @escaping () -> Content,
                onStateChange: ((DrawerViewState) -> ())? = nil) {
        self._drawerSection = drawerSection
        self._drawerProgress = drawerProgress
        self._drawerContentHeight = drawerContentHeight
        self._isDragging = isDragging
        self._isEnabled = isEnabled
        
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

extension DrawerView {
    
    private func dynamicValue(collapsed: CGFloat, regular: CGFloat, expanded: CGFloat) -> CGFloat {
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
    
}
