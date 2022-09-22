//
//  Splash.swift
//  BevBits
//
//  Created by Shayne Guiliano on 1/1/18.
//  Copyright © 2018 CHAICore. All rights reserved.
//

import UIKit

class Splash: UIViewController {

    @IBOutlet weak var pid:UITextField!
    @IBOutlet weak var studyId:UITextField!
    @IBOutlet weak var studyNote:UITextField!
    @IBOutlet weak var visitID:UITextField!
    @IBOutlet weak var setSwitch:UISegmentedControl!
    @IBOutlet weak var selectedSetPreview:UIImageView!
    @IBOutlet weak var helpText:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changedSet() {
        selectedSetPreview.image = UIImage(named:"\(setSwitch.selectedSegmentIndex)right")
    }
    
    var numberRemember = ""
    @IBAction func numberCheck() {
        
        if let _ = Int(visitID.text!) {
            numberRemember = visitID.text!
        } else {
            if (visitID.text != "") {
                visitID.text = numberRemember
            }
        }
    }
    
    @IBAction func Go() {
        
        if (pid.text == ""
            || studyId.text == ""
            || visitID.text == "") {
            helpText.isHidden = false
        } else {
            helpText.isHidden = true
            
            Tuning.pid = pid.text!
            Tuning.studyId = studyId.text!
            Tuning.studyNote = studyNote.text == "" ? "na" : studyNote.text!
            Tuning.stimulusId = setSwitch.selectedSegmentIndex
            Tuning.visitId = Int(visitID.text!)!
            
            performSegue(withIdentifier: "go", sender: self)
        }
        
        pid.resignFirstResponder()
        studyId.resignFirstResponder()
        studyNote.resignFirstResponder()
        visitID.resignFirstResponder()
    }
}
