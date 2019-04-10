import Flutter
import UIKit
import AWSS3
import AWSMobileClient

public class SwiftAwsAmplifyStoragePlugin: NSObject, FlutterPlugin {
    var registrar: FlutterPluginRegistrar!
    var channel: FlutterMethodChannel!
    
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
            DispatchQueue.main.async {
                let fractionCompleted = Int(progress.fractionCompleted * 100)
                var map: [String: Any] = [:]
                map["id"] = task.taskIdentifier
                map["transferState"] = "PROGRESS_CHANGED"
                map["progress"] = fractionCompleted
                self.channel.invokeMethod("onTransferStateChanged", arguments: map)
            }
        }
        
        var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
        completionHandler = { (task, error) -> Void in
            DispatchQueue.main.async {
                if let _ = error {
                    var map: [String: Any] = [:]
                    map["id"] = task.taskIdentifier
                    map["transferState"] = "ERROR"
                    map["progress"] = -1
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                } else {
                    var map: [String: Any] = [:]
                    map["id"] = task.taskIdentifier
                    map["transferState"] = "COMPLETED"
                    map["progress"] = Int(task.progress.fractionCompleted * 100)
                    self.channel.invokeMethod("onTransferStateChanged", arguments: map)
                }
            }
        }
        
        if let transferUtility = transferUtility {
            if let pathname = arguments["pathname"], let bucket = arguments["bucket"], let bucketKey = arguments["bucketKey"], let contentType = arguments["contentType"] {
                let fileUrl = URL(fileURLWithPath: pathname)
                transferUtility.uploadFile(fileUrl, bucket: bucket, key: bucketKey, contentType: contentType, expression: expression, completionHandler: completionHandler)
                
            }
        }
    }
    
    func handleDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    func handlePause(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    func handleResume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    func handleStopListeningTransferState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
}
