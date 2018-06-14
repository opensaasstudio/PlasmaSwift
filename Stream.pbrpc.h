#import "Stream.pbobjc.h"

#import <ProtoRPC/ProtoService.h>
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>



NS_ASSUME_NONNULL_BEGIN

@protocol PLASMAStreamService <NSObject>

#pragma mark Events(stream Request) returns (stream Payload)

- (void)eventsWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, PLASMAPayload *_Nullable response, NSError *_Nullable error))eventHandler;

- (GRPCProtoCall *)RPCToEventsWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, PLASMAPayload *_Nullable response, NSError *_Nullable error))eventHandler;


@end

/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface PLASMAStreamService : GRPCProtoService<PLASMAStreamService>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end

NS_ASSUME_NONNULL_END
