import Foundation
import Combine

struct Subscribtion {
    let id: UInt64
    let topic: String
    let subject: PassthroughSubject<MessageResponse, Never>
    let subscribersCount: Int
    
    init(id: UInt64, topic: String) {
        self.id = id
        self.topic = topic
        self.subject = PassthroughSubject<MessageResponse, Never>()
        self.subscribersCount = 1
    }
    
    init (_ subscribtion: Subscribtion, subscribersCount: Int) {
        self.id = subscribtion.id
        self.topic = subscribtion.topic
        self.subject = subscribtion.subject
        self.subscribersCount = subscribersCount
    }
}

struct PendingPing {
    let id: UInt64
    let requestedAt: Date
}

enum ConnectionStatus {
    case connected
    case disconnected
    case connecting
    case paused
}

extension URL {
    func addQueryParam(name: String, value: String) -> URL {
        var urlComponents = URLComponents(string: self.absoluteString)!
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        let queryItem = URLQueryItem(name: name, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        return urlComponents.url!
    }
}

public class EventHub {
    private let ws: WebSocketEngine
    private let encoder = RequestEncoder()
    private let decoder = ResponseDecoder()
    
    private let pingTimeout: TimeInterval = 10
    
    private var lastRequestId: UInt64 = 0
    private let lastRequestIdLock = NSLock()
    
    private var status: ConnectionStatus = .disconnected
    private var subscribtions: [UInt64: Subscribtion] = [:]
    private var pendingPings: [UInt64: PendingPing] = [:]
    
    public init (url: URL, token: String) {
        ws = WebSocketEngine(url: url.addQueryParam(name: "auth", value: token))
        ws.onReceive = { [weak self] data in
            self?.onReceive(data: data)
        }
    }
    
    private func reconnect() {
        guard status == .disconnected else {
            return
        }
        status = .connecting
        
        ws.reconnect()
        
        ws.onConnectionError = { [weak self] in
            self?.disconnect()
            self?.reconnectAfter(delay: 5)
        }
        
        ws.onConnect = {  [weak self] in
            self?.status = .connected
            self?.sendPing()
            self?.subscribtions.values.forEach { subscribtion in
                if let data = self?.encoder.encodeSubscribe(requestId: subscribtion.id, topic: subscribtion.topic) {
                    self?.ws.send(data: data)
                }
            }
        }
    }
    
    private func sendPing() {
        guard status == .connected else {
            return
        }
        
        // check ping losses
        let minRequestedAt = Date() - pingTimeout
        let expiredPings = pendingPings.values.filter { $0.requestedAt < minRequestedAt }
        if expiredPings.count > 3 {
            self.disconnect()
            self.reconnectAfter(delay: 1)
            return
        }
        
        let requestId = getNextRequestId()
        pendingPings[requestId] = .init(id: requestId,
                                        requestedAt: Date())
        ws.send(data: encoder.encodePing(requestId: requestId))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + pingTimeout) { [weak self] in
            self?.sendPing()
        }
    }
    
    private func getNextRequestId() -> UInt64 {
        lastRequestIdLock.lock()
        defer { lastRequestIdLock.unlock() }
        lastRequestId += 1
        return lastRequestId
    }
    
    private func disconnect() {
        status = .disconnected
        ws.disconnect()
        pendingPings = [:]
    }
    
    private func reconnectAfter(delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.reconnect()
        }
    }
    
    private func removeSubscribtion(at id: UInt64) {
        if let subscribtion = subscribtions[id] {
            let requestId = getNextRequestId()
            ws.send(data: encoder.encodeUnsubscribe(requestId: requestId, topic: subscribtion.topic))
            
            subscribtions.removeValue(forKey: id)
            if subscribtions.count == 0 {
                disconnect()
            }
        }
    }

    private func onReceive(data: Data) {
        guard let id = decoder.decodeResponseId(data: data) else {
            // something unexpected
            return
        }
        
        if let subscribtion = subscribtions[id] {
            guard let message = decoder.decodeMessage(data: data) else {
                // probably a subscribtion response
                return
            }
            
            subscribtion.subject.send(message)
            return
        }
        
        if pendingPings.keys.contains(id) {
            pendingPings.removeValue(forKey: id)
            return
        }
    }
    
    public func pause() {
        disconnect()
        status = .paused
    }
    
    public func resume() {
        if status == .paused {
            status = .disconnected
        }
        
        if subscribtions.count > 0 {
            reconnect()
        }
    }
    
    public func subscribe(topic: String) -> AnyPublisher<MessageResponse, Never> {
        reconnect()
        
        let subscribtion: Subscribtion
        
        if let existingSubscribtion = subscribtions.values.first(where: { $0.topic == topic }) {
            subscribtion = Subscribtion(existingSubscribtion,
                                        subscribersCount: existingSubscribtion.subscribersCount + 1)
        } else {
            let requestId = getNextRequestId()
            subscribtion = Subscribtion(id: requestId, topic: topic)
            if (status == .connected) {
                ws.send(data: encoder.encodeSubscribe(requestId: requestId, topic: topic))
            }
        }
        
        subscribtions[subscribtion.id] = subscribtion
        
        return subscribtion.subject.handleEvents(receiveCancel: { [weak self] in
            if let canceledSubscribtion = self?.subscribtions[subscribtion.id] {
                if canceledSubscribtion.subscribersCount <= 1 {
                    self?.removeSubscribtion(at: subscribtion.id)
                } else {
                    self?.subscribtions[canceledSubscribtion.id] = Subscribtion(canceledSubscribtion,
                                                                               subscribersCount: canceledSubscribtion.subscribersCount - 1)
                }
            }

        }).eraseToAnyPublisher()
    }
}
