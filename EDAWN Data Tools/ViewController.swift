//
//  ViewController.swift
//  EDAWN Data Tools
//
//  Created by maxwell thom on 10/29/17.
//  Copyright © 2017 maxwell thom. All rights reserved.
//

import Cocoa
import CSV

class ViewController: NSViewController {
   @IBOutlet weak var inputFileNameField: NSTextField!
   @IBOutlet weak var outputFileNameField: NSTextField!

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

   }

   func browseFile(textField: NSTextField, isOutput: Bool) {
      let dialog = NSOpenPanel()
      dialog.title                   = "Choose a .txt file"
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
}
