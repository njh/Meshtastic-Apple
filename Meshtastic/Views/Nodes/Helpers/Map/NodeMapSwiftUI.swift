//
//  NodeMapSwiftUI.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 9/11/23.
//

import SwiftUI
import CoreLocation
#if canImport(MapKit)
import MapKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct NodeMapSwiftUI: View {
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	/// Parameters
	@ObservedObject var node: NodeInfoEntity
	@State var showUserLocation: Bool = false
	@State var positions: [PositionEntity] = []
	/// Map State User Defaults
	@AppStorage("meshMapShowNodeHistory") private var showNodeHistory = false
	@AppStorage("meshMapShowRouteLines") private var showRouteLines = false
	@AppStorage("enableMapConvexHull") private var showConvexHull = false
	@AppStorage("enableMapTraffic") private var showTraffic: Bool = false
	@AppStorage("enableMapPointsOfInterest") private var showPointsOfInterest: Bool = false
	@AppStorage("mapLayer") private var selectedMapLayer: MapLayer = .hybrid
	// Map Configuration
	@Namespace var mapScope
	@State var mapStyle: MapStyle = MapStyle.hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
	@State var position = MapCameraPosition.automatic
	@State var scene: MKLookAroundScene?
	@State var isLookingAround = false
	@State var isShowingAltitude = false
	@State var isEditingSettings = false
	@State var selectedPosition: PositionEntity?
	@State var showWaypoints = false
	@State var selectedWaypoint: WaypointEntity?
	@State var isMeshMap = false
	
	@State private var mapRegion = MKCoordinateRegion.init()
	
	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
				  predicate: NSPredicate(
					format: "expire == nil || expire >= %@", Date() as NSDate
				  ), animation: .none)
	private var waypoints: FetchedResults<WaypointEntity>
	
	var body: some View {
		var mostRecent = node.positions?.lastObject as? PositionEntity
		
		if node.hasPositions {
			ZStack {
				MapReader { reader in
					Map(position: $position, bounds: MapCameraBounds(minimumDistance: 1, maximumDistance: .infinity), scope: mapScope) {
						NodeMapContent(node: node)
					}
					.mapScope(mapScope)
					.mapStyle(mapStyle)
					.mapControls {
						MapScaleView(scope: mapScope)
							.mapControlVisibility(.visible)
						if showUserLocation {
							MapUserLocationButton(scope: mapScope)
								.mapControlVisibility(.visible)
						}
						MapPitchToggle(scope: mapScope)
							.mapControlVisibility(.visible)
						MapCompass(scope: mapScope)
							.mapControlVisibility(.visible)
					}
					.controlSize(.regular)
					.overlay(alignment: .bottom) {
						if scene != nil && isLookingAround {
							LookAroundPreview(initialScene: scene)
								.frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 250 : 400)
								.clipShape(RoundedRectangle(cornerRadius: 12))
								.padding(.horizontal, 20)
						}
					}
					.overlay(alignment: .bottom) {
						if !isLookingAround && isShowingAltitude {
							PositionAltitudeChart(node: node)
								.frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 250 : 400)
								.clipShape(RoundedRectangle(cornerRadius: 12))
								.padding(.horizontal, 20)
						}
					}
					.sheet(item: $selectedWaypoint) { selection in
						WaypointForm(waypoint: selection)
							.padding()
					}
					.sheet(isPresented: $isEditingSettings) {
						MapSettingsForm(nodeHistory: $showNodeHistory, routeLines: $showRouteLines, convexHull: $showConvexHull, traffic: $showTraffic, pointsOfInterest: $showPointsOfInterest, mapLayer: $selectedMapLayer, meshMap: $isMeshMap)
							.onChange(of: (selectedMapLayer)) { newMapLayer in
								switch selectedMapLayer {
								case .standard:
									UserDefaults.mapLayer = newMapLayer
									mapStyle = MapStyle.standard(elevation: .realistic, pointsOfInterest: showPointsOfInterest ? .all : .excludingAll, showsTraffic: showTraffic)
								case .hybrid:
									UserDefaults.mapLayer = newMapLayer
									mapStyle = MapStyle.hybrid(elevation: .realistic, pointsOfInterest: showPointsOfInterest ? .all : .excludingAll, showsTraffic: showTraffic)
								case .satellite:
									UserDefaults.mapLayer = newMapLayer
									mapStyle = MapStyle.imagery(elevation: .realistic)
								case .offline:
									return
								}
							}
					}
					.onChange(of: node) {
						isLookingAround = false
						isShowingAltitude = false
						mostRecent = node.positions?.lastObject as? PositionEntity
						if node.positions?.count ?? 0 > 1 {
							position = .automatic
						} else {
							position = .camera(MapCamera(centerCoordinate: mostRecent!.coordinate, distance: 8000, heading: 0, pitch: 60))
						}
						if let mostRecent {
							Task {
								scene = try? await fetchScene(for: mostRecent.coordinate)
							}
						}
					}
					.onAppear {
						UIApplication.shared.isIdleTimerDisabled = true
						switch selectedMapLayer {
						case .standard:
							mapStyle = MapStyle.standard(elevation: .realistic, pointsOfInterest: showPointsOfInterest ? .all : .excludingAll, showsTraffic: showTraffic)
						case .hybrid:
							mapStyle = MapStyle.hybrid(elevation: .realistic, pointsOfInterest: showPointsOfInterest ? .all : .excludingAll, showsTraffic: showTraffic)
						case .satellite:
							mapStyle = MapStyle.imagery(elevation: .realistic)
						case .offline:
							mapStyle = MapStyle.hybrid(elevation: .realistic, pointsOfInterest: showPointsOfInterest ? .all : .excludingAll, showsTraffic: showTraffic)
						}
						mostRecent = node.positions?.lastObject as? PositionEntity
						if node.positions?.count ?? 0 > 1 {
							position = .automatic
						} else {
							position = .camera(MapCamera(centerCoordinate: mostRecent!.coordinate, distance: 8000, heading: 0, pitch: 60))
						}
						if self.scene == nil {
							Task {
								scene = try? await fetchScene(for: mostRecent!.coordinate)
							}
						}
					}
					.safeAreaInset(edge: .bottom, alignment: UIDevice.current.userInterfaceIdiom == .phone ? .leading : .trailing) {
						HStack {
							Button(action: {
								withAnimation {
									isEditingSettings = !isEditingSettings
								}
							}) {
								Image(systemName: isEditingSettings ? "info.circle.fill" : "info.circle")
									.padding(.vertical, 5)
							}
							.tint(Color(UIColor.secondarySystemBackground))
							.foregroundColor(.accentColor)
							.buttonStyle(.borderedProminent)
							/// Show / Hide Waypoints Button
							if waypoints.count > 0 {
								
								Button(action: {
									withAnimation {
										showWaypoints = !showWaypoints
									}
								}) {
									Image(systemName: showWaypoints ? "signpost.right.and.left.fill" : "signpost.right.and.left")
										.padding(.vertical, 5)
								}
								.tint(Color(UIColor.secondarySystemBackground))
								.foregroundColor(.accentColor)
								.buttonStyle(.borderedProminent)
							}
							/// Look Around Button
							if self.scene != nil {
								Button(action: {
									if isShowingAltitude {
										isShowingAltitude = false
									}
									isLookingAround = !isLookingAround
								}) {
									Image(systemName: isLookingAround ? "binoculars.fill" : "binoculars")
										.padding(.vertical, 5)
								}
								.tint(Color(UIColor.secondarySystemBackground))
								.foregroundColor(.accentColor)
								.buttonStyle(.borderedProminent)
							}
							/// Altitude Button
							if node.positions?.count ?? 0 > 1 {
								Button(action: {
									if isLookingAround {
										isLookingAround = false
									}
									isShowingAltitude = !isShowingAltitude
								}) {
									Image(systemName: isShowingAltitude ? "mountain.2.fill" : "mountain.2")
										.padding(.vertical, 5)
								}
								.tint(Color(UIColor.secondarySystemBackground))
								.foregroundColor(.accentColor)
								.buttonStyle(.borderedProminent)
							}
						}
						.controlSize(.regular)
						.padding(5)
					}
					.onDisappear {
						UIApplication.shared.isIdleTimerDisabled = false
					}
				}}
			.navigationBarTitle(String((node.user?.shortName ?? "unknown".localized) + (" \(node.positions?.count ?? 0) points")), displayMode: .inline)
			.navigationBarItems(trailing:
									ZStack {
				ConnectedDevice(
					bluetoothOn: bleManager.isSwitchedOn,
					deviceConnected: bleManager.connectedPeripheral != nil,
					name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName : "?")
			})
		} else {
			ContentUnavailableView("No Positions", systemImage: "mappin.slash")
		}
	}
	/// Get the look around scene
	private func fetchScene(for coordinate: CLLocationCoordinate2D) async throws -> MKLookAroundScene? {
		let lookAroundScene = MKLookAroundSceneRequest(coordinate: coordinate)
		return try await lookAroundScene.scene
	}
}
