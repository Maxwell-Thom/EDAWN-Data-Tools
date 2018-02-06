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

   @IBOutlet weak var newContacts: NSTextField!
   @IBOutlet weak var updatedContacts: NSTextField!
   @IBOutlet weak var failedContacts: NSTextField!

   var new: Int? {
      didSet {
         guard let new = new else {return}
         if new > 0 {
            newContacts.isHidden = false
            newContacts.stringValue = "New Contacts: \(new)"
         } else {
            newContacts.isHidden = true
            newContacts.stringValue = "New Contacts: \(new)"
         }
      }
   }

   var updated: Int? {
      didSet {
         guard let updated = updated else {return}
         if updated > 0 {
            updatedContacts.isHidden = false
            updatedContacts.stringValue = "Updated Contacts: \(updated)"
         } else {
            updatedContacts.isHidden = true
            updatedContacts.stringValue = "Updated Contacts: \(updated)"
         }
      }
   }

   var failed: Int? {
      didSet {
         guard let failed = failed else {return}
         if failed > 0 {
            failedContacts.isHidden = false
            failedContacts.stringValue = "Failed Contacts: \(failed)"
         } else {
            failedContacts.isHidden = true
            failedContacts.stringValue = "Failed Contacts: \(failed)"
         }
      }
   }

   @IBAction func runRequest(_ sender: Any) {
      self.runButton.isEnabled = false
      new = 0
      updated = 0
      failed = 0
      authenticateCaspio()
   }

   override var representedObject: Any? {
      didSet {
      // Update the view, if already loaded.
      }
   }

   override func viewDidLoad() {
      super.viewDidLoad()
      new = 0
      updated = 0
      failed = 0
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
                     }

                  } else {
                     self.runButton.isEnabled = true
                     self.progressBar.doubleValue = 0
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

   func putCaspioProspects(firstName: String, lastName: String, domainKey: String, email: String, peopleUUID: String) {
      let json = ["people_uuid":"\(peopleUUID)",
         "DomainKey":"\(domainKey)",
         "first_name":"\(firstName)",
         "last_name":"\(lastName)",
         "email":"\(email)"]

      let queryString = """
      https://c5ebl095.caspio.com/rest/v1/tables/Contacts/rows?q={"where":"people_uuid='\(peopleUUID)'"}
      """.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      if let caspioAccessToken = caspioAccessToken, let queryString = queryString {
         if email == "" {
            postFailedEmailLookup(firstName: firstName, lastName: lastName, domainKey: domainKey, peopleUUID: peopleUUID)
         } else {
            Alamofire.request(queryString, method: .put, parameters: json, encoding: JSONEncoding.prettyPrinted, headers: ["Authorization": caspioAccessToken]).responseJSON { response in
               switch response.result {
                  case .success:
                     if let data = response.data {
                        let json = JSON(data: data)
                        if let rowsAffected =  json["RowsAffected"].int, rowsAffected > 0 {
                           self.progressBar.increment(by: 1.0)
                           self.requestGroup.leave()
                           if let updated = self.updated {
                              self.updated = updated+1
                           }
                        } else {
                           self.postCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domainKey, email: email, peopleUUID: peopleUUID)
                        }
                     }
                  case .failure(let error):
                     self.progressBar.increment(by: 1.0)
                     self.requestGroup.leave()
                     print(error)
                     break
                }
            }
         }
      }
   }


   func postCaspioProspects(firstName: String, lastName: String, domainKey: String, email: String, peopleUUID: String) {
      let json = ["people_uuid":"\(peopleUUID)",
                  "DomainKey":"\(domainKey)",
                  "first_name":"\(firstName)",
                  "last_name":"\(lastName)",
                  "email":"\(email)"]

      if let caspioAccessToken = caspioAccessToken {
         if email == "" {
            self.postFailedEmailLookup(firstName: firstName, lastName: lastName, domainKey: domainKey, peopleUUID: peopleUUID)
         } else {
             Alamofire.request("https://c5ebl095.caspio.com/rest/v1/tables/Contacts/rows", method: .post, parameters: json, encoding: JSONEncoding.default, headers: ["Authorization": caspioAccessToken]).response { response in
               self.progressBar.increment(by: 1.0)
               self.requestGroup.leave()
               if let new = self.new {
                  self.new = new+1
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
                  self.putCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: email, peopleUUID: peopleUUID)
               }
            }
         case .failure(let error):
            print(error)
            self.requestGroup.leave()
         }
      }
   }

   func fetchHunterEmail(domain: String, firstName: String, lastName: String, peopleUUID: String) {
      guard let encodedFirstName = firstName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let encodedLastName = lastName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
         self.requestGroup.leave()
         return
      }
      Alamofire.request("https://api.hunter.io/v2/email-finder?domain=/\(domain)&first_name=\(encodedFirstName)&last_name=\(encodedLastName)&api_key=\(Constants.hunterSecretKey)").responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               let email = json["data"]["email"].stringValue
               if email == "" {
                  self.postFailedEmailLookup(firstName: firstName, lastName: lastName, domainKey: domain, peopleUUID: peopleUUID)
               } else {
                  self.putCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: email, peopleUUID: peopleUUID)
               }
            }
         case .failure(let error):
            self.putCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: "", peopleUUID: peopleUUID)
            print(error)
         }
      }
   }

   func postFailedEmailLookup (firstName: String, lastName: String, domainKey: String, peopleUUID: String) {
      let json = ["people_uuid":"\(peopleUUID)",
                  "domain":"\(domainKey)",
                  "first_name":"\(firstName)",
                  "last_name":"\(lastName)"]

      if let caspioAccessToken = caspioAccessToken {
         Alamofire.request("https://c5ebl095.caspio.com/rest/v1/tables/FailedEmailLookup/rows", method: .post, parameters: json, encoding: JSONEncoding.default, headers: ["Authorization": caspioAccessToken]).response { response in
            self.progressBar.increment(by: 1.0)
            self.requestGroup.leave()
            if let failed = self.failed {
               self.failed = failed+1
            }
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
