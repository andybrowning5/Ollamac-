//
//  OllamaModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 03/11/23.
//

import Foundation
import SwiftData

@Model
final class OllamaModel: Identifiable {
    @Attribute(.unique) var name: String
    @Attribute var isAPI: Bool = false
    @Attribute var apiKey: String = ""
    @Attribute var apiURL: String = ""
    @Attribute var modelVersion: String = ""
    
    var isAvailable: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \Chat.model)
    var chats: [Chat] = []
    
    init(name: String, isAPI: Bool, apiKey: String, apiURL: String, modelVersion: String) {
        self.name = name
        self.isAPI = isAPI
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.modelVersion = modelVersion
        
        if(isAPI){
            isAvailable = true
        }
    }
    
    @Transient var isNotAvailable: Bool {
        isAvailable == false
    }
}
