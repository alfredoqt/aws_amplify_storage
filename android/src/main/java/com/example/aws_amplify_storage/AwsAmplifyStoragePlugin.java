package com.example.aws_amplify_storage;

import android.content.Intent;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.amazonaws.mobile.client.AWSMobileClient;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferService;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferType;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferObserver;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener;
import com.amazonaws.services.s3.AmazonS3Client;

import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;


/**
 * AwsAmplifyStoragePlugin
 */
public class AwsAmplifyStoragePlugin implements MethodCallHandler {

    private final Registrar mRegistrar;
    private final MethodChannel mChannel;
    private final TransferUtility mTransferUtility;

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
        AWSMobileClient.getInstance().initialize(registrar.context());

        // Transfer service needs to be initialized
        registrar.context().startActivity(new Intent(registrar.context(), TransferService.class));

        // Initialize the transfer utility as well
        mTransferUtility = TransferUtility
                .builder()
                .context(registrar.context())
                .awsConfiguration(AWSMobileClient.getInstance().getConfiguration())
                .s3Client(new AmazonS3Client(AWSMobileClient.getInstance()))
                .build();
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
        int resumedId = mTransferUtility.resume(id).getId();
        result.success(resumedId);
    }

    private void handleResumeAllWithType(MethodCall call, Result result) {
        Map<String, String> arguments = call.arguments();
        String transferType = arguments.get("transferType");
        switch (transferType) {
            case "ANY":
                result.success(getTransferObserverIds(mTransferUtility.resumeAllWithType(TransferType.ANY)));
                break;
            case "UPLOAD":;
                result.success(getTransferObserverIds(mTransferUtility.resumeAllWithType(TransferType.UPLOAD)));
                break;
            case "DOWNLOAD":
                result.success(getTransferObserverIds(mTransferUtility.resumeAllWithType(TransferType.DOWNLOAD)));
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleCancel(MethodCall call, Result result) {

    }

    private void handleCancelAllWithType(MethodCall call, Result result) {

    }

    private void handleStartListeningTransferState(MethodCall call, Result result) {

    }

    private void handleStopListeningTransferState(MethodCall call, Result result) {

    }

    private List<Integer> getTransferObserverIds(List<TransferObserver> observers) {
        List<Integer> ids = new ArrayList<>();

        for (TransferObserver observer : observers) {
            ids.add(observer.getId());
        }

        return ids;
    }
}
