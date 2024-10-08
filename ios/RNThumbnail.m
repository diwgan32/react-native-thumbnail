
#import "RNThumbnail.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAsset.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@implementation RNThumbnail

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(get:(NSString *)filepath
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self getThumbnail:filepath second:@(1.0) type:@"raw" resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getSecond:(NSString *)filepath
                  second:(nonnull NSNumber *)second
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self getThumbnail:filepath second:second type:@"raw" resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getSecondAndType:(NSString *)filepath
                  second:(nonnull NSNumber *)second
                  type:(nonnull NSString *)type
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self getThumbnail:filepath second:second type:type resolve:resolve reject:reject];
}

- (void)getThumbnail:(NSString *)filepath
        second:(NSNumber *)second
        type:(NSString *)type
        resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject
{
    @try {
        filepath = [filepath stringByReplacingOccurrencesOfString:@"file://"
                                                  withString:@""];
        __block NSURL *vidURL;
      
        if ([filepath hasPrefix:@"ph://"]) {
            PHFetchResult *phAssetFetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[[filepath substringFromIndex: 5]] options:nil];
            if (phAssetFetchResult.count == 0) {
                @throw([NSException exceptionWithName:@"Error" reason:@"Failed to fetch PHAsset" userInfo:nil]);
            }

            PHAsset *phAsset = [phAssetFetchResult firstObject];
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.networkAccessAllowed = YES;
            options.version = PHVideoRequestOptionsVersionOriginal;
            options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;

            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    vidURL = [(AVURLAsset *)asset URL];
                    dispatch_group_leave(group);
                }
            }];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        } else {
            vidURL = [NSURL fileURLWithPath:filepath];
        }
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:vidURL options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        
        NSError *err = NULL;
        CMTime time = CMTimeMakeWithSeconds([second doubleValue], 60);
        
        CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&err];
        UIImage *thumbnail = [UIImage imageWithCGImage:imgRef];
        // save to temp directory
        NSString* tempDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                       NSUserDomainMask,
                                                                       YES) lastObject];
        
        NSData *data = UIImageJPEGRepresentation(thumbnail, 1.0);
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *fullPath = [tempDirectory stringByAppendingPathComponent: [NSString stringWithFormat:@"thumb-%@.jpg", [[NSProcessInfo processInfo] globallyUniqueString]]];
        [fileManager createFileAtPath:fullPath contents:data attributes:nil];
        CGImageRelease(imgRef);
        if (resolve) {
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            [result setValue:[NSNumber numberWithFloat: thumbnail.size.width] forKey:@"width"];
            [result setValue:[NSNumber numberWithFloat: thumbnail.size.height] forKey:@"height"];
            if ([type isEqualToString:@"raw"]) {
                [result setValue:fullPath forKey:@"path"];
            } else if ([type isEqualToString:@"base64"]) {
                NSFileManager *manager = [NSFileManager defaultManager];
                NSData *content = [manager contentsAtPath:fullPath];
                NSString *base64Content = [content base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                [result setValue:base64Content forKey:@"base64"];
                NSError *error = nil;
                [manager removeItemAtPath:fullPath error:&error];
            }
            resolve(result);
        }
    } @catch(NSException *e) {
        reject(e.reason, nil, nil);
    }
}

@end
  
