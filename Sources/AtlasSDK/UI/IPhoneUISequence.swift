//
//  IPhoneUISequence.swift
//  AtlasSDK
//
//  Created by Will Taylor on 3/3/26.
//

import Foundation
import SwiftUI

public struct IPhoneUISequence: View {
    
    public struct Config: Identifiable {
        public var id: UUID = UUID()
        
        public let title: String
        public let subtitle: String
        public let illustration: Illustration
        public let zoomScale: CGFloat
        public let zoomAnchor: UnitPoint
        
        public let primaryAction: Action
        public let secondaryAction: Action?
        
        public enum Illustration {
            case image(UIImage)
            case swiftUIView(AnyView)
            case swiftUIViewInPhoneBezel(AnyView)
        }
        
        public enum Action {
            case `continue`(String)
            case custom(String, () -> Void)
            
            var text: String {
                switch self {
                case .continue(let string):
                    return string
                case .custom(let string, _):
                    return string
                }
            }
        }
        
        public init(
            id: UUID = UUID(),
            title: String,
            subtitle: String,
            illustration: Illustration,
            primaryAction: Action = .continue("Continue"),
            secondaryAction: Action? = nil,
            zoomScale: CGFloat = 1,
            zoomAnchor: UnitPoint = .center
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.primaryAction = primaryAction
            self.secondaryAction = secondaryAction
            self.illustration = illustration
            self.zoomScale = zoomScale
            self.zoomAnchor = zoomAnchor
        }
    }
    
    public typealias Item = Config
    
    let tint: Color = Color.accentColor
    let items: [Config]
    
    public init(items: [Config]) {
        self.items = items
        self.currentIndex = currentIndex
        self.screenshotSize = screenshotSize
    }
    
    @State private var currentIndex = 0
    @State private var screenshotSize: CGSize = .zero
    
