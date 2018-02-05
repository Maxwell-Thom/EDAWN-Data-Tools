//
//  Constants.swift
//  EDAWN Data Tools
//
//  Created by maxwell thom on 1/11/18.
//  Copyright © 2018 maxwell thom. All rights reserved.
//

import Foundation

public struct Constants {
   static let caspioClientID = "c0c311c790a2416569dd581bb15c65621357d41118ed3e2deb"
   static let caspioClientSecret = "db740a06f62e4e048011a448933312ccab03a49ad83f379edb"
   static let caspioGrantType = "client_credentials"
   static let caspioPageSize = 100
   static let caspioAuthenticationBody = "grant_type=\(Constants.caspioGrantType)&client_id=\(Constants.caspioClientID)&client_secret=\(Constants.caspioClientSecret)"
   static let prospectSecretKey = "5d_yyMqoJNVTy-Xx2LYG"
   static let hunterSecretKey = "3bd0686bea18d2c0717ff7afcd5d0fa711de2d3c"
}
