//
//  AnchoredObjectQueryStreamHandler.swift
//  health_kit_reporter
//
//  Created by Victor Kachalov on 09.12.20.
//

import Foundation
import HealthKitReporter
import HealthKit

public final class AnchoredObjectQueryStreamHandler: NSObject {
    public let reporter: HealthKitReporter
    public var activeQueries = Set<Query>()
    public var plannedQueries = Set<Query>()

    init(reporter: HealthKitReporter) {
        self.reporter = reporter
    }

    // MARK: - Anchor Encoding/Decoding

    private func encodeQueryAnchor(from anchor: HKQueryAnchor?) -> String? {
        guard let anchor = anchor else {
            return nil
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            return data.base64EncodedString()
        } catch {
            return nil
        }
    }

    private func decodeQueryAnchor(from base64String: String?) -> HKQueryAnchor? {
        guard let base64String = base64String, !base64String.isEmpty else {
            return nil
        }
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - StreamHandlerProtocol
extension AnchoredObjectQueryStreamHandler: StreamHandlerProtocol {
    public func setQueries(arguments: [String: Any], events: @escaping FlutterEventSink) throws {
        guard
            let identifiers = arguments["identifiers"] as? [String],
            let startTimestamp = arguments["startTimestamp"] as? Double,
            let endTimestamp = arguments["endTimestamp"] as? Double
        else {
            return
        }

        // Get optional anchor from arguments
        let anchorString = arguments["anchor"] as? String
        let queryAnchor = decodeQueryAnchor(from: anchorString)

        let predicate = NSPredicate.samplesPredicate(
            startDate: Date.make(from: startTimestamp),
            endDate: Date.make(from: endTimestamp)
        )
        for identifier in identifiers {
            guard let type = identifier.objectType as? SampleType else {
                return
            }
            let query = try reporter.reader.anchoredObjectQuery(
                type: type,
                predicate: predicate,
                anchor: queryAnchor,
                monitorUpdates: true
            ) { (query, samples, deletedObjects, anchor, error) in
                guard error == nil else {
                    return
                }
                var jsonDictionary: [String: Any] = [:]
                var samplesArray: [String] = []
                for sample in samples {
                    do {
                        let encoded = try sample.encoded()
                        samplesArray.append(encoded)
                    } catch {
                        continue
                    }
                }
                var deletedObjectsArray: [String] = []
                for deletedObject in deletedObjects {
                    do {
                        let encoded = try deletedObject.encoded()
                        deletedObjectsArray.append(encoded)
                    } catch {
                        continue
                    }
                }
                jsonDictionary["samples"] = samplesArray
                jsonDictionary["deletedObjects"] = deletedObjectsArray
                jsonDictionary["anchor"] = self.encodeQueryAnchor(from: anchor)

                // Dispatch to main thread for Flutter event sink
                DispatchQueue.main.async {
                    events(jsonDictionary)
                }
            }
            plannedQueries.insert(query)
        }
    }

    public static func make(with reporter: HealthKitReporter) -> AnchoredObjectQueryStreamHandler {
        AnchoredObjectQueryStreamHandler(reporter: reporter)
    }
}

// MARK: - FlutterStreamHandler
extension AnchoredObjectQueryStreamHandler: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        handleOnListen(withArguments: arguments, eventSink: events)
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        handleOnCancel(withArguments: arguments)
    }
}
