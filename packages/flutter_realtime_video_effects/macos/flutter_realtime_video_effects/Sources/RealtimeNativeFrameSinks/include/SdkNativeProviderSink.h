#import <Foundation/Foundation.h>
@interface SdkNativeProviderSink : NSObject
@property(nonatomic, copy, nullable) void (^onFailure)(NSString * _Nonnull message);
+ (nullable instancetype)attachWithSourceId:(NSString * _Nonnull)sourceId
                                  provider:(NSString * _Nonnull)provider
                              engineHandle:(int64_t)engineHandle
                                   trackId:(uint32_t)trackId;
- (void)dispose;
@end
