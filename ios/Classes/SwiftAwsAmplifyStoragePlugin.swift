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
                    let configuration = AWSServiceConfiguration(region: .USWest2, credentialsProvider: AWSMobileClient.sharedInstance())
                    AWSS3TransferUtility.register(with: configuration!, forKey: "transfer-utility") { (errorTransfer) in
                        if let errorTransfer = errorTransfer {
                            print("Error: \(errorTransfer.localizedDescription)")
                        }
                        print("Success: \(AWSMobileClient.sharedInstance().identityId)")
                        print("Success: \(errorTransfer.debugDescription)")
                    }
                }
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
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
        case "startListeningTransferState":
            handleStartListeningTransferState(call: call, result: result)
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
        
        if let transferUtility = transferUtility {
            if let pathname = arguments["pathname"], let bucket = arguments["bucket"], let bucketKey = arguments["bucketKey"], let contentType = arguments["contentType"] {
                let expression = AWSS3TransferUtilityUploadExpression()
                
                let fileUrl = URL(fileURLWithPath: pathname)
                transferUtility.uploadFile(fileUrl, bucket: bucket, key: bucketKey, contentType: contentType, expression: expression, completionHandler: nil).continueWith { (task) -> AnyObject? in
                    if let error = task.error {
                        print("Error: \(error.localizedDescription)")
                        result(FlutterError(code: "TRANSFER_INIT_FAILED", message: error.localizedDescription, details: nil))
                        return nil
                    }
                    
                    if let uploadTask = task.result {
                        print("Success: \(uploadTask.taskIdentifier)")
                        self.taskMap[uploadTask.taskIdentifier] = uploadTask
                        result(Int(uploadTask.taskIdentifier))
                        return nil
                    }
                    result(nil)
                    return nil;
                }
            }
        }
    }
    
    func handleDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, String>
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "transfer-utility")
        
        if let transferUtility = transferUtility {
            if let pathname = arguments["pathname"], let bucket = arguments["bucket"], let bucketKey = arguments["bucketKey"] {
                let expression = AWSS3TransferUtilityDownloadExpression()
                
                let fileUrl = URL(fileURLWithPath: pathname)
                transferUtility.download(to: fileUrl, bucket: bucket, key: bucketKey, expression: expression, completionHandler: nil).continueWith {
                    (task) -> AnyObject? in
                    if let error = task.error {
                        print("Error: \(error.localizedDescription)")
                        result(FlutterError(code: "TRANSFER_INIT_FAILED", message: error.localizedDescription, details: nil))
                        return nil
                    }
                    
                    if let downloadTask = task.result {
                        print("Success: \(downloadTask.taskIdentifier)")
                        self.taskMap[downloadTask.taskIdentifier] = downloadTask
                        result(Int(downloadTask.taskIdentifier))
                        return nil
                    }
                    result(nil)
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
                result(Int(task.taskIdentifier))
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
    
    func handleStartListeningTransferState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                
                if let taskUpload = task as? AWSS3TransferUtilityUploadTask {
                    let progressBlock: AWSS3TransferUtilityProgressBlock = {(task, progress) in
                        DispatchQueue.main.async {
                            print("Progress Block \(task.status)")
                            let fractionCompleted = Int(progress.fractionCompleted * 100)
                            var map: [String: Any] = [:]
                            map["id"] = Int(taskUpload.taskIdentifier)
                            map["transferState"] = "PROGRESS_CHANGED"
                            map["progress"] = fractionCompleted
                            self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                        }
                    }
                    let completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock = { (task, error) -> Void in
                        DispatchQueue.main.async {
                            if let _ = error {
                                var map: [String: Any] = [:]
                                map["id"] = Int(taskUpload.taskIdentifier)
                                map["transferState"] = "ERROR"
                                map["progress"] = -1
                                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                            } else {
                                var map: [String: Any] = [:]
                                map["id"] = Int(taskUpload.taskIdentifier)
                                map["transferState"] = "COMPLETED"
                                map["progress"] = Int(taskUpload.progress.fractionCompleted * 100)
                                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                            }
                        }
                    }
                    taskUpload.setCompletionHandler(completionHandler)
                    taskUpload.setProgressBlock(progressBlock)
                    result(Int(taskUpload.taskIdentifier))
                    return
                }
                if let taskDownload = task as? AWSS3TransferUtilityDownloadTask {
                    let progressBlock: AWSS3TransferUtilityProgressBlock = {(task, progress) in
                        DispatchQueue.main.async {
                            print("Progress Block \(task.status)")
                            let fractionCompleted = Int(progress.fractionCompleted * 100)
                            var map: [String: Any] = [:]
                            map["id"] = Int(taskDownload.taskIdentifier)
                            map["transferState"] = "PROGRESS_CHANGED"
                            map["progress"] = fractionCompleted
                            self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                        }
                    }
                    let completionHandler: AWSS3TransferUtilityDownloadCompletionHandlerBlock = { (task, URL, data, error) -> Void in
                        DispatchQueue.main.async {
                            if let _ = error {
                                var map: [String: Any] = [:]
                                map["id"] = Int(taskDownload.taskIdentifier)
                                map["transferState"] = "ERROR"
                                map["progress"] = -1
                                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                            } else {
                                var map: [String: Any] = [:]
                                map["id"] = Int(taskDownload.taskIdentifier)
                                map["transferState"] = "COMPLETED"
                                map["progress"] = Int(taskDownload.progress.fractionCompleted * 100)
                                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                            }
                        }
                    }
                    taskDownload.setCompletionHandler(completionHandler)
                    taskDownload.setProgressBlock(progressBlock)
                    result(Int(taskDownload.taskIdentifier))
                    return
                }
                result(nil)
                return
            }
            result(nil)
            return
        }
        result(nil)
    }
    
    func handleStopListeningTransferState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Int>
        if let id = arguments["id"] {
            let parsedId = UInt(id)
            if let task = taskMap[parsedId] {
                // TODO: Check how to do a proper cleanup
                result(Int(task.taskIdentifier))
                return
            }
            result(nil)
            return
        }
        result(nil)
    }
    
}
