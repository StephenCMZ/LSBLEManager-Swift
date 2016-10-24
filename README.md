# LSBLEManager-Swift
一个简易的蓝牙管理器

##### 使用步骤：
- 导入`LSBluetoothManager.swift`
- 设置代理并获取蓝牙管理器
```
    class ViewController: UIViewController, LSBluetoothManagerDelegate{}
    let bleManager = LSBluetoothManager.manager
    bleManager.delegate = self;
```
- 查找蓝牙
```
	// 查找蓝牙设备
	bleManager.scanDevice()

  // 查找到设备回调
  func updateDevices(device: NSArray) {
     // devices 为 CBPeripheral 集合
  }
```
- 连接蓝牙
```
	//连接蓝牙
	bleManager.connectDeviceWithCBPeripheral(peripheral, serviceUUID: SERVICEUUID, outputcharacteristicUUID: OUTPUTUUID, inputcharacteristicUUID: INPUTUUID)

     // 连接状态回调
	func updateStatue(statue: BLESTATUE) {}
```
- 收发数据
```
	//收到数据回调
	func revicedMessage(msg: Data) {}
	//发送数据
	let data = Data.init(bytes: [89])
  bleManager.sendMsg(msg: data)
```
