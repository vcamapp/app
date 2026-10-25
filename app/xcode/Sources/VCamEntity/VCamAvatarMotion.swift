//
//  VCamAvatarMotion.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/01.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum VCamAvatarMotion: String, CaseIterable, Codable, Sendable {
    case hi, bye, jump, cheer, what, pose, nod, no, shudder, run
}
