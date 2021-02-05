import Foundation

protocol ResponseResult: Decodable {}

struct Response<T: ResponseResult>: Decodable {
    let id: UInt64
    let result: T
}

struct ResponseWithId: Decodable {
    let id: UInt64
}

public struct MessageResponse: ResponseResult {
    public let id: String
    public let message: String
    public let topic: String
}

class ResponseDecoder {
    private lazy var decoder = JSONDecoder()

    func decodeResponseId(data: Data) -> UInt64? {
        do {
            let response = try decoder.decode(ResponseWithId.self, from: data)
            return response.id
        } catch {
            return nil
        }
    }

    func decodeMessage(data: Data) -> MessageResponse? {
        do {
            let response = try decoder.decode(Response<MessageResponse>.self, from: data)
            return response.result
        } catch {
            return nil
        }
    }
}
