//
// ContentView.swift
// Swift Charts Examples
//
// Copyright © 2022 Swift Charts Examples.
// Open Source - MIT License
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var imageCache = ImagesCache()
    @State private var selectedChartType: ChartType?
    @State var filterCategory: ChartCategory = .all
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedChartType) {
                ForEach(displayedCategories) { category in
                    Section {
                        ForEach(ChartType.allCases.filter { $0.category == category }) { chart in
                            NavigationLink(value: chart) {
                                preview(chart: chart)
                            }
                        }
                    } header: {
                        Text("\(category.rawValue)")
                    }
                }
            }
#if os(macOS)
            .listStyle(.bordered)
#else
            .listStyle(.insetGrouped)
#endif
            .navigationTitle("Charts")
            .toolbar {
                toolbarItems
            }
        } detail: {
            NavigationStack {
                if let selectedChartType {
                    selectedChartType.detailView
                } else {
                    Text("Select a chart")
                }
            }
        }
    }
    
    private var displayedCategories: [ChartCategory] {
        var categories = ChartCategory.allCases.filter { $0 != .all }
        if filterCategory != .all {
            categories = ChartCategory.allCases.filter { $0 == filterCategory }
        }
        return categories
    }
    
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
#if os(macOS)
            picker
#else
            Menu {
                picker
            } label: {
                Text("Filter")
            }
            // Temporary fix for the menu selection picker not updating to show the selected item
            // Broken since Xcode 14 beta 4 (Reported FB11104547)
            .id(UUID())
#endif
        }
    }
    
    private var picker: some View {
        Picker(selection: $filterCategory, label: Text("Filter")) {
            ForEach(ChartCategory.allCases.filter { $0 != .all }) { category in
                Label("\(category.rawValue.capitalized)", systemImage: category.sfSymbolName)
                    .tag(category)
            }
            Divider()
            Text("Show all")
                .tag(ChartCategory.all)
        }
    }
    
    private func preview(chart: ChartType) -> some View {
        VStack(alignment: .leading) {
            Text(chart.title)
            
            // causes UI to hang for several seconds when scrolling
            // from 100% CPU usage when cells are reloaded
            //            chart.view
            
            // workaround to address hanging UI
            // Reported FB10335209
            if let image = imageCache.images[chart] {
                AccessiblePreviewImage(id: chart.id, image: image)
            }
        }
    }
}

@MainActor private final class ImagesCache: ObservableObject {
    @Published var images: [ChartType: XImage] = [:]
    
    init() {
        ChartType.allCases.forEach { chart in
            let view = chart.view
                .padding(10)
                .frame(width: 300)
                .background {
                    if chart.category == .apple {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(.white)
                    }
                }
            let renderer = ImageRenderer(content: view)
#if os(macOS)
            renderer.scale = NSApplication.shared.mainWindow?.backingScaleFactor ?? 1
            if let image = renderer.nsImage {
                images[chart] = image
            }
#else
            renderer.scale = UIScreen.main.scale
            if let image = renderer.uiImage {
                images[chart] = image
            }
#endif
        }
    }
}

struct AccessiblePreviewImage: View, AXChartDescriptorRepresentable {
    @State var id: String
    @State var image: XImage
    
    var body: some View {
        Image(xImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 320)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        // Remove the image trait so VoiceOver doesn't attempt to describe image contents
            .accessibilityRemoveTraits(.isImage)
            .accessibilityChartDescriptor(self)
    }
    
    func makeChartDescriptor() -> AXChartDescriptor {
        guard let chartType = ChartType(rawValue: id) else {
            fatalError("Unknown Chart Type")
        }
        
        if let chartDescriptor = chartType.chartDescriptor {
            return chartDescriptor
        }
        
        let axis = AXNumericDataAxisDescriptor(title: "", range: 0...0, gridlinePositions: []) { _ in "" }
        return AXChartDescriptor(title: "", summary: nil, xAxis: axis, yAxis: axis, series: [])
        
        /*
         // TODO: Something like this might be better, but the if always evaluates to false
         if
         let chartType = ChartType(rawValue: id),
         let view = chartType.view as? any View & AXChartDescriptorRepresentable {
         return view.makeChartDescriptor()
         } else {
         let axis = AXNumericDataAxisDescriptor(title: "", range: 0.0...0.0, gridlinePositions: [], valueDescriptionProvider: { _ in
         return ""
         })
         return AXChartDescriptor(title: "", summary: nil, xAxis: axis, yAxis: axis, series: [])
         }
         */
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
