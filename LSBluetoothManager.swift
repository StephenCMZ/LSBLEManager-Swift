//
//  LSBluetoothManager.swift
//  LSBLEManager-Swift
//
//  Created by StephenChen on 2016/10/24.
//  Copyright © 2016年 Lansion. All rights reserved.
//

import UIKit
import CoreBluetooth

enum BLESTATUE: Int{
    case BLESTATUE_UNKNOW           //未知
    case BLESTATUE_RESETTING        //重置中
    case BLESTATUE_UNSUPPORT        //不支持
    case BLESTATUE_UNLAWFUL         //非法
    case BLESTATUE_COLSED           //关闭
    case BLESTATUE_OPENED           //开启，但未连接
    
    case BLESTATUE_DEVICE_SEARCH    //搜索中
    case BLESTATUE_DEVICE_NOTFIND   //找不到设备
    
    case BLESTATUE_CONNECT_ING      //连接中
    case BLESTATUE_CONNECT_FAIL     //连接失败
    case BLESTATUE_CONNECT_DIS      //连接断开
    
    case BLESTATUE_SERVICE_ING      //获取服务中
    case BLESTATUE_SERVICE_FAIL     //获取服务失败
    
    case BLESTATUE_CHARACT_ING      //获取特征(通道)中
    case BLESTATUE_CHARACT_FAIL     //获取特征(通道)失败
    case BLESTATUE_CHARACT_USEFUL   //特征(通道)可用
}

protocol LSBluetoothManagerDelegate: NSObjectProtocol{
    func updateDevices(device: NSArray)
    func updateStatue(statue: BLESTATUE)
    func revicedMessage(msg: Data)
}

class LSBluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate{
    
    public var delegate: LSBluetoothManagerDelegate?
    public var bleStatue: BLESTATUE = .BLESTATUE_UNKNOW
    
    private var serviceUUID: NSString?
    private var outputCharacteristicUUID: NSString?
    private var inputCharacteristicUUID: NSString?
    
    private var centralManager: CBCentralManager! //蓝牙管理
    private var cbPeripheral: CBPeripheral? //连接的设备信息
    private var service: CBService? //当前服务
    private var inputCharacteristic: CBCharacteristic? //连接的设备特征（通道）输入
    private var outPutcharacteristic: CBCharacteristic? //连接的设备特征（通道）输出
    
    private var scanCutdownTimer: Timer? //查找设备倒计时
    private var mPeripherals: NSMutableArray? //找到的设备
    
    static let manager = LSBluetoothManager()
    
    private override init(){
        super.init()
        centralManager = CBCentralManager.init(delegate: self, queue: nil)
    }
    
    
    //MARK: - 蓝牙状态
    
