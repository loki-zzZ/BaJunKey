//
//  CarDetail.swift
//  carkey
//
//  车辆详情页：基本信息 / 电池信息 / 温度信息 / 胎压（iOS 17+ 深色 UI）
//

import SwiftUI

// MARK: - Root

struct VehicleDetailView: View {
	@ObservedObject var dataManager = DataManager.shared
	@State private var showVIN = false
	@State private var showHistory = false

	var body: some View {
		ZStack {
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
					BaselineToggleChip(showHistory: $showHistory)
					VehicleHeaderCard(dataManager: dataManager, showVIN: $showVIN, showHistory: showHistory)
					BatteryInfoSection(dataManager: dataManager, showHistory: showHistory)
					TemperatureSection(dataManager: dataManager)
					FooterInfo(dataManager: dataManager)
					Spacer(minLength: 20)
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
			}
			.refreshable {
				DataManager.shared.fetchAndLoadCarData()
				DataManager.shared.fetchAndLoadTireData()
			}
		}
		.preferredColorScheme(.dark)
		.onAppear {
			if dataManager.appData.tireData == nil {
				DataManager.shared.fetchAndLoadTireData()
			}
		}
	}
}

// MARK: - 到手/历史切换

struct BaselineToggleChip: View {
	@Binding var showHistory: Bool

	var body: some View {
		Button(action: {
			simpleImpact(style: .light)
			withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() }
		}) {
			HStack(spacing: 7) {
				Image(systemName: showHistory ? "clock.arrow.circlepath" : "sparkles")
					.font(.system(size: 13))
					.foregroundColor(Color(hex: 0x64D2FF))
				Text(showHistory ? "正在显示历史数据 · 点击切回到手数据" : "正在显示到手后数据 · 点击查看历史")
					.font(.caption.weight(.medium))
					.foregroundColor(.white.opacity(0.75))
				Spacer()
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
			.background(
				Capsule().fill(Color.white.opacity(0.08))
			)
			.overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
		}
	}
}

// MARK: - 车辆头部卡片（VIN / 颜色 / 购买日期 / 车主天数）

struct VehicleHeaderCard: View {
	@ObservedObject var dataManager: DataManager
	@Binding var showVIN: Bool
	let showHistory: Bool

	private var info: CarInfo? { dataManager.appData.carData?.carInfo }

	private var purchaseText: String {
		guard let info = info else { return "--" }
		let f = DateFormatter()
		f.dateFormat = "yyyy年M月d日"
		if !showHistory { return f.string(from: BaselineStore.baseDate) }
		return f.string(from: info.purchaseDateAsDate)
	}

	private var ownerDayText: String {
		guard let info = info else { return "--" }
		// 到手模式：从到手日期起算；历史模式：优先用车主天数
		if !showHistory {
			let days = Calendar.current.dateComponents(
				[.day],
				from: Calendar.current.startOfDay(for: BaselineStore.baseDate),
				to: Calendar.current.startOfDay(for: Date())
			).day ?? 0
			return days >= 0 ? "\(days) 天" : "--"
		}
		if let d = info.carOwnerDay, d > 0 { return "\(d) 天" }
		let days = Calendar.current.dateComponents(
			[.day],
			from: Calendar.current.startOfDay(for: info.purchaseDateAsDate),
			to: Calendar.current.startOfDay(for: Date())
		).day ?? 0
		return days > 0 ? "\(days) 天" : "--"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				Text(info?.carName ?? "我的车辆")
					.font(.title2.weight(.bold))
					.foregroundColor(.white)
				Text("\(info?.carTypeName ?? "--") \(info?.model ?? "")")
					.font(.subheadline)
					.foregroundColor(.white.opacity(0.6))
				Text(info?.level ?? "")
					.font(.caption)
					.foregroundColor(Color(hex: 0x64D2FF))
			}

			// VIN 行（带眼睛切换）
			HStack(spacing: 10) {
				VStack(alignment: .leading, spacing: 3) {
					Text("VIN")
						.font(.caption2)
						.foregroundColor(.white.opacity(0.45))
					Text(showVIN ? (info?.vin ?? "--") : (info?.vin.masked(percentage: 0.7) ?? "--"))
						.font(.system(.footnote, design: .monospaced))
						.foregroundColor(.white.opacity(0.85))
				}
				Spacer()
				Button(action: { showVIN.toggle() }) {
					Image(systemName: showVIN ? "eye.slash.fill" : "eye.fill")
						.font(.system(size: 14))
						.foregroundColor(Color(hex: 0x64D2FF))
				}
			}
			.padding(12)
			.background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))

			HStack(spacing: 12) {
				DetailField(label: showHistory ? "颜色" : "颜色", value: info?.colorName)
				DetailField(label: "车牌", value: (info?.carPlate.isEmpty == false) ? info?.carPlate : "未上牌")
			}
			HStack(spacing: 12) {
				DetailField(label: showHistory ? "购买日期" : "到手日期", value: purchaseText)
				DetailField(label: showHistory ? "车主天数" : "到手天数", value: ownerDayText)
			}
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

