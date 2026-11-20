//
//  CarControl.swift
//  carkey
//
//  Redesigned dashboard UI (iOS 17+)
//

import SwiftUI
import MapKit

// MARK: - Root

struct CarControlsView: View {
	@ObservedObject var dataManager = DataManager.shared
	@ObservedObject var bt = BluetoothManager.shared

	var body: some View {
		ZStack {
			// 深色渐变背景
			LinearGradient(
				gradient: Gradient(colors: [
					Color(red: 0.07, green: 0.09, blue: 0.14),
					Color(red: 0.10, green: 0.12, blue: 0.20),
					Color(red: 0.05, green: 0.06, blue: 0.10)
				]),
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			).ignoresSafeArea()

			ScrollView {
				VStack(spacing: 16) {
					DashboardHeader(bt: bt)
					CarImageSection(dataManager: dataManager)
					BatteryHeroCard(dataManager: dataManager)
					StatusGrid(dataManager: dataManager)
					VehicleStateChips(dataManager: dataManager)
					TirePressureCard(dataManager: dataManager)
					ControlSection(bt: bt)
					CarLocationView()
					FooterInfo(dataManager: dataManager)
					Spacer(minLength: 20)
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
			}
			.refreshable {
				DataManager.shared.fetchAndLoadCarData()
				DataManager.shared.fetchAndLoadKeyData()
				DataManager.shared.fetchAndLoadTireData()
			}
		}
		.overlay(alignment: .bottom) {
			ControlToast()
			.padding(.bottom, 10)
		}
		.preferredColorScheme(.dark)
	}
}

// MARK: - Header

struct DashboardHeader: View {
	@ObservedObject var bt: BluetoothManager
	@State private var scanningTask: Task<Void, Error>?

	private func startScanningLoop() {
		guard scanningTask == nil else { return }
		scanningTask = Task.detached {
			while !Task.isCancelled {
				BluetoothManager.shared.startScan()
				try await Task.sleep(for: .seconds(9))
			}
		}
	}

	private func stopScanningLoop() {
		scanningTask?.cancel()
		scanningTask = nil
	}

	private var bleColor: Color {
		switch bt.state {
		case .connected: return .green
		case .authorizing: return .orange
		case .scanning: return .yellow
		default: return .red
		}
	}

	private var bleText: String {
		switch bt.state {
		case .connected: return "蓝牙已连接"
		case .authorizing: return "蓝牙认证中"
		case .scanning: return "蓝牙扫描中"
		case .disconnected: return "蓝牙未连接"
		case .unknown: return "蓝牙异常"
		}
	}

	var body: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 6) {
				Text(DataManager.shared.appData.carData?.carInfo.carName ?? "我的车辆")
					.font(.system(size: 26, weight: .bold))
					.foregroundColor(.white)
				Text(DataManager.shared.appData.carData?.carInfo.model ?? "下拉刷新获取车辆信息")
					.font(.subheadline)
					.foregroundColor(.white.opacity(0.55))
			}
			Spacer()
			HStack(spacing: 6) {
				Circle()
					.fill(bleColor)
					.frame(width: 8, height: 8)
					.shadow(color: bleColor, radius: 4)
				Text(bleText)
					.font(.caption)
					.foregroundColor(.white.opacity(0.7))
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(Color.white.opacity(0.08))
			.clipShape(Capsule())
			.onAppear(perform: startScanningLoop)
			.onDisappear(perform: stopScanningLoop)
		}
		.padding(.top, 6)
		.onTapGesture {
			BluetoothManager.shared.startScan()
		}
	}
}

// MARK: - Car image

struct CarImageSection: View {
	@ObservedObject var dataManager: DataManager

	var body: some View {
		Group {
			if let path = dataManager.appData.carData?.carInfo.image,
			   !path.isEmpty, let url = URL(string: path) {
				AsyncImage(url: url) { phase in
					switch phase {
					case .success(let image):
						image.resizable().scaledToFit()
					default:
						PlaceholderCarImage()
					}
				}
			} else {
				PlaceholderCarImage()
			}
		}
		.frame(height: 150)
		.frame(maxWidth: .infinity)
	}
}

