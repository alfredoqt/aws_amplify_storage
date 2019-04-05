package com.example.aws_amplify_storage;

import android.content.Intent;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.amazonaws.mobile.client.AWSMobileClient;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferService;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferObserver;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener;
import com.amazonaws.services.s3.AmazonS3Client;

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
                break;
            case "download":
                break;
            case "pause":
                break;
            case "pauseAllWithType":
                break;
            case "resume":
                break;
            case "resumeAllWithType":
                break;
            case "cancel":
                break;
            case "cancelAllWithType":
                break;
            default:
                result.notImplemented();
                break;
        }
    }
}
