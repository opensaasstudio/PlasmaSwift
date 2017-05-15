#import "Stream.pbrpc.h"

#import <ProtoRPC/ProtoRPC.h>
#import <RxLibrary/GRXWriter+Immediate.h>

@implementation PLASMAStreamService

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  return (self = [super initWithHost:host packageName:@"proto" serviceName:@"StreamService"]);
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}


#pragma mark Events(Request) returns (stream Payload)

- (void)eventsWithRequest:(PLASMARequest *)request eventHandler:(void(^)(BOOL done, PLASMAPayload *_Nullable response, NSError *_Nullable error))eventHandler{
  [[self RPCToEventsWithRequest:request eventHandler:eventHandler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToEventsWithRequest:(PLASMARequest *)request eventHandler:(void(^)(BOOL done, PLASMAPayload *_Nullable response, NSError *_Nullable error))eventHandler{
  return [self RPCToMethod:@"Events"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[PLASMAPayload class]
        responsesWriteable:[GRXWriteable writeableWithEventHandler:eventHandler]];
}
@end
