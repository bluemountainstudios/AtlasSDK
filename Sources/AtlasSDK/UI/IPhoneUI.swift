//
//  IPhoneUI.swift
//  AtlasSDK
//
//  Created by Will Taylor on 3/3/26.
//

import Foundation
import SwiftUI

public struct IPhoneUI<Content: View>: View {
    @ViewBuilder public var content: Content
    
    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .top) {
                // Status bar
                HStack(spacing: 4) {
                    Text("9:41")
                    
                    Spacer()
                    
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }
                .font(.system(size: 12))
                .fontWeight(.medium)
                .padding(.horizontal, 32)
                .offset(y: 20)
            }
            .overlay(alignment: .top) {
                // Dynamic island
                Capsule()
                    .fill(.black)
                    .frame(width: 72, height: 20)
                    .offset(y: 20)
            }
    }
}
