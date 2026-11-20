//
//  NetThing.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//
import Foundation
import UIKit
import CoreLocation
import OSLog

let loggerNet = Logger(
	subsystem: "com.sleepyshark.carkey",
	category: "net"
)

// MARK: - 抓取状态（供界面显示错误提示）

final class FetchStatus: ObservableObject {
    static let shared = FetchStatus()
    private init() {}
    @Published var lastError: String?
    @Published var successDate: Date?

    func reportError(_ message: String) {
        DispatchQueue.main.async { self.lastError = message }
    }

    func reportSuccess() {
        DispatchQueue.main.async {
            self.lastError = nil
            self.successDate = Date()
        }
    }
}

// api请求协议
protocol EndpointType {
    var path: String { get }
    var method: String { get }
    var body: [String: Any]? { get }
    var host: String { get }
}

extension EndpointType {
    /// 默认旧网关；个别接口（如胎压新网关）在具体 endpoint 里覆盖
    var host: String { "https://openapi.baojun.net" }
}

enum BaojunEndpoint {
    // 查询默认车辆状态
    case queryDefaultCarStatus
    
    // 一个带有请求体的 POST 接口，例如发送车辆控制命令
    case queryBleKey(vin: String, userId: String)
    
    // 胎压查询（旧/新双网关双保险）
    case queryTirePressure(vin: String)
    case queryTirePressurePlus(vin: String)
    
    // 云端控制：闪灯寻车 / 启动点火授权
    case controlSearchCar(vin: String)
    case controlIgnitionAuth(vin: String)
}

extension BaojunEndpoint: EndpointType {
    var path: String {
        switch self {
        case .queryDefaultCarStatus:
            return "/junApi/sgmw/userCarRelation/queryDefaultCarStatus"
        case .queryBleKey(vin: _, userId: _):
            return "/junApi/sgmw/car/control/ble/key/query"
        case .queryTirePressure:
            return "/junApi/sgmw/car/info/tire/pressure"
        case .queryTirePressurePlus:
            return "/sgmw/car/info/tire/pressure"
        case .controlSearchCar:
            return "/junApi/sgmw/car/control/searchCar"
        case .controlIgnitionAuth:
            return "/junApi/sgmw/car/control/ignition/authorize"
        }
    }
    
    // 接口主机
    var host: String {
        switch self {
        case .queryTirePressurePlus:
            return "https://carc.baojun.net"
        default:
            return "https://openapi.baojun.net"
        }
    }

    // 接口的 HTTP 方法
    var method: String {
        switch self {
        case .queryDefaultCarStatus:
            return "POST"
        case .queryBleKey, .queryTirePressure, .queryTirePressurePlus, .controlSearchCar, .controlIgnitionAuth:
            return "POST"
        }
    }
    
    // 接口的请求体
    var body: [String: Any]? {
        switch self {
        case .queryDefaultCarStatus:
            return nil
        case .queryBleKey(let vin, let userId):
            return ["vin": vin, "userId": userId]
        case .queryTirePressure(let vin), .controlSearchCar(let vin), .controlIgnitionAuth(let vin):
            return ["vin": vin]
        case .queryTirePressurePlus(let vin):
            return ["vin": vin]
        }
    }
}

// MARK: - 云端控制反馈（供界面 toast 显示）

final class ControlFeedback: ObservableObject {
    static let shared = ControlFeedback()
    private init() {}
    @Published var message: String?
    @Published var isSuccess: Bool = false

    func report(_ msg: String, success: Bool) {
        DispatchQueue.main.async {
            self.message = msg
            self.isSuccess = success
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.message == msg { self.message = nil }
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    private let session = URLSession.shared
}

// General part
extension NetworkManager {
    func request(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // 判断响应是否是 HTTP 响应
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                    // 判断状态码是否在 200-299 之间，这之间表示请求成功，否则抛出错误
                let statusError = NSError(domain: "com.networking.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response"])
                completion(.failure(statusError))
                return
            }
            
            // 判断返回的数据是否存在，如果存在则调用 completion 回调
            if let data = data {
                completion(.success(data))
            }
        }
          
        // 开始执行网络请求任务
        task.resume()
    }
}

// Baojun Part
extension NetworkManager {
    // 参数 url: URL，请求的 URL 地址
    // 参数 completion: @escaping (Result<Data, Error>) -> Void，请求完成后的回调
    func requestBaojun(_ endpoint: EndpointType, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: endpoint.host + endpoint.path) else {
                    let error = NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    completion(.failure(error))
                    return
                }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("accept", forHTTPHeaderField: "application/json")
        
        if let headers = DataManager.shared.sgmwUnifiedOAuth.generateAuthenticatedHeaders(plusGateway: endpoint.host.contains("carc.baojun.net")) {
                for (field, value) in headers {
                    request.setValue(value, forHTTPHeaderField: field)
                }
            } else {
                // 处理未登录或无法生成签名的情况
				loggerNet.error("failed to generate SGMW OAuth auth header")
            }
        