    var deviceCornerRadius: CGFloat {
        guard let uiImage = currentBezelReferenceImage else {
            return 44
        }
        
        let ratio = screenshotSize.height / uiImage.size.height
        let actualCornerRadius: CGFloat = 190
        return actualCornerRadius * ratio
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            VisualContentView()
            
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    TextContentView()
                    
                    IndicatorView()
                    
                    VStack(spacing: 2) {
                        PrimaryActionButton(action: items[currentIndex].primaryAction)
                        
                        if let secondaryAction = items[currentIndex].secondaryAction {
                            SecondaryActionButton(action: secondaryAction)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .frame(maxHeight: 210)
            }
            
            if currentIndex != 0 {
                BackButton()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
    }
    
    @ViewBuilder
    private func VisualContentView() -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let isActive = index == currentSegmentIndex
                        
                        if let swiftUIView = segment.swiftUIView {
                            swiftUIView
                                .frame(width: size.width, height: size.height)
                                .opacity(isActive ? 1 : 0)
                        } else {
                            ScreenshotSequenceView(itemIndices: segment.itemIndices)
                                .compositingGroup()
                                .scaleEffect(
                                    zoomScale(for: segment),
                                    anchor: zoomAnchor(for: segment)
                                )
                                .padding(.top, 36)
                                .padding(.bottom, 220)
                                .padding(.horizontal, 16)
                                .frame(width: size.width, height: size.height)
                                .opacity(isActive ? 1 : 0)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollDisabled(true)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(
                id: .init(
                    get: { currentSegmentIndex },
                    set: { _ in }
                )
            )
        }
    }
    
    @ViewBuilder
    private func ScreenshotSequenceView(itemIndices: [Int]) -> some View {
        let shape: AnyShape = {
            if #available(iOS 26.0, *) {
                AnyShape(ConcentricRectangle(corners: .concentric, isUniform: true))
            } else {
                AnyShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
            }
        }()
        
        GeometryReader { proxy in
            // Back background for switching between screenshots
            Rectangle()
                .fill(.black)
                .clipShape(shape)
            
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(itemIndices.enumerated()), id: \.offset) { _, itemIndex in
                        Group {
                            switch items[itemIndex].illustration {
                            case .image(let uiImage):
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .onGeometryChange(for: CGSize.self) {
                                        $0.size
                                    } action: { newValue in
                                        screenshotSize = newValue
                                    }
                                    .clipShape(shape)
                            case .swiftUIViewInPhoneBezel(let anyView):
                                anyView
                                    .clipShape(shape)
                            case .swiftUIView:
                                Color.clear
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollDisabled(true)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(
                id: .init(
                    get: { localBezelItemIndex(for: itemIndices) },
                    set: { _ in }
                )
            )
        }
        .clipShape(shape)
        .overlay {
            if screenshotSize != .zero {
                // Device Frame UI
                ZStack {
                    shape
                        .stroke(.white, lineWidth: 6)
                    
                    shape
                        .stroke(.black, lineWidth: 4)
                    
                    shape
                        .stroke(.black, lineWidth: 6)
                        .padding(4)
                }
                .padding(-6)
            }
        }
        .frame(
            maxWidth: screenshotSize.width == 0 ? nil : screenshotSize.width,
            maxHeight: screenshotSize.height == 0 ? nil : screenshotSize.height
        )
        .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func TextContentView() -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let isActive = currentIndex == index
                        
                        VStack(spacing: 8) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Text(item.subtitle)
                                .multilineTextAlignment(.center)
                                .font(.callout)
                                .lineLimit(2)
                                .opacity(0.8)
                        }
                        .frame(width: size.width)
                        .compositingGroup()
                        .blur(radius: isActive ? 0 : 30)
                        .opacity(isActive ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            .scrollTargetBehavior(.paging)
            .scrollClipDisabled()
            .scrollPosition(
                id: .init(
                    get: { return currentIndex },
                    set: { _ in }
                )
            )
        }
    }
    
    @ViewBuilder
    private func PrimaryActionButton(action: Config.Action) -> some View {
        if #available(iOS 26.0, *) {
            Button {
                navigate(to: min(currentIndex + 1, items.count - 1))
            } label: {
                Text(action.text)
                    .fontWeight(.medium)
                    .padding(.vertical, 6)
            }
            .tint(tint)
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .padding(.horizontal, 32)
        } else {
            Button {
                navigate(to: min(currentIndex + 1, items.count - 1))
            } label: {
                Text(action.text)
                    .fontWeight(.medium)
                    .padding(.vertical, 6)
            }
            .tint(tint)
            .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func SecondaryActionButton(action: Config.Action) -> some View {
        Button {
            switch action {
            case .continue(_):
                navigate(to: min(currentIndex + 1, items.count - 1))
            case .custom(_, let onClick):
                onClick()
            }
        } label: {
            Text(action.text)
                .fontWeight(.medium)
                .padding(.vertical, 6)
        }
        .tint(Color.secondary)
        .font(.callout)
    }
    
    @ViewBuilder
    private func BackButton() -> some View {
        if #available(iOS 26.0, *) {
            Button {
                navigate(to: max(currentIndex - 1, 0))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 20, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 16)
            .padding(.top, 8)
        } else {
            Button {
                navigate(to: max(currentIndex - 1, 0))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 20, height: 30)
            }
            .buttonBorderShape(.circle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func IndicatorView() -> some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                let isActive = currentIndex == index
                
                Capsule()
                    .fill(.primary.opacity(isActive ? 0.8 : 0.4))
                    .frame(
                        width: isActive ? 26 : 6,
                        height: 6
                    )
            }
        }
    }
    
    private var currentBezelReferenceImage: UIImage? {
        if case .image(let uiImage) = items[currentIndex].illustration {
            return uiImage
        }
        
        let segment = segments[currentSegmentIndex]
        for itemIndex in segment.itemIndices {
            if case .image(let uiImage) = items[itemIndex].illustration {
                return uiImage
            }
        }
        
        return nil
    }
    
