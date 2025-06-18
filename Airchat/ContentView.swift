//
//  ContentView.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Airchat")
                .font(.title)
            Text("Menu bar AI chat app")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