        // Advanced device info
        let device = UIDevice.current
        let appInfo = Bundle.main.infoDictionary
        let deviceModel = device.model
        let platformVersion = device.systemVersion
        let deviceBrand = "Apple" // This is a constant for iOS devices
        let appVersion = appInfo?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = appInfo?["CFBundleVersion"] as? String ?? "unknown"
        request.setValue("73", forHTTPHeaderField: "accessChannel")
        request.setValue("%E4%B8%8A%E6%B5%B7%E5%B8%82", forHTTPHeaderField: "cityName")
        request.setValue(getDeviceModelIdentifier(), forHTTPHeaderField: "deviceType")
        request.setValue("iOS", forHTTPHeaderField: "platformNo")
        request.setValue("App Store", forHTTPHeaderField: "channel")
        request.setValue(platformVersion, forHTTPHeaderField: "platformVersion")
        request.setValue("31.262702401106353", forHTTPHeaderField: "latitude")
        request.setValue(appVersion, forHTTPHeaderField: "version")
        request.setValue(appBuild, forHTTPHeaderField: "build")
        request.setValue(deviceModel, forHTTPHeaderField: "deviceModel")
        request.setValue("121.65264383085028", forHTTPHeaderField: "longitude")
        request.setValue(deviceBrand, forHTTPHeaderField: "deviceBrand")
        
        // 如果有请求体，则设置
        if let bodyData = endpoint.body,
           let jsonData = try? JSONSerialization.data(withJSONObject: bodyData, options: []) {
            request.httpBody = jsonData
        }
        
        self.request(request, completion: completion)
    }
}

extension DataManager {
    func fetchAndLoadCarData() {
        
        // 1. 调用你的 NetworkManager 发起请求
        NetworkManager.shared.requestBaojun(BaojunEndpoint.queryDefaultCarStatus) { [weak self] result in
            
            // 确保在主线程处理后续逻辑，因为会更新 @Published 属性
            DispatchQueue.main.async {
                
                switch result {
                    case .success(let data):
                        if let responseString = String(data: data, encoding: .utf8) {
                            self?.loadCarData(from: responseString)
                        }
                    case .failure(let error):
						loggerNet.error("failed to load car data: \(error)")
                        FetchStatus.shared.reportError("网络请求失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchAndLoadKeyData() {
        NetworkManager.shared.requestBaojun(BaojunEndpoint.queryBleKey(vin: DataManager.shared.appData.carData?.carInfo.vin ?? "", userId: DataManager.shared.appData.userData?.userID ?? "")) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                    case .success(let data):
                        if let responseString = String(data: data, encoding: .utf8) {
                            self?.loadKeyData(from: responseString)
                        }
                    case .failure(let error):
						loggerNet.error("failed to load car key data: \(error)")
                        FetchStatus.shared.reportError("网络请求失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchAndLoadTireData() {
        guard let vin = DataManager.shared.appData.carData?.carInfo.vin, !vin.isEmpty else { return }
        // 旧网关
        NetworkManager.shared.requestBaojun(BaojunEndpoint.queryTirePressure(vin: vin)) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let responseString = String(data: data, encoding: .utf8) {
                        self?.loadTireData(from: responseString)
                    }
                case .failure(let error):
                    loggerNet.error("failed to load tire data (old gw): \(error)")
                }
            }
        }
        // 新网关双保险：哪份数据全用哪份
        NetworkManager.shared.requestBaojun(BaojunEndpoint.queryTirePressurePlus(vin: vin)) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let responseString = String(data: data, encoding: .utf8) {
                        self?.loadTireData(from: responseString, merge: true)
                    }
                case .failure(let error):
                    loggerNet.error("failed to load tire data (new gw): \(error)")
                }
            }
        }
    }

    /// 云端控制通用下发：result=true 视为成功
    private func sendCloudCommand(endpoint: BaojunEndpoint, successText: String) {
        NetworkManager.shared.requestBaojun(endpoint) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        ControlFeedback.shared.report("服务器响应解析失败", success: false)
                        return
                    }
                    if json["result"] as? Bool == true {
                        ControlFeedback.shared.report(successText, success: true)
                    } else {
                        let msg = json["errorMessage"] as? String ?? "指令被服务器拒绝"
                        ControlFeedback.shared.report(msg, success: false)
                    }
                case .failure(let error):
                    loggerNet.error("cloud control failed: \(error)")
                    ControlFeedback.shared.report("网络请求失败: \(error.localizedDescription)", success: false)
                }
            }
        }
    }

    private func currentVin() -> String? {
        guard let vin = DataManager.shared.appData.carData?.carInfo.vin, !vin.isEmpty else {
            ControlFeedback.shared.report("还没有车辆信息，先下拉刷新一次", success: false)
            return nil
        }
        return vin
    }

    func sendSearchCar() {
        guard let vin = currentVin() else { return }
        sendCloudCommand(endpoint: .controlSearchCar(vin: vin), successText: "已下发寻车指令，车辆会闪灯鸣笛")
    }

    func sendIgnitionAuth() {
        guard let vin = currentVin() else { return }
        sendCloudCommand(endpoint: .controlIgnitionAuth(vin: vin), successText: "已下发启动点火授权")
    }
}