struct PlaceholderCarImage: View {
	var body: some View {
		VStack(spacing: 10) {
			Image(systemName: "car.fill")
				.font(.system(size: 44))
				.foregroundColor(.white.opacity(0.25))
			Text("下拉刷新加载车辆数据")
				.font(.caption)
				.foregroundColor(.white.opacity(0.4))
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

// MARK: - Battery hero card

struct BatteryHeroCard: View {
	@ObservedObject var dataManager: DataManager

	private var soc: Int? {
		dataManager.appData.carData?.carStatus.batterySOCPercentage
	}
	private var rangeKm: Int? {
		dataManager.appData.carData?.carStatus.remainingMileage
	}
	private var isCharging: Bool {
		let s = dataManager.appData.carData?.carStatus
		return s?.vecChrgingSts == "1" || s?.charging == "1"
	}
	private var totalKm: String {
		let raw = dataManager.appData.carData?.carStatus.mileage ?? ""
		guard let v = Double(raw) else { return "--" }
		return v >= 10000
			? String(format: "%.1f 万", v / 10000)
			: String(format: "%.0f", v)
	}

	var body: some View {
		HStack(spacing: 18) {
			// 电量圆环
			ZStack {
				Circle()
					.stroke(Color.white.opacity(0.10), lineWidth: 12)
				Circle()
					.trim(from: 0, to: Double(soc ?? 0) / 100.0)
					.stroke(
						AngularGradient(
							colors: [(soc ?? 0) <= 20 ? Color.orange : Color(hex: 0x34C759),
									 Color(hex: 0x30D158), Color(hex: 0x64D2FF)],
							center: .center,
							startAngle: .degrees(-90),
							endAngle: .degrees(270)
						),
						style: StrokeStyle(lineWidth: 12, lineCap: .round)
					)
					.rotationEffect(.degrees(-90))
					.animation(.easeInOut, value: soc)
				VStack(spacing: 2) {
					Text(soc != nil ? "\(soc!)" : "--")
						.font(.system(size: 30, weight: .heavy, design: .rounded))
						.foregroundColor(.white)
					Text("%")
						.font(.caption2)
						.foregroundColor(.white.opacity(0.5))
				}
			}
			.frame(width: 104, height: 104)

			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 6) {
					Image(systemName: isCharging ? "bolt.fill" : "battery.75percent")
						.font(.system(size: 13))
						.foregroundColor(isCharging ? Color(hex: 0xFFD60A) : Color(hex: 0x30D158))
					Text(isCharging ? "充电中" : "未在充电")
						.font(.caption)
						.foregroundColor(.white.opacity(0.7))
				}
				HStack(alignment: .firstTextBaseline, spacing: 4) {
					Text(rangeKm != nil ? "\(rangeKm!)" : "--")
						.font(.system(size: 34, weight: .heavy, design: .rounded))
						.foregroundColor(.white)
					Text("km")
						.font(.subheadline)
						.foregroundColor(.white.opacity(0.5))
				}
				Text("剩余续航")
					.font(.caption)
					.foregroundColor(.white.opacity(0.45))
				Divider().overlay(Color.white.opacity(0.12))
				Text("总里程 \(totalKm) km")
					.font(.footnote)
					.foregroundColor(.white.opacity(0.6))
			}
			Spacer()
		}
		.padding(18)
		.background(
			RoundedRectangle(cornerRadius: 22)
				.fill(Color.white.opacity(0.07))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 22)
				.stroke(Color.white.opacity(0.10), lineWidth: 1)
		)
	}
}

// MARK: - Status cards

struct StatusGrid: View {
	@ObservedObject var dataManager: DataManager

	private var items: [(icon: String, label: String, value: String)] {
		let s = dataManager.appData.carData?.carStatus
		let soh = s?.batHealth ?? ""
		let cabin = s?.interiorTemperature ?? ""
		let batT = s?.batAvgTemp ?? ""
		let vol = s?.lowBatVol ?? ""
		return [
			("heart.fill", "电池健康", soh.isEmpty ? "--" : "\(soh)%"),
			("thermometer.medium", "车内温度", cabin.isEmpty ? "--" : "\(cabin)°C"),
			("battery.100", "电池均温", batT.isEmpty ? "--" : "\(batT)°C"),
			("car.battery.bolt", "12V电压", vol.isEmpty ? "--" : "\(vol)V")
		]
	}

