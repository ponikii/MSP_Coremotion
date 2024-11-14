import SwiftUI
import CoreMotion
import SwiftOSC

class GyroscopeSender: NSObject, ObservableObject {
    private var motionManager: CMMotionManager!
    private var oscClient: OSCClient!
    private var oscMessage: OSCMessage!

    @Published var gyroscopeData: String = ""

    override init() {
        super.init()
        
        // 初始化陀螺仪和 OSC 客户端
        self.motionManager = CMMotionManager()
        self.oscClient = OSCClient(address: "192.168.10.176", port: 12345)  // 设置 Max/MSP 的 IP 地址和端口
        
        // 使用正确的方式初始化 OSC 地址
        self.oscMessage = OSCMessage(OSCAddressPattern("/gyro"))  // 使用 OSCAddressPattern 来初始化地址

        // 启动陀螺仪更新
        startGyroscopeUpdates()
    }

    private func startGyroscopeUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.2  // 每秒获取一次数据
            motionManager.startGyroUpdates(to: OperationQueue.main) { [weak self] (data, error) in
                guard let gyroData = data, error == nil else { return }
                let x = gyroData.rotationRate.x
                let y = gyroData.rotationRate.y
                let z = gyroData.rotationRate.z
                let dataString = "\(x),\(y),\(z)"
                
                // 更新陀螺仪数据显示
                DispatchQueue.main.async {
                    self?.gyroscopeData = dataString
                }
                
                // 发送数据到 Max/MSP
                self?.sendGyroData(x: x, y: y, z: z)
            }
        }
    }
    
    private func sendGyroData(x: Double, y: Double, z: Double) {
        oscMessage.arguments = [x, y, z]  // 设置 OSC 消息的参数
        
        // 将发送操作移到后台队列
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                try self?.oscClient.send(self!.oscMessage)
                print("Sent OSC message: \(self!.oscMessage)")
            } catch {
                print("Failed to send OSC message: \(error)")
            }
        }
    }


//    private func sendGyroData(x: Double, y: Double, z: Double) {
//        oscMessage.arguments = [x, y, z]  // 设置 OSC 消息的参数
//        
//        do {
//            // 发送 OSC 消息到 Max/MSP
//            try oscClient.send(oscMessage)
//            print("Sent OSC message: \(oscMessage)")
//        } catch {
//            print("Failed to send OSC message: \(error)")
//        }
//    }
}

struct ContentView: View {
    @StateObject private var gyroSender = GyroscopeSender()

    var body: some View {
        VStack {
            Text("Gyroscope Data")
                .font(.title)
            Text(gyroSender.gyroscopeData)
                .font(.body)
                .padding()

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}


