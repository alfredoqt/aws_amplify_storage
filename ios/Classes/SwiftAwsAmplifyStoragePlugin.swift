import Flutter
import UIKit
import AWSS3
import AWSMobileClient

public class SwiftAwsAmplifyStoragePlugin: NSObject, FlutterPlugin {
    var registrar: FlutterPluginRegistrar!
    var channel: FlutterMethodChannel!
    var taskMap: [UInt: AWSS3TransferUtilityTask] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "aws_amplify_storage", binaryMessenger: registrar.messenger())
        let instance = SwiftAwsAmplifyStoragePlugin(registrar: registrar, channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(registrar: FlutterPluginRegistrar, channel: FlutterMethodChannel) {
        self.registrar = registrar
        self.channel = channel
        
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            if userState != nil {
                DispatchQueue.main.async {
                    let configuration = AWSServiceConfiguration(region: .EUWest2, credentialsProvider: AWSMobileClient.sharedInstance())
                    AWSS3TransferUtility.register(with: configuration!, forKey: "transfer-utility") { (errorTransfer) in
                        if let errorTransfer = errorTransfer {
                            print(errorTransfer.localizedDescription)
                        }
                    }
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "upload":
            handleUpload(call: call, result: result)
            break
        case "download":
            handleDownload(call: call, result: result)
            break
        case "pause":
            handlePause(call: call, result: result)
            break
        case "resume":
            handleResume(call: call, result: result)
            break
        case "cancel":
            handleCancel(call: call, result: result)
            break
        case "stopListeningTransferState":
            handleStopListeningTransferState(call: call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }
    
    func handleUpload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, String>
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "transfer-utility")
        
        let expression = AWSS3TransferUtilityUploadExpression()
        
        expression.progressBlock = {(task, progress) in
            print("Progress Block \(task.status)")
            DispatchQueue.main.async {
                let fractionCompleted = Int(progress.fractionCompleted * 100)
                var map: [String: Any] = [:]
                map["id"] = Int(task.taskIdentifier)
                map["transferState"] = "PROGRESS_CHANGED"
                map["progress"] = fractionCompleted
                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
            }
        }
        
        var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
        completionHandler = { (task, error) -> Void in
            print("Completion handler \(task.status)")
            DispatchQueue.main.async {
                if let _ = error {
                    var map: [String: Any] = [:]
                    map["id"] = Int(task.taskIdentifier)
                    map["transferState"] = "ERROR"
                    map["progress"] = -1
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                } else {
                    var map: [String: Any] = [:]
                    map["id"] = Int(task.taskIdentifier)
                    map["transferState"] = "COMPLETED"
                    map["progress"] = Int(task.progress.fractionCompleted * 100)
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                }
            }
        }
        
        if let transferUtility = transferUtility {
            if let pathname = arguments["pathname"], let bucket = arguments["bucket"], let bucketKey = arguments["bucketKey"], let contentType = arguments["contentType"] {
                let fileUrl = URL(fileURLWithPath: pathname)
                transferUtility.uploadFile(fileUrl, bucket: bucket, key: bucketKey, contentType: contentType, expression: expression, completionHandler: completionHandler).continueWith { (task) -> AnyObject? in
                    if let error = task.error {
                        print("Error: \(error.localizedDescription)")
                    }
                    
                    if let uploadTask = task.result {
                        self.taskMap[uploadTask.taskIdentifier] = uploadTask
                    }
                    return nil;
                }
            }
        }
    }
    
    func handleDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, String>
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "transfer-utility")
        
        let expression = AWSS3TransferUtilityDownloadExpression()
        
        expression.progressBlock = {(task, progress) in
            print("Progress Block \(task.status)")
            DispatchQueue.main.async {
                let fractionCompleted = Int(progress.fractionCompleted * 100)
                var map: [String: Any] = [:]
                map["id"] = Int(task.taskIdentifier)
                map["transferState"] = "PROGRESS_CHANGED"
                map["progress"] = fractionCompleted
                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
            }
        }
        
        var completionHandler: AWSS3TransferUtilityDownloadCompletionHandlerBlock?
        completionHandler = { (task, URL, data, error) -> Void in
            print("Completion handler \(task.status)")
            DispatchQueue.main.async {
                if let _ = error {
                    var map: [String: Any] = [:]
                    map["id"] = Int(task.taskIdentifier)
                    map["transferState"] = "ERROR"
                    map["progress"] = -1
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                } else {
                    var map: [String: Any] = [:]
                    map["id"] = Int(task.taskIdentifier)
                    map["transferState"] = "COMPLETED"
                    map["progress"] = Int(task.progress.fractionCompleted * 100)
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                }
            }
        }
        
        if let transferUtility = transferUtility {
            if let pathname = arguments["pathname"], let bucket = arguments["bucket"], let bucketKey = arguments["bucketKey"] {
                let fileUrl = URL(fileURLWithPath: pathname)
                transferUtility.download(to: fileUrl, bucket: bucket, key: bucketKey, expression: expression, completionHandler: completionHandler).continueWith {
                    (task) -> AnyObject? in
                    if let error = task.error {
                        print("Error: \(error.localizedDescription)")
                    }
                    
                    if let downloadTask = task.result {
                        self.taskMap[downloadTask.taskIdentifier] = downloadTask
                    }
                    return nil
                }
                
            }
        }
    }
    
    func handlePause(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                task.suspend()
                result(true)
                return
            }
            result(false)
            return
        }
        result(false)
    }
    
    func handleResume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                task.resume()
                result(id)
                return
            }
            result(nil)
            return
        }
        result(nil)
    }
    
    func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                task.cancel()
                result(true)
                return
            }
            result(false)
            return
        }
        result(false)
    }
    
    func handleStopListeningTransferState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                // TODO: Check how to do a proper cleanup
                result(id)
                return
            }
            result(nil)
            return
        }
        result(nil)
    }
    
}
