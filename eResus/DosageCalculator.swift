//
//  DosageCalculator.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation

enum PatientAgeCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case adult = "≥12 years / Adult"
    case elevenYears = "11 years"
    case tenYears = "10 years"
    case nineYears = "9 years"
    case eightYears = "8 years"
    case sevenYears = "7 years"
    case sixYears = "6 years"
    case fiveYears = "5 years"
    case fourYears = "4 years"
    case threeYears = "3 years"
    case twoYears = "2 years"
    case eighteenMonths = "18 months"
    case twelveMonths = "12 months"
    case nineMonths = "9 months"
    case sixMonths = "6 months"
    case threeMonths = "3 months"
    case oneMonth = "1 month"
    case postBirthToOneMonth = "Post-birth to 1 month"
    case atBirth = "At birth"
    
    var id: String { self.rawValue }
}

struct DosageCalculator {
    
    static func calculateAdrenalineDose(for age: PatientAgeCategory) -> String {
        switch age {
        case .adult: return "1mg"
        case .elevenYears: return "350mcg"
        case .tenYears: return "320mcg"
        case .nineYears: return "300mcg"
        case .eightYears: return "260mcg"
        case .sevenYears: return "230mcg"
        case .sixYears: return "210mcg"
        case .fiveYears: return "190mcg"
        case .fourYears: return "160mcg"
        case .threeYears: return "140mcg"
        case .twoYears: return "120mcg"
        case .eighteenMonths: return "110mcg"
        case .twelveMonths: return "100mcg"
        case .nineMonths: return "90mcg"
        case .sixMonths: return "80mcg"
        case .threeMonths: return "60mcg"
        case .oneMonth: return "50mcg"
        case .postBirthToOneMonth: return "50mcg"
        case .atBirth: return "70mcg"
        }
    }
    
    static func calculateAmiodaroneDose(for age: PatientAgeCategory, doseNumber: Int) -> String? {
        // doseNumber 1 is initial dose, 2 is repeat dose
        switch age {
        case .adult:
            return doseNumber == 1 ? "300mg" : "150mg"
        case .elevenYears:
            return doseNumber == 1 ? "180mg" : "180mg"
        case .tenYears:
            return doseNumber == 1 ? "160mg" : "160mg"
        case .nineYears:
            return doseNumber == 1 ? "150mg" : "150mg"
        case .eightYears:
            return doseNumber == 1 ? "130mg" : "130mg"
        case .sevenYears:
            return doseNumber == 1 ? "120mg" : "120mg"
        case .sixYears:
            return doseNumber == 1 ? "100mg" : "100mg"
        case .fiveYears:
            return doseNumber == 1 ? "100mg" : "100mg"
        case .fourYears:
            return doseNumber == 1 ? "80mg" : "80mg"
        case .threeYears:
            return doseNumber == 1 ? "70mg" : "60mg"
        case .twoYears:
            return doseNumber == 1 ? "60mg" : "60mg"
        case .eighteenMonths:
            return doseNumber == 1 ? "55mg" : "55mg"
        case .twelveMonths:
            return doseNumber == 1 ? "50mg" : "50mg"
        case .nineMonths:
            return doseNumber == 1 ? "45mg" : "45mg"
        case .sixMonths:
            return doseNumber == 1 ? "40mg" : "40mg"
        case .threeMonths:
            return doseNumber == 1 ? "30mg" : "30mg"
        case .oneMonth:
            return doseNumber == 1 ? "25mg" : "25mg"
        case .postBirthToOneMonth, .atBirth:
            return nil // N/A
        }
    }
}
