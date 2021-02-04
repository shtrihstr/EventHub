import Foundation

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
