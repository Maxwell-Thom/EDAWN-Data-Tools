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
   @IBOutlet weak var inputFileNameField: NSTextField!
   @IBOutlet weak var outputFileNameField: NSTextField!

   var titles = ["coo", "ceo", "founder", "cfo"]

   override func viewDidLoad() {
      super.viewDidLoad()

      // Do any additional setup after loading the view.


   }

   override var representedObject: Any? {
      didSet {
      // Update the view, if already loaded.
      }
   }

   @IBAction func inputBrowse(_ sender: Any) {
      browseFile(textField: inputFileNameField, isOutput: false)
   }

   @IBAction func outputBrowse(_ sender: Any) {
      browseFile(textField: outputFileNameField, isOutput: true)
   }

   @IBAction func submit(_ sender: Any) {

      if inputFileNameField.stringValue == "" {
         print("input path unspecified")
         return
      }

      if outputFileNameField.stringValue == "" {
         print("output path unspecified")
         return
      }

      let writePath = outputFileNameField.stringValue + "/test" + ".csv"

      guard let inputStream = InputStream(fileAtPath: inputFileNameField.stringValue) else {
         print("input file path was bad")
         return
      }

      guard let inputCSV = try? CSVReader(stream: inputStream, hasHeaderRow: true) else {
         print("could not intialize csv reader")
         return
      }

      guard let outputStream = OutputStream(toFileAtPath: writePath, append: false) else {
         print("output folder path was bad")
         return
      }

      guard let outputCSV = try? CSVWriter(stream: outputStream) else {
         print("could not intialize csv writer")
         return
      }

      guard let headerRows = inputCSV.headerRow else {
         print("CSV has an invalid header")
         return
      }

      while inputCSV.next() != nil {
         try? outputCSV.write(row: inputCSV.currentRow!)
      }
      outputCSV.stream.close()
      requestOrganization(domain: "facebook.com")
   }

   func browseFile(textField: NSTextField, isOutput: Bool) {
      let dialog = NSOpenPanel()
      dialog.title                   = "Choose a .csv file"
      dialog.showsResizeIndicator    = true
      dialog.showsHiddenFiles        = false
      dialog.canChooseDirectories    = isOutput
      dialog.canChooseFiles          = !isOutput
      dialog.canCreateDirectories    = isOutput
      dialog.allowsMultipleSelection = false
      dialog.allowedFileTypes        = ["csv"]

      if (dialog.runModal() == NSApplication.ModalResponse.OK) {
         let result = dialog.url // Pathname of the file

         if let result = result {
            let path = result.path
            textField.stringValue = path
         }
      } else {
         // User clicked on "Cancel"
         return
      }
   }

   func requestOrganization(domain: String) {
      Alamofire.request("https://api.crunchbase.com/v3.1/odm-organizations?domain_name=\(domain)&user_key=a03227a012cd7b8a686f58745bd98a0d").responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               if let name = json["data"]["items"][0]["properties"]["name"].string {
                  self.requestPeople(companyName: name)
               }
            }
         case .failure(let error):
            print(error)
         }
      }
   }

   func requestPeople(companyName: String) {
      var chiefs = [String:String]()
      Alamofire.request("https://api.crunchbase.com/v3.1/odm-people?query=\(companyName)&user_key=a03227a012cd7b8a686f58745bd98a0d").responseJSON { response in
         switch response.result {
         case .success:
            if let data = response.data {
               let json = JSON(data: data)
               for item in json["data"]["items"] {
                  for title in self.titles {
                     if item.1["properties"]["title"].string?.lowercased().range(of:title) != nil {
                        if item.1["properties"]["organization_name"].string?.description == companyName.description {
                           if let first = item.1["properties"]["first_name"].string, let last = item.1["properties"]["last_name"].string {
                              chiefs["\(first) \(last)"] = "\(item.1["properties"]["title"])"
                           }
                        }
                     }
                  }
               }
            }
         case .failure(let error):
            //return "\(domain): \(error.localizedDescription)"
            print(error)
         }
         print(chiefs)
      }
   }
}

