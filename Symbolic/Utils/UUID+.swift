//
//  UUID+.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/21.
//

import Foundation

extension UUID: Identifiable {
    public var id: UUID { self }
}
