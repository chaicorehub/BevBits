//
//  ExportController.swift
//  BevBits
//
//  Created by Shayne Guiliano on 2/1/18.
//  Copyright © 2018 CHAICore. All rights reserved.
//

import UIKit
import MessageUI
import Messages

class ExportController: UITableViewController, MFMailComposeViewControllerDelegate {

    var filesList:[String] = []
    var namesList:[String] = []
    
    @IBAction func export() {
        sendEmail()
    }
    
    weak var mailController:MFMailComposeViewController?;
    
    @IBAction func done() {
        self.navigationController?.dismiss(animated: true) {
            
        }
        
        mailController = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        filesList = getFilesList()
        filesList.sort()
        filesList.reverse()
        
        var cleanList:[String] = []
        for url in filesList {
            var result = url.components(separatedBy: "/")
            cleanList.append(result[result.count-1])
        }
        
        cleanList.sort()
        cleanList.reverse()
        namesList = cleanList
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }
    
    func getFilesList() -> [String] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            var stringList:[String] = []
 
            for url in fileURLs {
                stringList.append(url.absoluteString)
            }
            
            return stringList
        } catch {
            //print("Error while enumerating files \(destinationFolder.path): \(error.localizedDescription)")
        }
        
        let dummy = [""]
        return dummy
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return namesList.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "export", for: indexPath) as! ExportCell

        let selectedIndexPaths = tableView.indexPathsForSelectedRows
        let rowIsSelected = selectedIndexPaths != nil && selectedIndexPaths!.contains(indexPath)
        cell.accessoryType = rowIsSelected ? .checkmark : .none
        
        cell.fileName.text = namesList[indexPath.row]
        
        // Configure the cell...

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        cell.accessoryType = .checkmark
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        cell.accessoryType = .none
    }
    
    func cleanNameFromPath(path:String)->String {
        var result = path.components(separatedBy: "/")
        return result[result.count-1]
    }

    func sendEmail() {
        
        //Check to see the device can send email.
        if let selected = tableView.indexPathsForSelectedRows {
            if( MFMailComposeViewController.canSendMail() && selected.count > 0) {
                let mailComposer = MFMailComposeViewController()
                mailComposer.mailComposeDelegate = self
                
                mailController = mailComposer
                
                //Set the subject and message of the email
                mailComposer.setSubject("Export from BevBits")
                
                var messageBody = "Export from BevBits includes:\n"
                
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows {
                    for indexpath in selectedIndexPaths {
                        let filepath = filesList[indexpath.row]
                        
                        messageBody = messageBody + cleanNameFromPath(path: filepath) + "\n"
                        let file = filepath.replacingOccurrences(of: "file://", with: "")
                        
                        do {
                            _ = try NSData(contentsOfFile: filepath.replacingOccurrences(of: "file://", with: ""), options: .uncached)
                        } catch {
                            print(error)
                        }
                        if let fileData = NSData(contentsOfFile: filepath.replacingOccurrences(of: "file://", with: "")) {
                            // println("File data loaded.")
                            mailComposer.addAttachmentData(fileData as Data, mimeType: "text/csv", fileName: filepath)
                        }
                    }
                }
                
                mailComposer.setMessageBody(messageBody, isHTML: false)
                let nav = self.navigationController
                self.navigationController?.present(mailComposer, animated: true, completion: nil)
            }
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.navigationController?.dismiss(animated: true) {
        
        }
        
        mailController = nil
    }

}