    private var segments: [VisualSegment] {
        var result: [VisualSegment] = []
        var currentBezelRun: [Int] = []
        
        func flushBezelRun() {
            guard !currentBezelRun.isEmpty else { return }
            result.append(
                VisualSegment(
                    id: result.count,
                    itemIndices: currentBezelRun,
                    swiftUIView: nil
                )
            )
            currentBezelRun.removeAll()
        }
        
        for (index, item) in items.enumerated() {
            switch item.illustration {
            case .image, .swiftUIViewInPhoneBezel:
                currentBezelRun.append(index)
            case .swiftUIView(let anyView):
                flushBezelRun()
                result.append(
                    VisualSegment(
                        id: result.count,
                        itemIndices: [index],
                        swiftUIView: anyView
                    )
                )
            }
        }
        
        flushBezelRun()
        return result
    }
    
    var currentSegmentIndex: Int {
        for (segmentIndex, segment) in segments.enumerated() {
            if segment.itemIndices.contains(currentIndex) {
                return segmentIndex
            }
        }
        return 0
    }
    
    func localBezelItemIndex(for segmentItemIndices: [Int]) -> Int {
        segmentItemIndices.firstIndex(of: currentIndex) ?? 0
    }
    
    private func zoomScale(for segment: VisualSegment) -> CGFloat {
        guard segment.itemIndices.contains(currentIndex) else {
            return 1
        }
        return items[currentIndex].zoomScale
    }
    
    private func zoomAnchor(for segment: VisualSegment) -> UnitPoint {
        guard segment.itemIndices.contains(currentIndex) else {
            return .center
        }
        return items[currentIndex].zoomAnchor
    }
    
    private func navigate(to newIndex: Int) {
        guard items.indices.contains(newIndex), newIndex != currentIndex else {
            return
        }
        
        withAnimation(animation) {
            currentIndex = newIndex
        }
    }
    
    private var animation: Animation {
        .interpolatingSpring(duration: 0.65, bounce: 0.25, initialVelocity: 0)
    }
    
    private struct VisualSegment: Identifiable {
        let id: Int
        let itemIndices: [Int]
        let swiftUIView: AnyView?
    }
}

#Preview {
    IPhoneUISequence(items: [
        IPhoneUISequence.Config(
            title: "Welcome to iOS 26",
            subtitle: "Introducing a new design with\nLiquid Glass.",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue)),
            secondaryAction: .custom("Custom Action", {})
        ),
        IPhoneUISequence.Config(
            title: "Big Feature #2",
            subtitle: "We know you'll just love\nthis feature.",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue))
        ),
        IPhoneUISequence.Config(
            title: "Custom SwiftUI Views",
            subtitle: "Onboarding Manager\nalso supports SwiftUI views.",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue))
        ),
        IPhoneUISequence.Config(
            title: "Big Feature #3",
            subtitle: "Introducing a new design with\nLiquid Glass.",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue))
        ),
        IPhoneUISequence.Config(
            title: "Big Feature #4",
            subtitle: "Introducing a new design with\nLiquid Glass.",
            illustration: .swiftUIViewInPhoneBezel(
                AnyView(
                    IPhoneUI {
                        ZStack {
                            Color.cyan
                            AnimatedPermissionSkeletonPrompt(
                                config: AnimatedPermissionSkeletonPrompt.Config(
                                    alertButtons: .two,
                                    activeTap: .one,
                                )
                            )
                            .padding(.horizontal)
                        }
                    }
                )
            )
        ),
        IPhoneUISequence.Config(
            title: "Zoom In",
            subtitle: "Now with zooming\nfunctionality.",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue)),
            zoomScale: 1.3,
            zoomAnchor: .bottom
        ),
        IPhoneUISequence.Config(
            title: "Onboarding",
            subtitle: "Can't wait to test this out!",
            illustration: .swiftUIViewInPhoneBezel(AnyView(Color.blue))
        ),
    ])
}
