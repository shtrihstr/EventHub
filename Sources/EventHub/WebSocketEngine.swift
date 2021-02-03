import Foundation

class WebSocketEngine : NSObject {
    private var task: URLSessionWebSocketTask?
    private let url: URL
    
    var onReceive: ((Data) -> Void) = { _ in }
    var onConnect: (() -> Void) = {}
    var onConnectionError: (() -> Void) = {}
    
    init(url: URL) {
        self.url = url
    }
    
    func reconnect() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        task = session.webSocketTask(with: request)
        task?.resume()
        receive()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: .none)
        task = nil
    }
    
    func send(data: Data) {
        task?.send(.string(String(data: data, encoding: .utf8)!), completionHandler: { _ in })
    }

    private func receive() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self?.onReceive(data)
                    }
                case .data(let data):
                    self?.onReceive(data)
                }

                self?.receive()
            case .failure(let error):
                print("Error when receiving \(error)")
            }
        }
    }

}

extension WebSocketEngine: URLSessionWebSocketDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        if task != nil {
            onConnect()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            onConnectionError()
        }
    }
}
