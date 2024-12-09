import SwiftUI
import CoreMotion
import SwiftOSC

class GyroscopeSender: NSObject, ObservableObject {
    var motionManager: CMMotionManager!
    private var oscClient: OSCClient!
    private var oscMessage: OSCMessage!

    @Published var gyroscopeData: String = ""
    @Published var ipAddress: String = "192.168.10.176"  // 默认 IP 地址
    @Published var port: String = "12345"             // 默认端口
    @Published var gyroUpdateInterval: Double = 0.5   // 默认更新频率 0.5 秒

    override init() {
        super.init()
        self.motionManager = CMMotionManager() // 初始化陀螺仪和 OSC 客户端
        // 默认的 OSC 客户端
        self.oscClient = OSCClient(address: ipAddress, port: Int(port) ?? 12345)
        self.oscMessage = OSCMessage(OSCAddressPattern("/gyro"))  // 使用 OSC 地址模式
        // 启动陀螺仪更新
        startGyroscopeUpdates()
    }

    private func startGyroscopeUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = gyroUpdateInterval  // 根据用户设置的间隔更新
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
    
    // 更新 OSC 客户端 IP 和端口
    func updateClientSettings() {
        if let portNumber = Int(port) {
            self.oscClient = OSCClient(address: ipAddress, port: portNumber)
            print("Updated OSC client to \(ipAddress):\(port)")
        }
    }
}

struct ContentView: View {
    @StateObject private var gyroSender = GyroscopeSender()

    var body: some View {
        VStack {
            // IP 地址输入框
            TextField("Enter IP Address", text: $gyroSender.ipAddress)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)

            // 端口号输入框
            TextField("Enter Port", text: $gyroSender.port)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)

            // 按钮触发 IP 地址和端口更新
            Button(action: {
                gyroSender.updateClientSettings()
            }) {
                Text("Update IP & Port")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // 陀螺仪更新频率控制滑块
            VStack {
                Text("Gyroscope Update Interval: \(String(format: "%.2f", gyroSender.gyroUpdateInterval)) seconds")
                    .padding()

                Slider(value: $gyroSender.gyroUpdateInterval, in: 0.1...1.5, step: 0.05)
                    .padding()
                    .onChange(of: gyroSender.gyroUpdateInterval) { newValue in
                        gyroSender.motionManager.gyroUpdateInterval = newValue  // 动态更新陀螺仪更新间隔
                    }
            }
            .padding()

            // 显示当前陀螺仪数据
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
