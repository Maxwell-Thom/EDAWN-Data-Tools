//
//  ViewController.swift
//  EDAWN Data Tools
//
//  Created by maxwell thom on 10/29/17.
//  Copyright © 2017 maxwell thom. All rights reserved.
//

import Cocoa
import CSV
import SwiftyJSON
import Alamofire

class ViewController: NSViewController {

   var caspioAccessToken: String?
   var caspioPage = 1
   let requestGroup =  DispatchGroup()

   @IBOutlet weak var progressBar: NSProgressIndicator!
   @IBOutlet weak var runButton: NSButton!
   @IBOutlet weak var inputView: NSTextField!
   @IBOutlet weak var outputTable: NSTextField!
   @IBOutlet weak var errorLabel: NSTextField!
   @IBOutlet weak var inputValidationColor: NSColorWell!
   @IBOutlet weak var outputValidationColor: NSColorWell!

   @IBAction func runRequest(_ sender: Any) {
      self.runButton.isEnabled = false
      errorLabel.isHidden = true
      errorLabel.stringValue = ""
      authenticateCaspio()
   }

   override var representedObject: Any? {
      didSet {
      // Update the view, if already loaded.
      }
   }

   override func viewDidLoad() {
      super.viewDidLoad()
   }

   func authenticateCaspio() {
      Alamofire.request( "https://c5ebl095.caspio.com/oauth/token", method: .post, parameters: [:], encoding: Constants.caspioAuthenticationBody, headers: [:]).responseJSON { response in
            switch response.result {
            case .success:
               if let data = response.data {
                  let json = JSON(data: data)
                  self.caspioAccessToken = "\(json["token_type"]) \(json["access_token"])"
                  self.fetchCaspioProspects()
               }
            case .failure(let error):
               self.runButton.isEnabled = true
               self.progressBar.doubleValue = 0
               print(error)
            }
         }
   }

   func fetchCaspioProspects(){
      if let caspioAccessToken = caspioAccessToken {
         let parameters: Parameters = ["q" : "{pageNumber:\(caspioPage), pageSize:\(Constants.caspioPageSize)}"]
         Alamofire.request("https://c5ebl095.caspio.com/rest/v1/views/\(inputView.stringValue)/rows", parameters: parameters, headers: ["Authorization": caspioAccessToken]).responseJSON { response in
            switch response.result {
            case .success:
               if let data = response.data {
                  let json = JSON(data: data)
                  print(json["Result"].count)

                  if json["Result"].count > 0 {
                     if json["Result"].count >= Constants.caspioPageSize {
                        self.caspioPage = self.caspioPage+1
                     }

                     for i in 0...json["Result"].count-1 {
                        self.requestGroup.enter()
                        self.fetchProspectEmail(domain: json["Result"][i]["Crunchbase_Bombora_Sum_Domain"].stringValue, firstName: json["Result"][i]["people_first_name"].stringValue, lastName: json["Result"][i]["people_last_name"].stringValue, peopleUUID: json["Result"][i]["people_uuid"].stringValue)
                     }

                     //REQUEST GROUP NOTIFICATION (This only gets executed once all the above are done)
                     if json["Result"].count == Constants.caspioPageSize {
                        self.requestGroup.notify(queue: DispatchQueue.main, execute: {
                           self.fetchCaspioProspects()
                           print("Current Page: \(self.caspioPage)")
                        })
                     } else {
                        self.runButton.isEnabled = true
                        self.progressBar.doubleValue = 0
                        self.errorLabel.isHidden = false
                     }

                  } else {
                     self.runButton.isEnabled = true
                     self.progressBar.doubleValue = 0
                     self.errorLabel.isHidden = false
                     self.errorLabel.stringValue = "Something went wrong when trying to get Input View!"
                  }

                  // PROGRESS BAR
                  self.progressBar.maxValue = Double(json["Result"].count)
                  self.progressBar.controlSize = NSControl.ControlSize(rawValue: UInt(json["Result"].count))!
                  self.progressBar.doubleValue = 0
               }
            case .failure(let error):
               self.runButton.isEnabled = true
               self.progressBar.doubleValue = 0
               print(error)
            }
         }
      }
   }

   func postCaspioProspects(firstName: String, lastName: String, domainKey: String, email: String, peopleUUID: String) {
      let json = ["People_UUID":"\(peopleUUID)",
                  "DomainKey":"\(domainKey)",
                  "First_name":"\(firstName)",
                  "Last_name":"\(lastName)",
                  "Email":"\(email)"]

      if let caspioAccessToken = caspioAccessToken {
         if email == "" {
            self.postFailedEmailLookup(firstName: firstName, lastName: lastName, domainKey: domainKey, peopleUUID: peopleUUID)
         } else {
             Alamofire.request("https://c5ebl095.caspio.com/rest/v1/tables/\(outputTable.stringValue)/rows", method: .post, parameters: json, encoding: JSONEncoding.default, headers: ["Authorization": caspioAccessToken]).response { response in
               self.progressBar.increment(by: 1.0)
               self.requestGroup.leave()
               if response.response?.statusCode != 201 {
                  self.errorLabel.isHidden = false
               }
            }
         }
      }
   }

   func fetchProspectEmail(domain: String, firstName: String, lastName: String, peopleUUID: String) {
      let parameters: Parameters = ["domain" : domain, "first_name" :firstName, "last_name" : lastName]
      Alamofire.request("https://prospect.io/api/public/v1/emails/search?", parameters: parameters, headers: ["Authorization": Constants.prospectSecretKey]).responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               let email = json["data"][0]["attributes"]["value"].stringValue
               if email == "" {
                  self.fetchHunterEmail(domain: domain, firstName: firstName, lastName: lastName, peopleUUID: peopleUUID)
               } else {
                  self.postCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: email, peopleUUID: peopleUUID)
               }
            }
         case .failure(let error):
            print(error)
            self.errorLabel.stringValue = "\(error)"
            self.requestGroup.leave()
         }
      }
   }

   func fetchHunterEmail(domain: String, firstName: String, lastName: String, peopleUUID: String) {
      Alamofire.request("https://api.hunter.io/v2/email-finder?domain=/\(domain)&first_name=\(firstName)&last_name=\(lastName)&api_key=\(Constants.hunterSecretKey)").responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               let email = json["data"]["email"].stringValue
               if email == "" {
                  self.postFailedEmailLookup(firstName: firstName, lastName: lastName, domainKey: domain, peopleUUID: peopleUUID)
               } else {
                  self.postCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: email, peopleUUID: peopleUUID)
               }
            }
         case .failure(let error):
            self.postCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: "", peopleUUID: peopleUUID)
            self.errorLabel.stringValue = "\(error)"
         }
      }
   }

   func postFailedEmailLookup (firstName: String, lastName: String, domainKey: String, peopleUUID: String) {
      let json = ["Person_UUID":"\(peopleUUID)",
                  "Domain":"\(domainKey)",
                  "Firstname":"\(firstName)",
                  "Lastname":"\(lastName)"]

      if let caspioAccessToken = caspioAccessToken {
         Alamofire.request("https://c5ebl095.caspio.com/rest/v1/tables/FailedEmailLookup/rows", method: .post, parameters: json, encoding: JSONEncoding.default, headers: ["Authorization": caspioAccessToken]).response { response in
            self.progressBar.increment(by: 1.0)
            self.requestGroup.leave()
         }
      }
   }
}

extension String: ParameterEncoding {
   public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
      var request = try urlRequest.asURLRequest()
      request.httpBody = data(using: .utf8, allowLossyConversion: false)
      return request
   }
}