	private let columns = [GridItem(.flexible()), GridItem(.flexible())]

	var body: some View {
		LazyVGrid(columns: columns, spacing: 10) {
			ForEach(items, id: \.label) { item in
				HStack(spacing: 10) {
					Image(systemName: item.icon)
						.font(.system(size: 15))
						.foregroundColor(Color(hex: 0x64D2FF))
						.frame(width: 22)
					VStack(alignment: .leading, spacing: 2) {
						Text(item.label)
							.font(.caption2)
							.foregroundColor(.white.opacity(0.45))
						Text(item.value)
							.font(.system(size: 15, weight: .semibold, design: .rounded))
							.foregroundColor(.white)
					}
					Spacer()
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 10)
				.background(
					RoundedRectangle(cornerRadius: 14)
						.fill(Color.white.opacity(0.07))
				)
			}
		}
	}
}

// MARK: - Door / window chips

struct VehicleStateChips: View {
	@ObservedObject var dataManager: DataManager

	private var chips: [(String, Bool)] {
		let s = dataManager.appData.carData?.carStatus
		let doorOpen = (s?.doorOpenStatus ?? "0") != "0"
			|| (s?.door1OpenStatus ?? "0") != "0"
			|| (s?.door2OpenStatus ?? "0") != "0"
			|| (s?.door3OpenStatus ?? "0") != "0"
			|| (s?.door4OpenStatus ?? "0") != "0"
		let locked = (s?.doorLockStatus ?? "0") == "0"
		let windowClosed = (s?.windowStatus ?? "0") == "0"
			&& (s?.window1Status ?? "0") == "0"
			&& (s?.window2Status ?? "0") == "0"
			&& (s?.window3Status ?? "0") == "0"
			&& (s?.window4Status ?? "0") == "0"
		let tailClosed = (s?.tailDoorOpenStatus ?? "0") == "0"
		return [
			(locked ? "车门已锁" : "车门未锁", locked),
			(doorOpen ? "车门有开启" : "车门全关", !doorOpen),
			(windowClosed ? "车窗全关" : "车窗有开", windowClosed),
			(tailClosed ? "尾门关闭" : "尾门开启", tailClosed)
		]
	}

	var body: some View {
		HStack(spacing: 8) {
			ForEach(chips, id: \.0) { chip in
				HStack(spacing: 5) {
					Circle()
						.fill(chip.1 ? Color(hex: 0x30D158) : Color.orange)
						.frame(width: 6, height: 6)
					Text(chip.0)
						.font(.caption2)
						.foregroundColor(.white.opacity(0.75))
				}
				.padding(.horizontal, 9)
				.padding(.vertical, 7)
				.background(Color.white.opacity(0.08))
				.clipShape(Capsule())
			}
			Spacer(minLength: 0)
		}
	}
}

// MARK: - Tire pressure card

struct TirePressureCard: View {
	@ObservedObject var dataManager: DataManager

	private var wheels: [(String, String, String)] {
		let t = dataManager.appData.tireData
		return [
			("左前", t?.lfTirPrsVal, t?.lfTirPrStat),
			("右前", t?.rfTirPrsVal, t?.rfTirPrStat),
			("左后", t?.lrTirPrsVal, t?.lrTirPrStat),
			("右后", t?.rrTirPrsVal, t?.rrTirPrStat)
		].map { ($0.0, $0.1 ?? "--", $0.2 ?? "0") }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "gauge.with.needle")
					.font(.system(size: 15))
					.foregroundColor(Color(hex: 0x64D2FF))
				Text("胎压监测")
					.font(.headline)
					.foregroundColor(.white)
				Spacer()
				if let temp = dataManager.appData.tireData?.tirTemp, !temp.isEmpty {
					Text("胎温 \(temp)°C")
						.font(.caption)
						.foregroundColor(.white.opacity(0.6))
				}
			}
			if dataManager.appData.tireData == nil {
				Text("暂无胎压数据（车型不支持或未刷新）")
					.font(.caption)
					.foregroundColor(.white.opacity(0.35))
					.frame(maxWidth: .infinity, alignment: .center)
					.padding(.vertical, 10)
			} else {
				HStack(spacing: 8) {
					ForEach(wheels, id: \.0) { w in
						TireWheelCell(label: w.0, pressure: w.1, stat: w.2)
					}
				}
			}
		}
		.padding(16)
		.background(
			RoundedRectangle(cornerRadius: 22)
				.fill(Color.white.opacity(0.07))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 22)
				.stroke(Color.white.opacity(0.10), lineWidth: 1)
		)
	}
}

