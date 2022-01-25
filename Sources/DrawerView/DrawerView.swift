import SwiftUI
import SwiftHaptics

let CollapsedHeight = 98.0
let RegularHeight = 176.0

let RegularOffset = CollapsedHeight - RegularHeight
let CollapsedOffset = CollapsedHeight - CollapsedHeight

public enum DrawerViewDragSection {
    case collapsedRegular
    case regularExpanded
}

public struct DrawerView<Content: View>: View {

    @Binding public var drawerSection: DrawerViewDragSection
    @Binding public var drawerProgress: Double
    @Binding public var drawerContentHeight: Double
    public var content: () -> Content
    
    @Environment(\.scenePhase) var scenePhase

    @State var offset: CGFloat = 0
    @State var lastOffset: CGFloat = 0
    @GestureState var gestureOffset: CGFloat = 0
    @State var lastDragValue: DragGesture.Value? = nil
    
//    init(@ViewBuilder content: @escaping () -> Content) {
//        self.content = content
//    }
    
    public var body: some View {
        GeometryReader { proxy -> AnyView in
            
            let height = proxy.frame(in: .global).height
            return AnyView (
                ZStack {
                    background
                        .shadow(radius: 1.0)
                    VStack(spacing: 0) {
                        handle
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
        .ignoresSafeArea(.all, edges: .bottom)
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
            .clipShape(CustomCorner(corners: [.topLeft, .topRight], radius: 18))
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

struct CustomCorner: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
