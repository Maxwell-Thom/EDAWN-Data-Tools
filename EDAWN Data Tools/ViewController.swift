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
                        self.runButton.title = "Run Next Page"
                     } else {
                        self.runButton.title = "Complete"
                     }

                     for i in 0...json["Result"].count-1 {
                        self.fetchProspectEmail(domain: json["Result"][i]["Crunchbase_Bombora_Sum_Domain"].stringValue, firstName: json["Result"][i]["people_first_name"].stringValue, lastName: json["Result"][i]["people_last_name"].stringValue, peopleUUID: json["Result"][i]["people_uuid"].stringValue)
                     }
                  } else {
                     self.runButton.isEnabled = true
                     self.runButton.title = "Run"
                     self.errorLabel.isHidden = false
                     self.errorLabel.stringValue = "Something went wrong when trying to get Input View!"
                  }

                  self.progressBar.maxValue = Double(json["Result"].count)
                  self.progressBar.controlSize = NSControl.ControlSize(rawValue: UInt(json["Result"].count))!
                  self.progressBar.doubleValue = 0
               }
            case .failure(let error):
               self.runButton.isEnabled = true
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

      if let caspioAccessToken = caspioAccessToken{
          Alamofire.request("https://c5ebl095.caspio.com/rest/v1/tables/\(outputTable.stringValue)/rows", method: .post, parameters: json, encoding: JSONEncoding.default, headers: ["Authorization": caspioAccessToken]).response { response in

            self.progressBar.increment(by: 1.0)
            if response.response?.statusCode != 201 {
               self.errorLabel.isHidden = false
               self.errorLabel.stringValue = "Posting results failed with error code: \(String(response.response!.statusCode)), check Output Table Name"
            }

            if self.progressBar.doubleValue >= Double(Constants.caspioPageSize) && self.runButton.title != "Complete" {
               self.runButton.isEnabled = true
            }
         }
      }
   }

   func fetchProspectEmail(domain: String, firstName: String, lastName: String, peopleUUID: String){
      let parameters: Parameters = ["domain" : domain, "first_name" :firstName, "last_name" : lastName]
      Alamofire.request("https://prospect.io/api/public/v1/emails/search?", parameters: parameters, headers: ["Authorization": Constants.prospectSecretKey]).responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               let email = json["data"][0]["attributes"]["value"].stringValue
               self.postCaspioProspects(firstName: firstName, lastName: lastName, domainKey: domain, email: email, peopleUUID: peopleUUID)
            }
         case .failure(let error):
            print(error)
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

