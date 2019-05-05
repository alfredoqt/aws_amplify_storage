#import "AwsAmplifyStoragePlugin.h"
#import "AWSS3.h"
#import "AWSInfo.h"

@interface AwsAmplifyStoragePlugin ()
@property(nonatomic, retain) NSMutableDictionary<NSNumber *, AWSS3TransferUtilityTask *>* taskMap;
@property(nonatomic, retain) FlutterMethodChannel* channel;
@end

@implementation AwsAmplifyStoragePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"aws_amplify_storage"
            binaryMessenger:[registrar messenger]];
    AwsAmplifyStoragePlugin* instance = [[AwsAmplifyStoragePlugin alloc] init];
    instance.channel = channel;
    instance.taskMap = [[NSMutableDictionary alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString* pathToAWSConfigJson = [[NSBundle mainBundle] pathForResource:@"awsconfiguration" ofType:@"json"];
        NSLog(@"Configuration '@'", pathToAWSConfigJson);
        AWSCognitoCredentialsProvider* credentialsProvider = [[AWSCognitoCredentialsProvider alloc] initWithRegionType:AWSRegionUSWest2 identityPoolId:@"us-west-2:bfae5467-d7c7-4b54-b940-c30d7303767a"];
        AWSServiceConfiguration* configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSWest2 credentialsProvider:credentialsProvider];
        [AWSS3TransferUtility registerS3TransferUtilityWithConfiguration:configuration forKey:@"transfer-utility" completionHandler:^(NSError* error) {
            if (error) {
                NSLog(@"Error '%@'", error.localizedDescription);
            }
        }];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"upload" isEqualToString:call.method]) {
      NSString* pathname = call.arguments[@"pathname"];
      NSString* bucket = call.arguments[@"bucket"];
      NSString* bucketKey = call.arguments[@"bucketKey"];
      NSString* contentType = call.arguments[@"contentType"];
      AWSS3TransferUtility* transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:@"transfer-utility"];
      if (transferUtility) {
          AWSS3TransferUtilityUploadExpression* expression = [[AWSS3TransferUtilityUploadExpression alloc] init];
          NSURL* url = [[NSURL alloc] initFileURLWithPath:pathname];
          [[transferUtility uploadFile:url bucket:bucket key:bucketKey contentType:contentType expression:expression completionHandler:nil] continueWithBlock:^id(AWSTask<AWSS3TransferUtilityUploadTask *>* task) {
              if (task.error) {
                  NSLog(@"Error '%@'", task.error.localizedDescription);
                  result([FlutterError errorWithCode:@"TRANSFER_INIT_FAILED" message:task.error.localizedDescription details:nil]);
                  return nil;
              }
              if (task.result) {
                  NSLog(@"Success '%lu'", (unsigned long)task.result.taskIdentifier);
                  NSNumber* identifier = [NSNumber numberWithUnsignedInteger:task.result.taskIdentifier];
                  [self.taskMap setObject:task.result forKey:identifier];
                  result(identifier);
                  return nil;
              }
              return nil;
          }];
      }
  } else if ([@"download" isEqualToString:call.method]) {
      NSString* pathname = call.arguments[@"pathname"];
      NSString* bucket = call.arguments[@"bucket"];
      NSString* bucketKey = call.arguments[@"bucketKey"];
      AWSS3TransferUtility* transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:@"transfer-utility"];
      if (transferUtility) {
          AWSS3TransferUtilityDownloadExpression* expression = [[AWSS3TransferUtilityDownloadExpression alloc] init];
          NSURL* url = [[NSURL alloc] initFileURLWithPath:pathname];
          [[transferUtility downloadToURL:url bucket:bucket key:bucketKey expression:expression completionHandler:nil] continueWithBlock:^id(AWSTask<AWSS3TransferUtilityDownloadTask *>* task) {
              if (task.error) {
                  NSLog(@"Error '%@'", task.error.localizedDescription);
                  result([FlutterError errorWithCode:@"TRANSFER_INIT_FAILED" message:task.error.localizedDescription details:nil]);
                  return nil;
              }
              if (task.result) {
                  NSLog(@"Success '%lu'", (unsigned long)task.result.taskIdentifier);
                  NSNumber* identifier = [NSNumber numberWithUnsignedInteger:task.result.taskIdentifier];
                  [self.taskMap setObject:task.result forKey:identifier];
                  result(identifier);
                  return nil;
              }
              return nil;
          }];
      }
  } else if ([@"pause" isEqualToString:call.method]) {
      NSNumber *identifier = [NSNumber numberWithInteger:[call.arguments[@"id"] unsignedIntegerValue]];
      AWSS3TransferUtilityTask* task = self.taskMap[identifier];
      if (task) {
          NSNumber* paused = [NSNumber numberWithBool:YES];
          [task suspend];
          result(paused);
      } else {
          result([FlutterError
                  errorWithCode:@"ERROR_TASK_NOT_FOUND"
                  message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                           identifier.intValue]
                  details:nil]);
      }
  } else if ([@"resume" isEqualToString:call.method]) {
      NSNumber *identifier = [NSNumber numberWithInteger:[call.arguments[@"id"] unsignedIntegerValue]];
      AWSS3TransferUtilityTask* task = self.taskMap[identifier];
      if (task) {
          NSNumber* resumed = [NSNumber numberWithUnsignedInteger:task.taskIdentifier];
          [task resume];
          result(resumed);
      } else {
          result([FlutterError
                  errorWithCode:@"ERROR_TASK_NOT_FOUND"
                  message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                           identifier.intValue]
                  details:nil]);
      }
  } else if ([@"cancel" isEqualToString:call.method]) {
      NSNumber *identifier = [NSNumber numberWithInteger:[call.arguments[@"id"] unsignedIntegerValue]];
      AWSS3TransferUtilityTask* task = self.taskMap[identifier];
      if (task) {
          NSNumber* canceled = [NSNumber numberWithBool:YES];
          [task cancel];
          result(canceled);
      } else {
          result([FlutterError
                  errorWithCode:@"ERROR_TASK_NOT_FOUND"
                  message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                           identifier.intValue]
                  details:nil]);
      }
  } else if ([@"startListeningTransferState" isEqualToString:call.method]) {
      NSNumber* identifier = [NSNumber numberWithInteger:[call.arguments[@"id"] unsignedIntegerValue]];
      AWSS3TransferUtilityTask* task = self.taskMap[identifier];
      if (task) {
          if ([task isKindOfClass:[AWSS3TransferUtilityUploadTask class]]) {
              AWSS3TransferUtilityUploadTask* uploadTask = task;
              NSNumber* taskIdentifier = [NSNumber numberWithUnsignedInteger:uploadTask.taskIdentifier];
              [uploadTask setCompletionHandler:^(AWSS3TransferUtilityUploadTask* taskCompletion, NSError* error) {
                  if (error) {
                      NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                      response[@"id"] = taskIdentifier;
                      response[@"transferState"] = @"ERROR";
                      response[@"progress"] = [NSNumber numberWithDouble:-1.0];
                      [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
                  } else {
                      NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                      response[@"id"] = taskIdentifier;
                      response[@"transferState"] = @"COMPLETED";
                      response[@"progress"] = [NSNumber numberWithDouble:taskCompletion.progress.fractionCompleted];
                      [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
                  }
              }];
              [uploadTask setProgressBlock:^(AWSS3TransferUtilityTask* taskProgress, NSProgress* progress) {
                  NSLog(@"Progress Block status: '%ld'", (long)taskProgress.status);
                  NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                  response[@"id"] = taskIdentifier;
                  response[@"transferState"] = @"PROGRESS_CHANGED";
                  response[@"progress"] = [NSNumber numberWithDouble:progress.fractionCompleted];
                  [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
              }];
              result(taskIdentifier);
          } else if ([task isKindOfClass:[AWSS3TransferUtilityDownloadTask class]]) {
              AWSS3TransferUtilityDownloadTask* downloadTask = task;
              NSNumber* taskIdentifier = [NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier];
              [downloadTask setCompletionHandler:^(AWSS3TransferUtilityDownloadTask* taskCompletion, NSURL* location, NSData* data, NSError* error) {
                  if (error) {
                      NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                      response[@"id"] = taskIdentifier;
                      response[@"transferState"] = @"ERROR";
                      response[@"progress"] = [NSNumber numberWithDouble:-1.0];
                      [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
                  } else {
                      NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                      response[@"id"] = taskIdentifier;
                      response[@"transferState"] = @"COMPLETED";
                      response[@"progress"] = [NSNumber numberWithDouble:taskCompletion.progress.fractionCompleted];
                      response[@"location"] = location.absoluteString;
                      [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
                  }
              }];
              [downloadTask setProgressBlock:^(AWSS3TransferUtilityTask* taskProgress, NSProgress* progress) {
                  NSLog(@"Progress Block status: '%ld'", (long)taskProgress.status);
                  NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
                  response[@"id"] = taskIdentifier;
                  response[@"transferState"] = @"PROGRESS_CHANGED";
                  response[@"progress"] = [NSNumber numberWithDouble:progress.fractionCompleted];
                  [self.channel invokeMethod:@"onTransferStateChanged" arguments:response];
              }];
              result(taskIdentifier);
          } else {
              result([FlutterError
                      errorWithCode:@"ERROR_TASK_NOT_FOUND"
                      message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                               identifier.intValue]
                      details:nil]);
          }
      } else {
          result([FlutterError
                  errorWithCode:@"ERROR_TASK_NOT_FOUND"
                  message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                           identifier.intValue]
                  details:nil]);
      }
  } else if ([@"stopListeningTransferState" isEqualToString:call.method]) {
      NSNumber* identifier = [NSNumber numberWithInteger:[call.arguments[@"id"] unsignedIntegerValue]];
      AWSS3TransferUtilityTask* task = self.taskMap[identifier];
      if (task) {
          [self.taskMap removeObjectForKey:identifier];
          result(nil);
      } else {
          result([FlutterError
                  errorWithCode:@"ERROR_TASK_NOT_FOUND"
                  message:[NSString stringWithFormat:@"Task with identifier '%d' not found.",
                           identifier.intValue]
                  details:nil]);
      }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