    /**
     *  手机蓝牙状态 0，未知 1，重置中 2，不支持 3，非法 4，关闭 5，开启
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateBLEStatue(statue: BLESTATUE(rawValue: central.state.rawValue)!)
    }
    
    //MARK: - 查找蓝牙
    
    
    /// 查找设备
    public func scanDevice(){
        
        stopScanDevice()
        disconnectDevice()
        
        mPeripherals = NSMutableArray.init()
        
        DispatchQueue.main.async {
            if self.centralManager.state == .poweredOn{
                print("开始搜索蓝牙设备")
                self.centralManager.scanForPeripherals(withServices: nil, options: nil)
                self.updateBLEStatue(statue: .BLESTATUE_DEVICE_SEARCH)
                self.scanCutdownTimer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(self.stopScanDevice), userInfo: nil, repeats: false)
            }else{
                self.updateBLEStatue(statue: BLESTATUE(rawValue: self.centralManager.state.rawValue)!)
            }
        }
        
    }
    
    
    /// 找到蓝牙设备
    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("找到蓝牙设备 -> \(peripheral)")
        
        guard mPeripherals != nil else { return }
        
        if !mPeripherals!.contains(peripheral) {
            mPeripherals!.add(peripheral)
            delegate?.updateDevices(device: mPeripherals!)
        }
    }
    
    
    /// 停止查找设备
    public func stopScanDevice(){
        print("停止搜索蓝牙设备")
        centralManager.stopScan()
        
        if bleStatue == .BLESTATUE_DEVICE_SEARCH {
            updateBLEStatue(statue: .BLESTATUE_DEVICE_NOTFIND)
        }
        
        scanCutdownTimer?.invalidate()
    }
    
    
    //MARK: - 连接蓝牙
    
    
    /// 连接蓝牙
    ///
    /// - parameter peripheral:               设备信息
    /// - parameter serviceUUID:              服务UUID
    /// - parameter outputcharacteristicUUID: 写出特征UUID
    /// - parameter inputcharacteristicUUID:  写入特征UUID
    public func connectDeviceWithCBPeripheral(_ peripheral: CBPeripheral, serviceUUID: NSString, outputcharacteristicUUID: NSString,inputcharacteristicUUID: NSString){
        
        self.cbPeripheral = peripheral
        self.serviceUUID = serviceUUID
        self.outputCharacteristicUUID = outputcharacteristicUUID
        self.inputCharacteristicUUID = inputcharacteristicUUID
        
        reConnectDevice()
        
    }
    
    
    /// 重连蓝牙
    public func reConnectDevice(){
        guard cbPeripheral != nil && serviceUUID != nil && outputCharacteristicUUID != nil && inputCharacteristicUUID != nil else {
            print("peripheral, serviceUUID, outputCharacteristicUUID and inputCharacteristicUUID must not be nil");
            print("if is first time connect, please call connectDeviceWithCBPeripheral:andServiceUUID:andOutputCharacteristicUUID:andInputCharacteristicUUID:");
            return
        }
        
        stopScanDevice()
        disconnectDevice()
        
        DispatchQueue.main.async{
            self.centralManager.connect(self.cbPeripheral!, options: nil)
        }
        
        print("开始连接蓝牙设备")
        updateBLEStatue(statue: .BLESTATUE_CONNECT_ING)
        
    }
    
    
    /// 连接成功
    internal func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("开始查找蓝牙服务")
        
        service = nil
        inputCharacteristic = nil
        outPutcharacteristic = nil
        
        cbPeripheral = peripheral
        cbPeripheral?.delegate = self
        cbPeripheral?.discoverServices(nil)
        
        updateBLEStatue(statue: .BLESTATUE_SERVICE_ING)
    }
    
    /// 连接失败
    internal func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateBLEStatue(statue: .BLESTATUE_CONNECT_FAIL)
    }
    
    /// 发现服务
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("发现服务：\(peripheral) 错误：\(error!.localizedDescription)")
            updateBLEStatue(statue: .BLESTATUE_SERVICE_FAIL)
            return
        }
        
        print("发现服务：-> \(peripheral.services)")
        
        if peripheral.services != nil{
            for service in peripheral.services! {
                if service.uuid.isEqual(CBUUID.init(string: serviceUUID! as String)) {
                    self.service = service
                    DispatchQueue.main.async {
                        print("开始查找服务通道")
                        self.cbPeripheral?.discoverCharacteristics(nil, for: self.service!)
                    }
                    updateBLEStatue(statue: .BLESTATUE_CHARACT_ING)
                    break
                }
            }
        }
        
    }
    
    /// 发现特征
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("发现特征：\(peripheral) 错误：\(error!.localizedDescription)")
            updateBLEStatue(statue: .BLESTATUE_CHARACT_FAIL)
            return
        }
        
        print("发现特征：->\(service.characteristics)")
        
        if service.characteristics != nil {
            for characteristic in service.characteristics!{
                if characteristic.uuid.isEqual(CBUUID.init(string: outputCharacteristicUUID! as String)) {
                    outPutcharacteristic = characteristic
                }
                if characteristic.uuid.isEqual(CBUUID.init(string: inputCharacteristicUUID! as String)) {
                    cbPeripheral?.setNotifyValue(true, for: characteristic)
                    cbPeripheral?.readValue(for: characteristic)
                    inputCharacteristic = characteristic
                }
                if outPutcharacteristic != nil && inputCharacteristic != nil {
                    updateBLEStatue(statue: .BLESTATUE_CHARACT_USEFUL)
                    break
                }
            }
        }
        
    }
    
    
    //MAKR: - 蓝牙断开
    
    
    /// 断开连接
    public func disconnectDevice(){
        print("断开蓝牙连接")
        guard cbPeripheral != nil else { return }
        centralManager.cancelPeripheralConnection(cbPeripheral!)
    }
    
    /// 接收断开连接状态
    internal func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        updateBLEStatue(statue: .BLESTATUE_CONNECT_DIS)
    }
    
    //MARK: - 发送及接收消息
    
    
    /// 发送消息
    ///
    /// - parameter msg: 消息
    public func sendMsg(msg: Data){
        print("msg -> \(msg)")
        guard cbPeripheral != nil && outPutcharacteristic != nil else{ return }
        cbPeripheral?.writeValue(msg, for: outPutcharacteristic!, type: .withResponse)
    }
    
    
    /// 发送消息状态
    internal func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("didWriteValueForCharacteristic -> \(characteristic)")
    }
    
    /// 收到消息
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard error == nil else {
            print("接收数据错误 -> \(error!.localizedDescription)")
            return
        }
        
        print("接收到的数据 -> \(characteristic.value)")
        if let reData = characteristic.value{
            delegate?.revicedMessage(msg: reData)
        }
        
    }
    
    //MARK: - helper
    
    private func updateBLEStatue(statue: BLESTATUE){
        print("蓝牙状态：\(statue.rawValue)")
        bleStatue = statue
        delegate?.updateStatue(statue: bleStatue)
    }
}



