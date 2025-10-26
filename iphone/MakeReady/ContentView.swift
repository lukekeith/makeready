//
//  ContentView.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 60))

            Text("Hello, MakeReady!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your iPhone app is ready to build")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
