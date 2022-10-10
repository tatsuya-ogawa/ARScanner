//
//  ARViewContentView.swift
//  ARScanner
//
//  Created by Tatsuya Ogawa on 2022/10/03.
//
import SwiftUI
struct ARViewContentView: View {
    var body: some View {
        ARViewContainer()
            .ignoresSafeArea()
    }
}
struct ARViewContentView_Previews: PreviewProvider {
    static var previews: some View {
        ARSceneViewContentView()
    }
}
