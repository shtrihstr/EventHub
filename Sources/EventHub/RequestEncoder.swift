import Foundation

enum RequestMethod: String, Encodable {
    case subscribe
    case unsubscribe
    case ping
}

struct Request<T: RequestParams>: Encodable {
    let id: UInt64
    let jsonrpc = "2.0"
    let method: RequestMethod
    let params: T
}

protocol RequestParams: Encodable {}

struct SubscribeRequestParams: RequestParams {
    let topic: String
}

// RequestParams as an array
extension Array: RequestParams where Element == String {}

class RequestEncoder {
    private lazy var encoder: JSONEncoder = { e in
        e.outputFormatting = .withoutEscapingSlashes
        return e
    }(JSONEncoder())
    
    
    func encodeSubscribe(requestId: UInt64, topic: String) -> Data {
        let request = Request<SubscribeRequestParams>(id: requestId,
                                                      method: .subscribe,
                                                      params: .init(topic: topic))
        return encode(request)
    }
    
    func encodeUnsubscribe(requestId: UInt64, topic: String) -> Data {
        let request = Request<[String]>(id: requestId,
                                        method: .unsubscribe,
                                        params: [topic])
        
        return encode(request)
    }
    
    func encodePing(requestId: UInt64) -> Data {
        let request = Request<[String]>(id: requestId,
                                        method: .ping,
                                        params: [])
        return encode(request)
    }
    
    private func encode<T: Encodable>(_ request: T) -> Data {
        let data = try! encoder.encode(request)
        return data
    }
}
