package com.example.aws_amplify_storage;

import android.content.Intent;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.amazonaws.mobile.client.AWSMobileClient;
import com.amazonaws.mobile.client.Callback;
import com.amazonaws.mobile.client.UserStateDetails;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferService;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferType;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferObserver;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener;
import com.amazonaws.services.s3.AmazonS3Client;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


/**
 * AwsAmplifyStoragePlugin
 */
public class AwsAmplifyStoragePlugin implements MethodCallHandler {

    private final Registrar mRegistrar;
    private final MethodChannel mChannel;
    private TransferUtility mTransferUtility;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "aws_amplify_storage");
        channel.setMethodCallHandler(new AwsAmplifyStoragePlugin(registrar, channel));
    }

    private AwsAmplifyStoragePlugin(Registrar registrar, MethodChannel channel) {
        mRegistrar = registrar;
        mChannel = channel;

        // Initialize the AWS Mobile Client
        AWSMobileClient.getInstance().initialize(registrar.context(), new Callback<UserStateDetails>() {
            @Override
            public void onResult(UserStateDetails result) {
                // Initialize the transfer utility as well
                mTransferUtility = TransferUtility
                        .builder()
                        .context(mRegistrar.context())
                        .awsConfiguration(AWSMobileClient.getInstance().getConfiguration())
                        .s3Client(new AmazonS3Client(AWSMobileClient.getInstance()))
                        .build();
            }

            @Override
            public void onError(Exception e) {

            }
        });

        // Transfer service needs to be initialized
        registrar.context().startActivity(new Intent(registrar.context(), TransferService.class));

    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "upload":
                handleUpload(call, result);
                break;
            case "download":
                handleDownload(call, result);
                break;
            case "pause":
                handlePause(call, result);
                break;
            case "pauseAllWithType":
                handlePauseAllWithType(call, result);
                break;
            case "resume":
                handleResume(call, result);
                break;
            case "resumeAllWithType":
                handleResumeAllWithType(call, result);
                break;
            case "cancel":
                handleCancel(call, result);
                break;
            case "cancelAllWithType":
                handleCancelAllWithType(call, result);
                break;
            case "startListeningTransferState":
                handleStartListeningTransferState(call, result);
                break;
            case "stopListeningTransferState":
                handleStopListeningTransferState(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleUpload(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String bucket = arguments.get("bucket");
        String bucketKey = arguments.get("bucketKey");
        String pathname = arguments.get("pathname");
        int id = mTransferUtility.upload(bucket, bucketKey, new File(pathname)).getId();
        result.success(id);
    }

    private void handleDownload(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String bucket = arguments.get("bucket");
        String bucketKey = arguments.get("bucketKey");
        String pathname = arguments.get("pathname");
        int id = mTransferUtility.download(bucket, bucketKey, new File(pathname)).getId();
        result.success(id);
    }

    private void handlePause(MethodCall call, Result result) {
        Map<String, Integer> arguments = call.arguments();
        int id = arguments.get("id");
        boolean paused = mTransferUtility.pause(id);
        result.success(paused);
    }

    private void handlePauseAllWithType(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String transferType = arguments.get("transferType");
        switch (transferType) {
            case "ANY":
                mTransferUtility.pauseAllWithType(TransferType.ANY);
                result.success(null);
                break;
            case "UPLOAD":
                mTransferUtility.pauseAllWithType(TransferType.UPLOAD);
                result.success(null);
                break;
            case "DOWNLOAD":
                mTransferUtility.pauseAllWithType(TransferType.DOWNLOAD);
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleResume(MethodCall call, Result result) {
        Map<String, Integer> arguments = call.arguments();
        int id = arguments.get("id");
        TransferObserver observer = mTransferUtility.resume(id);
        if (observer != null) {
            result.success(observer.getId());
            return;
        }
        result.success(null);
    }

    private void handleResumeAllWithType(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String transferType = arguments.get("transferType");
        switch (transferType) {
            case "ANY":
                result.success(getTransferObserverIds(mTransferUtility
                        .resumeAllWithType(TransferType.ANY)));
                break;
            case "UPLOAD":
                result.success(getTransferObserverIds(mTransferUtility
                        .resumeAllWithType(TransferType.UPLOAD)));
                break;
            case "DOWNLOAD":
                result.success(getTransferObserverIds(mTransferUtility
                        .resumeAllWithType(TransferType.DOWNLOAD)));
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleCancel(MethodCall call, Result result) {
        Map<String, Integer> arguments = call.arguments();
        int id = arguments.get("id");
        boolean cancelled = mTransferUtility.cancel(id);
        result.success(cancelled);
    }

    private void handleCancelAllWithType(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String transferType = arguments.get("transferType");
        switch (transferType) {
            case "ANY":
                mTransferUtility.cancelAllWithType(TransferType.ANY);
                result.success(null);
                break;
            case "UPLOAD":
                mTransferUtility.cancelAllWithType(TransferType.UPLOAD);
                result.success(null);
                break;
            case "DOWNLOAD":
                mTransferUtility.cancelAllWithType(TransferType.DOWNLOAD);
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleStartListeningTransferState(MethodCall call, final Result result) {
        Map<String, Integer> arguments = call.arguments();
        int id = arguments.get("id");
        final TransferObserver observer = mTransferUtility.getTransferById(id);
        if (observer == null) {
            result.success(null);
            return;
        }
        TransferListener listener = new TransferListener() {
            @Override
            public void onStateChanged(int id, TransferState state) {
                Map<String, Object> map = new HashMap<>();
                switch (state) {
                    /* A transfer is initially in WAITING state when added */
                    case WAITING:
                        map.put("id", observer.getId());
                        map.put("transferState", "WAITING");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* It will turn into IN_PROGRESS once it starts */
                    case IN_PROGRESS:
                        map.put("id", observer.getId());
                        map.put("transferState", "IN_PROGRESS");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* Customers can pause the transfer when needed and turns it into PAUSED */
                    case PAUSED:
                        map.put("id", observer.getId());
                        map.put("transferState", "PAUSED");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* Customers can cancel the transfer when needed and turns it into CANCELED */
                    case CANCELED:
                        map.put("id", observer.getId());
                        map.put("transferState", "CANCELED");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* Finally the transfer will succeed as COMPLETED */
                    case COMPLETED:
                        map.put("id", observer.getId());
                        map.put("transferState", "COMPLETED");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* Finally the transfer will fail as FAILED */
                    case FAILED:
                        map.put("id", observer.getId());
                        map.put("transferState", "FAILED");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* WAITING_FOR_NETWORK state may kick in for an active transfer when network is lost */
                    case WAITING_FOR_NETWORK:
                        map.put("id", observer.getId());
                        map.put("transferState", "WAITING_FOR_NETWORK");
                        map.put("progress", getTransferProgress(observer));
                        mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
                        break;
                    /* The following states are used internally and there should be no need to use this states */
                    case PENDING_PAUSE:
                    case RESUMED_WAITING:
                    case PENDING_NETWORK_DISCONNECT:
                    case UNKNOWN:
                    case PART_COMPLETED:
                    case PENDING_CANCEL:
                    default:
                        break;
                }
            }

            @Override
            public void onProgressChanged(int id, long bytesCurrent, long bytesTotal) {
                int progress = (int) (bytesCurrent / bytesTotal * 100);
                Map<String, Object> map = new HashMap<>();
                map.put("id", id);
                /* Custom transfer state */
                map.put("transferState", "PROGRESS_CHANGED");
                map.put("progress", progress);
                mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
            }

            @Override
            public void onError(int id, Exception ex) {
                Map<String, Object> map = new HashMap<>();
                map.put("id", id);
                /* Custom transfer state */
                map.put("transferState", "ERROR");
                map.put("progress", -1);
                mChannel.invokeMethod("onTransferStateChanged", Collections.unmodifiableMap(map));
            }
        };
        observer.setTransferListener(listener);
        result.success(observer.getId());
    }

    private void handleStopListeningTransferState(MethodCall call, Result result) {
        Map<String, Integer> arguments = call.arguments();
        int id = arguments.get("id");
        TransferObserver observer = mTransferUtility.getTransferById(id);
        if (observer == null) {
            result.success(null);
            return;
        }
        observer.cleanTransferListener();
        result.success(observer.getId());
    }

    private List<Integer> getTransferObserverIds(List<TransferObserver> observers) {
        List<Integer> ids = new ArrayList<>();

        for (TransferObserver observer : observers) {
            ids.add(observer.getId());
        }

        return ids;
    }

    private int getTransferProgress(TransferObserver transferObserver) {
        return (int) (transferObserver.getBytesTransferred() / transferObserver.getBytesTotal() * 100);
    }
}