struct TireWheelCell: View {
	let label: String
	let pressure: String
	let stat: String

	private var color: Color {
		switch stat {
		case "0": return Color(hex: 0x30D158)
		case "1": return .orange
		case "2": return .red
		default: return .white.opacity(0.6)
		}
	}

	var body: some View {
		VStack(spacing: 5) {
			ZStack {
				Circle().stroke(color.opacity(0.25), lineWidth: 5)
				Image(systemName: "car.fill")
					.font(.system(size: 15))
					.foregroundColor(color)
			}
			.frame(width: 42, height: 42)
			Text(pressure)
				.font(.system(size: 15, weight: .bold, design: .rounded))
				.foregroundColor(.white)
			Text(label)
				.font(.caption2)
				.foregroundColor(.white.opacity(0.45))
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
		.background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
	}
}

// MARK: - Control toast

struct ControlToast: View {
	@ObservedObject var fb = ControlFeedback.shared

	var body: some View {
		if let msg = fb.message {
			HStack(spacing: 8) {
				Image(systemName: fb.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
					.foregroundColor(fb.isSuccess ? Color(hex: 0x30D158) : .orange)
				Text(msg)
					.font(.footnote.weight(.medium))
					.foregroundColor(.white)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				Capsule().fill(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.95))
			)
			.overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
			.transition(.move(edge: .bottom).combined(with: .opacity))
			.animation(.easeInOut(duration: 0.25), value: fb.message)
		}
	}
}

// MARK: - BLE control section

struct ControlSection: View {
	@ObservedObject var bt: BluetoothManager
	@State private var isLocked = true
	@State private var showIgnitionConfirm = false

	private var bleReady: Bool {
		if case .connected = bt.state { return true }
		return false
	}

	var body: some View {
		VStack(spacing: 14) {
			HStack(spacing: 16) {
				CircleControlButton(
					icon: "lock.open.fill",
					label: "解锁",
					color: Color(hex: 0x30D158),
					disabled: !bleReady
				) {
					simpleHaptic(type: .success)
					isLocked = false
					BluetoothManager.shared.CarUnlock()
				}

				CircleControlButton(
					icon: "lock.fill",
					label: "锁车",
					color: Color(hex: 0xFF453A),
					disabled: !bleReady
				) {
					simpleHaptic(type: .success)
					isLocked = true
					BluetoothManager.shared.CarLock()
				}
			}

			HStack(spacing: 10) {
				SquareControlButton(
					icon: "light.beacon.max.fill",
					label: "闪灯寻车",
					color: Color(hex: 0x64D2FF)
				) {
					simpleImpact(style: .light)
					DataManager.shared.sendSearchCar()
				}

				SquareControlButton(
					icon: "flame.fill",
					label: "启动点火",
					color: Color(hex: 0xFFD60A)
				) {
					simpleImpact(style: .medium)
					showIgnitionConfirm = true
				}
			}

			Button(action: {
				simpleHaptic(type: .warning)
				BluetoothManager.shared.CarPowerOff()
			}) {
				Label("整车下电", systemImage: "power")
					.font(.subheadline.weight(.semibold))
					.foregroundColor(.white.opacity(0.85))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
					.background(Color.white.opacity(0.08))
					.clipShape(RoundedRectangle(cornerRadius: 16))
			}
			.disabled(!bleReady)
			.opacity(bleReady ? 1.0 : 0.4)
		}
		.padding(.top, 4)
		.confirmationDialog(
			"确认远程启动点火？",
			isPresented: $showIgnitionConfirm,
			titleVisibility: .visible
		) {
			Button("确认启动", role: .destructive) {
				DataManager.shared.sendIgnitionAuth()
			}
			Button("取消", role: .cancel) {}
		} message: {
			Text("将通过云端下发启动授权指令")
		}
	}
}

struct SquareControlButton: View {
	let icon: String
	let label: String
	let color: Color
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(spacing: 7) {
				Image(systemName: icon)
					.font(.system(size: 21, weight: .medium))
					.foregroundColor(color)
				Text(label)
					.font(.caption.weight(.semibold))
					.foregroundColor(.white)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(color.opacity(0.14))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 16)
					.stroke(color.opacity(0.4), lineWidth: 1.5)
			)
		}
	}
}

