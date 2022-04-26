import SwiftUI
import SwiftHaptics

extension DrawerView {
    
    internal func dragGesture(height: CGFloat) -> some Gesture {
        DragGesture().updating($gestureOffset, body: { value, out, _ in
            guard vm.isEnabled else {
                out = 0
                return
            }
            out = value.translation.height
            onDragChanged(value: value, height: height)
        }).onEnded { value in
            
            /// reset these for the next drag
//            vm.isIgnoringHorizontalDrag = false
            vm.isEnabled = true
            
            /// Only complete drags that had begun (ie, vertical ones)
            guard vm.isDragging else { return }
            onDragEnded(value: value, height: height)
        }
    }
    
    //MARK: - Drag Events
    private func onDragChanged(value: DragGesture.Value, height: CGFloat) {
        /// Ignore horizontal translations, checking for them at the beginning
        if !vm.isDragging {
            guard abs(value.translation.width) < abs(value.translation.height) else {
                vm.isEnabled = false
//                vm.isIgnoringHorizontalDrag = true
                return
            }
        }
        
        /// ignore all continuing drags that began as horizontal, regardless of if they turn vertical halfway through
        guard vm.isEnabled else {
            return
        }
        
        DispatchQueue.main.async {
            self.vm.isDragging = true
            self.offset = gestureOffset + lastOffset
            self.lastDragValue = value
            self.updateProgress(height: height)
        }
    }
    
    func completeTransientStateChange(height: CGFloat) {

        guard offset != 0 else {
            return
        }
        
        let maxHeight = height - CollapsedHeight

        withAnimation(.interactiveSpring()) {
            if offset > RegularOffset {
//                log.verbose("\(offset) > \(RegularOffset), setting to Collapsed")
//                offset = CollapsedOffset
                changeState(to: .collapsed)
            } else if offset > (-maxHeight/2.0) {
//                log.verbose("\(offset) > \(-maxHeight/2.0), setting to Regular")
//                offset = RegularOffset
                changeState(to: .regular)
            } else {
//                log.verbose("Setting to maxHeight")
//                offset = -maxHeight
                changeState(to: .expanded, maxHeight: maxHeight)
            }
            updateProgress(height: height)
            lastOffset = offset
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                vm.isDragging = false
            }
        }
    }
    
    func changeState(to state: DrawerViewState, maxHeight: CGFloat = 0) {
        
        switch state {
        case .collapsed:
            offset = CollapsedOffset
        case .regular:
            offset = RegularOffset
        case .expanded:
            offset = -maxHeight
        }
        onStateChange?(state)
    }
    
    func updateProgress(height: CGFloat) {
        var progress: CGFloat
        if offset >= RegularOffset {
            progress = -offset / (CollapsedOffset - RegularOffset)
            progress = max(0, progress)
            vm.drawerSection = .collapsedRegular
        } else {
            let offsetDiff = offset - RegularOffset
            let maxHeight = height - CollapsedHeight
            progress = -offsetDiff / (RegularOffset - (-maxHeight))
            progress = min(1, progress)
            vm.drawerSection = .regularExpanded
        }
        vm.drawerProgress = progress
        
        setContentHeight(for: height)
    }
    
    func setContentHeight(for height: CGFloat) {
        let bottomPadding: CGFloat
        ///Source: https://stackoverflow.com/a/68709575
        let keyWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
        if let window = keyWindow {
            bottomPadding = window.safeAreaInsets.bottom
        } else {
            bottomPadding = 0
        }

        let safeOffset = max(min(offset, 0), -(height-CollapsedHeight))
        let handleHeight: CGFloat = 5 + 5 + 5
        let startingHeight = CollapsedHeight - handleHeight - bottomPadding
        vm.contentHeight = -safeOffset + startingHeight
    }
    
    private func onDragEnded(value: DragGesture.Value, height: CGFloat) {
        guard let lastDragPosition = self.lastDragValue else {
            vm.isDragging = false
            return
        }
        
        let timeDiff = value.time.timeIntervalSince(lastDragPosition.time)
        let speed = CGFloat(value.translation.height - lastDragPosition.translation.height) / CGFloat(timeDiff)
        let isDownwards = speed > 0
        
        let maxHeight = height - CollapsedHeight
        
        withAnimation(.interactiveSpring()) {
            
            Haptics.feedback(style: .soft)
            if abs(speed) > 150 {
//                let stateChange: String
//                if isDownwards {
//                    stateChange = "Downwards"
//                } else {
//                    stateChange = "Upwards"
//                }
//                log.verbose("State: \(stateChange) (\(Int(value.location.y))y @ \(Int(speed))px/s) — LastOffset: \(lastOffset)")

                let gestureEndedBelowCollapsedHeight = value.location.y > maxHeight
                if isDownwards {
                    if gestureEndedBelowCollapsedHeight || lastOffset == RegularOffset {
//                        offset = CollapsedOffset
                        changeState(to: .collapsed)
                        updateProgress(height: height)
                    } else {
//                        offset = RegularOffset
                        changeState(to: .regular)
                        updateProgress(height: height)
                    }
                } else {
                    if !gestureEndedBelowCollapsedHeight &&
                        (value.location.y < UIScreen.main.bounds.height*2.0/3.0 || lastOffset == RegularOffset)
                    {
                        changeState(to: .expanded, maxHeight: maxHeight)
//                        offset = -maxHeight
                        updateProgress(height: height)
                    } else {
//                        offset = RegularOffset
                        changeState(to: .regular)
                        updateProgress(height: height)
                    }
                }
            } else {
                
                let drawerTopIsBelowFourFifthOfMaxHeight = -offset < maxHeight*4.0/5.0
                let drawerTopIsAboveTwoThirdsOfMaxHeight = -offset > maxHeight/3.0
                
                let drawerTopIsAboveHalfwayBetweenCollapsedAndRegular = -offset > -RegularOffset/2.0
                
                if lastOffset == -maxHeight && drawerTopIsBelowFourFifthOfMaxHeight {
                    offset = RegularOffset
                    updateProgress(height: height)
                }
                else if drawerTopIsAboveTwoThirdsOfMaxHeight {
                    changeState(to: .expanded, maxHeight: maxHeight)
//                    offset = -maxHeight
                    updateProgress(height: height)
                }
                else if drawerTopIsAboveHalfwayBetweenCollapsedAndRegular {
//                    offset = RegularOffset
                    changeState(to: .regular)
                    updateProgress(height: height)
                }
                else {
//                    offset = CollapsedOffset
                    changeState(to: .collapsed)
                    updateProgress(height: height)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                vm.isDragging = false
            }
            lastOffset = offset
        }
    }
}
