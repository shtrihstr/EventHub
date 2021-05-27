# Swift EventHub Client
iOS client-side library for [EventHub](https://github.com/olesku/eventhub) written in Swift.

## Features
 - Keeps connection only if an active subscription exists
 - Automatic reconnect and resubscribe
 - Concurrent subscriptions to one topic

## Usage

```swift
import EventHub
import Combine

let client = EventHub(url: URL(string: "ws://myeventhubserver.com")!, token: "myAuthToken")

let cancellable = client.subscribe(topic: "foo/bar")
   .receive(on: RunLoop.main)
   .sink(receiveValue: { response in
      print(response.message)
   })
```

## Requirements

iOS 13+

## Installation
### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 
Once you have your Swift package set up, adding EventHub as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/shtrihstr/EventHub.git", .upToNextMajor(from: "0.1.0"))
]
```