struct DetailField: View {
	let label: String
	let value: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(label)
				.font(.caption2)
				.foregroundColor(.white.opacity(0.45))
			Text(value ?? "--")
				.font(.footnote.weight(.semibold))
				.foregroundColor(.white)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
	}
}

// MARK: - 分区标题

struct DetailSectionHeader: View {
	let icon: String
	let title: String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.system(size: 16))
				.foregroundColor(Color(hex: 0x64D2FF))
			Text(title)
				.font(.headline)
				.foregroundColor(.white)
			Spacer()
		}
		.padding(.leading, 4)
	}
}

// MARK: - 电池信息

struct BatteryInfoSection: View {
	@ObservedObject var dataManager: DataManager
	let showHistory: Bool

	private var items: [(String, String)] {
		let s = dataManager.appData.carData?.carStatus
		let soh = s?.batHealth ?? s?.batSOH ?? ""
		let vol = s?.lowBatVol ?? ""
		let pack = s?.leftBatteryPower ?? ""
		let yest = s?.yesterMileage ?? ""
		// 到手模式：行驶里程 = 当前里程 - 到手里程基准
		let drivenText: String = {
			guard !showHistory,
				let raw = s?.mileage, let v = Double(raw) else {
				return s.flatMap { st in Double(st.mileage).map { String(format: "%.0f km", $0) } } ?? "--"
			}
			return String(format: "%.0f km", max(0, v - BaselineStore.baseKm))
		}()
		return [
			("电量", s?.batterySOCPercentage.map { "\($0)%" } ?? "--"),
			("续航", s?.remainingMileage.map { "\($0) km" } ?? "--"),
			("剩余电量", pack.isEmpty ? "--" : "\(pack) kWh"),
			("健康度", soh.isEmpty ? "--" : "\(soh)%"),
			("低压电压", vol.isEmpty ? "--" : "\(vol) V"),
			(showHistory ? "总里程" : "到手行驶", drivenText),
			("昨日里程", yest.isEmpty ? "--" : "\(yest) km"),
			("充电状态", (s?.vecChrgingSts == "1" || s?.charging == "1") ? "充电中" : "未充电")
		]
	}

	private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			DetailSectionHeader(icon: "bolt.car.fill", title: "电池信息")
			LazyVGrid(columns: columns, spacing: 10) {
				ForEach(items, id: \.0) { item in
					DetailStatCard(value: item.1, label: item.0)
				}
			}
		}
	}
}

// MARK: - 温度信息

struct TemperatureSection: View {
	@ObservedObject var dataManager: DataManager

	private var items: [(String, String)] {
		let s = dataManager.appData.carData?.carStatus
		let t = dataManager.appData.tireData
		let bat = s?.batAvgTemp ?? ""
		let inv = s?.invActTemp ?? ""
		let motor = s?.cdjTemp ?? ""
		let cabin = s?.interiorTemperature ?? ""
		let acc = s.map { String(format: "%.0f", $0.accCntTemp) } ?? ""
		let tire = t?.tirTemp ?? ""
		return [
			("车内温度", cabin.isEmpty ? "--" : "\(cabin)°"),
			("环境温度", acc.isEmpty ? "--" : "\(acc)°"),
			("电池温度", bat.isEmpty ? "--" : "\(bat)°"),
			("逆变器", inv.isEmpty ? "--" : "\(inv)°"),
			("电机温度", motor.isEmpty ? "--" : "\(motor)°"),
			("胎温", tire.isEmpty ? "--" : "\(tire)°")
		]
	}

	private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			DetailSectionHeader(icon: "thermometer.medium.fill", title: "温度信息")
			LazyVGrid(columns: columns, spacing: 10) {
				ForEach(items, id: \.0) { item in
					DetailStatCard(value: item.1, label: item.0)
				}
			}
		}
	}
}

// MARK: - 数值卡片

struct DetailStatCard: View {
	let value: String
	let label: String

	private var valueColor: Color {
		if value == "--" { return .white.opacity(0.4) }
		return Color(hex: 0x64D2FF)
	}

	var body: some View {
		VStack(spacing: 4) {
			Text(value)
				.font(.system(size: 16, weight: .bold, design: .rounded))
				.foregroundColor(valueColor)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			Text(label)
				.font(.caption2)
				.foregroundColor(.white.opacity(0.45))
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 12)
		.background(
			RoundedRectangle(cornerRadius: 14)
				.fill(Color.white.opacity(0.07))
		)
	}
}
