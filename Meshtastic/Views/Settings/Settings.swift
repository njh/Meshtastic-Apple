//
//  Settings.swift
//  MeshtasticApple
//
//  Copyright (c) Garth Vander Houwen 6/9/22.
//

import SwiftUI

struct Settings: View {
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "user.longName", ascending: true)], animation: .default)
	private var nodes: FetchedResults<NodeInfoEntity>
	@State private var selectedNode: Int = 0
	@State private var preferredNodeNum: Int = 0
	@State private var selection: SettingsSidebar = .about
	enum SettingsSidebar {
		case appSettings
		case routes
		case routeRecorder
		case shareChannels
		case userConfig
		case loraConfig
		case channelConfig
		case bluetoothConfig
		case deviceConfig
		case displayConfig
		case networkConfig
		case positionConfig
		case powerConfig
		case ambientLightingConfig
		case cannedMessagesConfig
		case detectionSensorConfig
		case externalNotificationConfig
		case mqttConfig
		case rangeTestConfig
		case ringtoneConfig
		case serialConfig
		case telemetryConfig
		case meshLog
		case adminMessageLog
		case about
	}
	var body: some View {
		NavigationSplitView {
			List {
				NavigationLink {
					AboutMeshtastic()
				} label: {
					Image(systemName: "questionmark.app")
						.symbolRenderingMode(.hierarchical)
					Text("about.meshtastic")
				}
				.tag(SettingsSidebar.about)
				NavigationLink {
					AppSettings()
				} label: {
					Image(systemName: "gearshape")
						.symbolRenderingMode(.hierarchical)
					Text("appsettings")
				}
				.tag(SettingsSidebar.appSettings)
				if #available(iOS 17.0, macOS 14.0, *) {
					NavigationLink {
						Routes()
					} label: {
						Image(systemName: "road.lanes.curved.right")
							.symbolRenderingMode(.hierarchical)
						Text("routes")
					}
					.tag(SettingsSidebar.routes)
					NavigationLink {
						RouteRecorder()
					} label: {
						Image(systemName: "record.circle")
							.symbolRenderingMode(.hierarchical)
						Text("route.recorder")
					}
					.tag(SettingsSidebar.routeRecorder)
				}
				
				let node = nodes.first(where: { $0.num == preferredNodeNum })
				let hasAdmin = node?.myInfo?.adminIndex ?? 0 > 0 ? true : false
				
				
				if !(node?.deviceConfig?.isManaged ?? false) {
					if bleManager.connectedPeripheral != nil {
						Section("Configure") {
							if hasAdmin {
								Picker("Configuring Node", selection: $selectedNode) {
									if selectedNode == 0 {
										Text("Connect to a Node").tag(0)
									}
									ForEach(nodes) { node in
										if node.num == bleManager.connectedPeripheral?.num ?? 0 {
											Text("BLE Config: \(node.user?.longName ?? "unknown".localized)")
												.tag(Int(node.num))
										} else if node.metadata != nil {
											Text("Remote Config: \(node.user?.longName ?? "unknown".localized)")
												.tag(Int(node.num))
										} else if hasAdmin {
											Text("Request Admin: \(node.user?.longName ?? "unknown".localized)")
												.tag(Int(node.num))
										}
									}
								}
								.pickerStyle(.automatic)
								.labelsHidden()
								.onChange(of: selectedNode) { newValue in
									if selectedNode > 0 {
										let node = nodes.first(where: { $0.num == newValue })
										let connectedNode = nodes.first(where: { $0.num == preferredNodeNum })
										preferredNodeNum = Int(connectedNode?.num ?? 0)// Int(bleManager.connectedPeripheral != nil ? bleManager.connectedPeripheral?.num ?? 0 : 0)
										if connectedNode != nil && connectedNode?.user != nil && connectedNode?.myInfo != nil && node?.user != nil && node?.metadata == nil {
											let adminMessageId =  bleManager.requestDeviceMetadata(fromUser: connectedNode!.user!, toUser: node!.user!, adminIndex: connectedNode!.myInfo!.adminIndex, context: context)
											if adminMessageId > 0 {
												print("Sent node metadata request from node details")
											}
										}
									}
								}
							} else {
								if bleManager.connectedPeripheral != nil {
									Text("Connected Node \(node?.user?.longName ?? "unknown".localized)")
								}
							}
						}
					}
					Section("radio.configuration") {
						if node != nil && node?.loRaConfig != nil {
							let rc = RegionCodes(rawValue: Int(node?.loRaConfig?.regionCode ?? 0))
							if rc?.dutyCycle ?? 0 > 0 && rc?.dutyCycle ?? 0 < 100  {
								
								Label {
									Text("Hourly Duty Cycle")
								} icon: {
									Image(systemName: "clock.arrow.circlepath")
										.symbolRenderingMode(.hierarchical)
										.foregroundColor(.red)
								}
								Text("Your region has a \(rc?.dutyCycle ?? 0)% hourly duty cycle, your radio will stop sending packets when it reaches the hourly limit.")
									.foregroundColor(.orange)
									.font(.caption)
								Text("Limit all periodic broadcasts intervals especially telemetry and position. If you need to increase hops, do it on nodes at the edges, not the ones in the middle. MQTT is not advised when you are duty cycle restricted because the gateway node is then doing all the work.")
									.font(.caption2)
									.foregroundColor(.gray)
							}
						}
						NavigationLink {
							LoRaConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "dot.radiowaves.left.and.right")
								.symbolRenderingMode(.hierarchical)
							Text("lora")
						}
						.tag(SettingsSidebar.loraConfig)
						NavigationLink {
							Channels(node: nodes.first(where: { $0.num == preferredNodeNum }))
						} label: {
							Image(systemName: "fibrechannel")
								.symbolRenderingMode(.hierarchical)
							Text("channels")
						}
						.tag(SettingsSidebar.channelConfig)
						.disabled(selectedNode > 0 && selectedNode != preferredNodeNum)
						NavigationLink {
							ShareChannels(node: nodes.first(where: { $0.num == preferredNodeNum }))
						} label: {
							Image(systemName: "qrcode")
								.symbolRenderingMode(.hierarchical)
							Text("share.channels")
						}
						.tag(SettingsSidebar.shareChannels)
						.disabled(selectedNode > 0 && selectedNode != preferredNodeNum)
					}
					Section("device.configuration") {
						NavigationLink {
							UserConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "person.crop.rectangle.fill")
								.symbolRenderingMode(.hierarchical)
							Text("user")
						}
						.tag(SettingsSidebar.userConfig)
						NavigationLink {
							BluetoothConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "antenna.radiowaves.left.and.right")
								.symbolRenderingMode(.hierarchical)
							Text("bluetooth")
						}
						.tag(SettingsSidebar.bluetoothConfig)
						NavigationLink {
							DeviceConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "flipphone")
								.symbolRenderingMode(.hierarchical)
							Text("device")
						}
						.tag(SettingsSidebar.deviceConfig)
						NavigationLink {
							DisplayConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "display")
								.symbolRenderingMode(.hierarchical)
							Text("display")
						}
						.tag(SettingsSidebar.displayConfig)
						NavigationLink {
							NetworkConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "network")
								.symbolRenderingMode(.hierarchical)
							Text("network")
						}
						.tag(SettingsSidebar.networkConfig)
						NavigationLink {
							PositionConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "location")
								.symbolRenderingMode(.hierarchical)
							Text("position")
						}
						.tag(SettingsSidebar.positionConfig)

						NavigationLink {
							PowerConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "bolt.fill")
								.symbolRenderingMode(.hierarchical)
							Text("power")
						}
						.tag(SettingsSidebar.powerConfig)
					}
					Section("module.configuration") {
						if #available(iOS 17.0, macOS 14.0, *) {
							NavigationLink {
								AmbientLightingConfig(node: nodes.first(where: { $0.num == selectedNode }))
							} label: {
								Image(systemName: "light.max")
									.symbolRenderingMode(.hierarchical)
								Text("ambient.lighting")
							}
							.tag(SettingsSidebar.ambientLightingConfig)
						}
						NavigationLink {
							CannedMessagesConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "list.bullet.rectangle.fill")
								.symbolRenderingMode(.hierarchical)
							Text("canned.messages")
						}
						.tag(SettingsSidebar.cannedMessagesConfig)
						NavigationLink {
							DetectionSensorConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "sensor")
								.symbolRenderingMode(.hierarchical)
							Text("detection.sensor")
						}
						.tag(SettingsSidebar.detectionSensorConfig)
						NavigationLink {
							ExternalNotificationConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "megaphone")
								.symbolRenderingMode(.hierarchical)
							Text("external.notification")
						}
						.tag(SettingsSidebar.externalNotificationConfig)
						NavigationLink {
							MQTTConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "dot.radiowaves.right")
								.symbolRenderingMode(.hierarchical)
							Text("mqtt")
						}
						.tag(SettingsSidebar.mqttConfig)
						NavigationLink {
							RangeTestConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "point.3.connected.trianglepath.dotted")
								.symbolRenderingMode(.hierarchical)
							Text("range.test")
						}
						NavigationLink {
							RtttlConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "music.note.list")
								.symbolRenderingMode(.hierarchical)
							Text("ringtone")
						}
						.tag(SettingsSidebar.ringtoneConfig)
						NavigationLink {
							SerialConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "terminal")
								.symbolRenderingMode(.hierarchical)
							Text("serial")
						}
						.tag(SettingsSidebar.serialConfig)
						NavigationLink {
							StoreForwardConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "envelope.arrow.triangle.branch")
								.symbolRenderingMode(.hierarchical)
							Text("storeforward")
						}
						.tag(SettingsSidebar.serialConfig)
						NavigationLink {
							TelemetryConfig(node: nodes.first(where: { $0.num == selectedNode }))
						} label: {
							Image(systemName: "chart.xyaxis.line")
								.symbolRenderingMode(.hierarchical)
							Text("telemetry")
						}
						.tag(SettingsSidebar.telemetryConfig)
					}
					Section(header: Text("logging")) {
						NavigationLink {
							MeshLog()
						} label: {
							Image(systemName: "list.bullet.rectangle")
								.symbolRenderingMode(.hierarchical)
							Text("mesh.log")
						}
						.tag(SettingsSidebar.meshLog)
						NavigationLink {
							let connectedNode = nodes.first(where: { $0.num == preferredNodeNum })
							AdminMessageList(user: connectedNode?.user)
						} label: {
							Image(systemName: "building.columns")
								.symbolRenderingMode(.hierarchical)
							Text("admin.log")
						}
						.tag(SettingsSidebar.adminMessageLog)
					}
					Section(header: Text("Firmware")) {
						NavigationLink {
							Firmware(node: nodes.first(where: { $0.num == preferredNodeNum }))
						} label: {
							Image(systemName: "arrow.up.arrow.down.square")
								.symbolRenderingMode(.hierarchical)					
							Text("Firmware Updates")
						}
						.tag(SettingsSidebar.about)
						.disabled(selectedNode > 0 && selectedNode != preferredNodeNum)
					}
				}
			}
			.onChange(of: UserDefaults.preferredPeripheralNum ) { newConnectedNode in
				preferredNodeNum = newConnectedNode
				if nodes.count > 1 {
					if selectedNode == 0 {
						self.selectedNode = Int(bleManager.connectedPeripheral != nil ? newConnectedNode : 0)
					}
				} else {
					self.selectedNode = Int(bleManager.connectedPeripheral != nil ? newConnectedNode: 0)
				}
			}
			.onAppear {
				if self.preferredNodeNum <= 0 {
					self.preferredNodeNum = UserDefaults.preferredPeripheralNum
					if nodes.count > 1 {
						if selectedNode == 0 {
							self.selectedNode = Int(bleManager.connectedPeripheral != nil ? UserDefaults.preferredPeripheralNum : 0)
						}
					} else {
						self.selectedNode = Int(bleManager.connectedPeripheral != nil ? UserDefaults.preferredPeripheralNum : 0)
					}
				}
			}
			.listStyle(GroupedListStyle())
			.navigationTitle("settings")
			.navigationBarItems(leading:
				MeshtasticLogo()
			)
		}
		detail: {
			if #available (iOS 17, *) {
				ContentUnavailableView("select.menu.item", systemImage: "gear")
			} else {
				Text("select.menu.item")
			}
		}
	}
}
