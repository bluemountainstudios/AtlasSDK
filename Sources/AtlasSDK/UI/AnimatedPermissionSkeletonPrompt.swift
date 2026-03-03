//
//  AnimatedPermissionSkeletonPrompt.swift
//  AtlasSDK
//
//  Created by Will Taylor on 3/3/26.
//

import Foundation
import SwiftUI

public struct AnimatedPermissionSkeletonPrompt: View {
    
    public let config: Config
    
    @State private var showPermsissionAnimation = false
    
    public var body: some View {
        let fill = Color.primary.opacity(0.15)
        
        ZStack {
            Text("")
                .opacity(0)
                .accessibilityHidden(true)
            
            if showPermsissionAnimation {
                KeyframeAnimator(initialValue: Frame(), repeating: true) { frame in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fill)
                            .frame(width: 120, height: 20)
                            .padding(.bottom, 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fill)
                            .frame(height: 15)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fill)
                            .frame(height: 15)
                            .padding(.trailing, 150)
                            .padding(.bottom, 30)
                        
                        // Buttons
                        let layout = config.alertButtons == .three
                        ? AnyLayout(VStackLayout(spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 12))
                        
                        layout {
                            ForEach(1...config.alertButtons.rawValue, id: \.self) { index in
                                Capsule()
                                    .fill(fill)
                                    .frame(height: 26)
                                    .overlay {
                                        if config.activeTap.rawValue == index {
                                            Circle()
                                                .fill(.gray.opacity(0.8))
                                                .padding(5)
                                                .opacity(frame.tapOpacity)
                                        }
                                    }
                                    .scaleEffect(config.activeTap.rawValue == index ? frame.tapScale : 1)
                            }
                        }
                    }
                    .padding(20)
                    .optionalLiquidGlass()
                    .opacity(frame.opacity)
                    .scaleEffect(frame.scale)
                    
                } keyframes: { _ in
                    SpringKeyframe(
                        Frame(opacity: 1, scale: 1),
                        duration: 0.7,
                        spring: .smooth(duration: 0.5, extraBounce: 0)
                    )
                    
                    SpringKeyframe(
                        Frame(opacity: 1, scale: 1, tapOpacity: 1),
                        duration: 0.1,
                        spring: .smooth(duration: 0.4, extraBounce: 0)
                    )
                    
                    SpringKeyframe(
                        Frame(opacity: 1, scale: 1, tapOpacity: 1, tapScale: 0.9),
                        duration: 0.2,
                        spring: .smooth(duration: 0.4, extraBounce: 0)
                    )
                    
                    SpringKeyframe(
                        Frame(opacity: 1, scale: 1),
                        duration: 0.4,
                        spring: .smooth(duration: 0.4, extraBounce: 0)
                    )
                    
                    SpringKeyframe(
                        Frame(),
                        duration: 2,
                        spring: .smooth(duration: 0.4, extraBounce: 0)
                    )
                }
            }
        }
        .task {
            guard !showPermsissionAnimation else { return }
            try? await Task.sleep(for: .seconds(config.initialDelay))
            showPermsissionAnimation = true
        }
    }
    
    public enum Buttons: Int, CaseIterable {
        case two = 2
        case three = 3
    }
    
    public enum ActiveTap: Int, CaseIterable {
        case one = 1
        case two = 2
        case three = 3
    }
    
    @Animatable
    fileprivate struct Frame {
        var opacity: CGFloat = 0
        var scale: CGFloat = 1
        var tapOpacity: CGFloat = 0
        var tapScale: CGFloat = 1.1
    }
    
    public struct Config {
        public let initialDelay: CGFloat
        public let alertButtons: Buttons
        public let activeTap: ActiveTap
        
        public init(initialDelay: CGFloat = 2, alertButtons: Buttons, activeTap: ActiveTap) {
            self.initialDelay = initialDelay
            self.alertButtons = alertButtons
            self.activeTap = activeTap
        }
    }
}

fileprivate extension View {
    
    @ViewBuilder
    func optionalLiquidGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.clear, in: .rect(cornerRadius: 30))
        } else {
            self
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.background)
                        
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(.gray.opacity(0.4), lineWidth: 1)
                    }
                }
        }
    }
}

#Preview {
    ZStack {
        Color.cyan
        
        AnimatedPermissionSkeletonPrompt(
            config: AnimatedPermissionSkeletonPrompt.Config(
                alertButtons: .two,
                activeTap: .one,
            )
        )
    }
}

