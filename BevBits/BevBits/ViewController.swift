//
//  ViewController.swift
//  Juice
//
//  Created by Shayne Guiliano on 12/5/17.
//  Copyright © 2017 Shayne Guiliano. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var leftImage:UIImageView!
    @IBOutlet weak var rightImage:UIImageView!
    
    @IBAction func back() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        leftImage.image = Tuning.getLeftImage()
        rightImage.image = Tuning.getRightImage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

