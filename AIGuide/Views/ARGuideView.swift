// AR Guide View - Augmented Reality Navigation

import SwiftUI
import ARKit

struct ARGuideView: View {
    @StateObject private var arService = ARService()
    @StateObject private var locationService = LocationService()
    @State private var showAR = false
    @State private var selectedPOI: ARService.ARPOI?
    @State private var currentHeading: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                if showAR && arService.isARAvailable {
                    // AR View
                    arView
                    
                    // AR Overlay
                    AROverlayView(
                        pois: arService.detectedPOIs,
                        heading: currentHeading
                    )
                } else {
                    // Compass view
                    compassView
                }
            }
            .navigationTitle("AR 导览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAR.toggle() }) {
                        Label(showAR ? "指南针" : "AR", systemImage: showAR ? "compass" : "arkit")
                    }
                }
            }
            .onAppear {
                locationService.requestPermission()
                locationService.startUpdating()
            }
            .onDisappear {
                locationService.stopUpdating()
            }
            .onChange(of: locationService.currentLocation) { _, newLocation in
                if let location = newLocation {
                    arService.updatePOIs(
                        userLocation: location.coordinate,
                        pois: POI.seedList
                    )
                }
            }
            .onChange(of: locationService.heading) { _, newHeading in
                if let heading = newHeading {
                    currentHeading = heading.trueHeading
                }
            }
            .sheet(item: $selectedPOI) { poi in
                ARPOIDetailView(poi: poi)
            }
        }
    }
    
    // MARK: - AR View
    private var arView: some View {
        ZStack {
            ARViewContainer(arService: arService)
                .ignoresSafeArea()
            
            // AR markers overlay
            ForEach(arService.getPOIsInView(heading: currentHeading)) { poi in
                ARMarkerView(poi: poi, heading: currentHeading)
                    .onTapGesture {
                        selectedPOI = poi
                    }
            }
        }
    }
    
    // MARK: - Compass View
    private var compassView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Compass
            CompassView(heading: currentHeading, pois: arService.detectedPOIs)
                .frame(height: 250)
            
            // POI list
            VStack(alignment: .leading, spacing: 12) {
                Text("附近景点")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(arService.detectedPOIs.prefix(10)) { poi in
                            ARPOIListRow(poi: poi)
                                .onTapGesture {
                                    selectedPOI = poi
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.black, .blue.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