struct CircleControlButton: View {
	let icon: String
	let label: String
	let color: Color
	let disabled: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(spacing: 8) {
				Image(systemName: icon)
					.font(.system(size: 26, weight: .medium))
					.foregroundColor(disabled ? .white.opacity(0.35) : color)
				Text(label)
					.font(.caption.weight(.semibold))
					.foregroundColor(disabled ? .white.opacity(0.35) : .white)
			}
			.frame(width: 88, height: 88)
			.background(
				Circle()
					.fill(color.opacity(disabled ? 0.06 : 0.16))
			)
			.overlay(
				Circle()
					.stroke(color.opacity(disabled ? 0.15 : 0.5), lineWidth: 1.5)
			)
		}
		.disabled(disabled)
	}
}

// MARK: - Location

struct CarLocationView: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("车辆位置")
				.font(.caption)
				.foregroundColor(.white.opacity(0.45))
				.padding(.leading, 10)
			Map(bounds: MapCameraBounds(minimumDistance: 200)) {
				Annotation(
					"车辆位置",
					coordinate: GPSTool.gps84_To_Gcj02(
						lon: Double(DataManager.shared.appData.carData?.carStatus.longitude ?? "0") ?? 0.00,
						lat: Double(DataManager.shared.appData.carData?.carStatus.latitude ?? "0") ?? 0.00
					) ?? CLLocationCoordinate2D(latitude: 31, longitude: 128)
				) {
					Image(systemName: "car.fill")
						.foregroundStyle(.white)
						.padding()
						.background(.thickMaterial)
						.clipShape(Circle())
						.imageScale(.small)
				}
				.tint(.gray)
			}
			.mapControlVisibility(.visible)
			.frame(minHeight: 180)
			.clipShape(RoundedRectangle(cornerRadius: 16))
		}
	}
}

// MARK: - Footer

struct FooterInfo: View {
	@ObservedObject var dataManager: DataManager
	@ObservedObject var fetch = FetchStatus.shared

	private var timeText: String {
		if let err = fetch.lastError { return "" }
		if let d = fetch.successDate {
			let f = DateFormatter()
			f.dateFormat = "HH:mm:ss"
			return "更新于 \(f.string(from: d))"
		}
		let updated = dataManager.appData.carData?.updateDate
		return updated == nil ? "从未刷新 · 下拉刷新" : "数据更新于 \(updated!)"
	}

	var body: some View {
		VStack(spacing: 4) {
			if let err = fetch.lastError {
				Text("⚠️ \(err)")
					.font(.caption)
					.foregroundColor(.orange)
					.multilineTextAlignment(.center)
			}
			Text(timeText)
				.font(.caption2)
				.foregroundColor(.white.opacity(0.35))
		}
	}
}

// MARK: - Helpers

extension Color {
	init(hex: UInt32, opacity: Double = 1.0) {
		self.init(
			.sRGB,
			red: Double((hex >> 16) & 0xFF) / 255.0,
			green: Double((hex >> 8) & 0xFF) / 255.0,
			blue: Double(hex & 0xFF) / 255.0,
			opacity: opacity
		)
	}
}

// MARK: - StatusState (referenced by ViewIndicator.swift)

enum StatusState {
	case ok
	case warning(issues: [String])
	case error(issues: [String])

	var iconName: String {
		switch self {
		case .ok: return "checkmark"
		case .warning: return "exclamationmark"
		case .error: return "xmark"
		}
	}

	var color: Color {
		switch self {
		case .ok: return .green
		case .warning: return .orange
		case .error: return .red
		}
	}

	var title: String {
		switch self {
		case .ok: return "车辆状态正常"
		case .warning: return "发现车辆异常"
		case .error: return "出现错误"
		}
	}
}

// MARK: - Preview

struct CarControlsView_Previews: PreviewProvider {
	static var previews: some View {
		CarControlsView()
	}
}
