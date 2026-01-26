//
//  WeightUnit.swift
//  Callout
//
//  Voice-first workout logging
//

import Foundation

/// Weight unit preference for the user
enum WeightUnit: String, Codable, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
    
    var displayName: String {
        switch self {
        case .kg: return "Kilograms"
        case .lbs: return "Pounds"
        }
    }
    
    var shortName: String {
        rawValue
    }
    
    /// Common plate weights for this unit system
    var standardPlates: [Double] {
        switch self {
        case .kg: return [1.25, 2.5, 5, 10, 15, 20, 25]
        case .lbs: return [2.5, 5, 10, 25, 35, 45]
        }
    }
    
    /// Standard barbell weight
    var barbellWeight: Double {
        switch self {
        case .kg: return 20
        case .lbs: return 45
        }
    }
    
    /// Convert a weight to the other unit
    func convert(_ weight: Double, to target: WeightUnit) -> Double {
        if self == target { return weight }
        switch (self, target) {
        case (.kg, .lbs): return weight * 2.20462
        case (.lbs, .kg): return weight / 2.20462
        default: return weight
        }
    }
}
