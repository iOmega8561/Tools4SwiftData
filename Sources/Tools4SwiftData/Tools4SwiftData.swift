//
//  Tools4SwiftData.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import Foundation

public enum Tools4SwiftData: LocalizedError {
    
    case internalError
    
    public var errorDescription: String? {
        
        switch self {
        case .internalError:
            return String(localized: "error-swiftdata")
        }
    }
}
