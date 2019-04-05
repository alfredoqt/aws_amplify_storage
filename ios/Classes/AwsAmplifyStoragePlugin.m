#import "AwsAmplifyStoragePlugin.h"
#import <aws_amplify_storage/aws_amplify_storage-Swift.h>

@implementation AwsAmplifyStoragePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAwsAmplifyStoragePlugin registerWithRegistrar:registrar];
}
@end
