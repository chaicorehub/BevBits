//
//  MainLoop.swift
//  Juice
//
//  Created by Shayne Guiliano on 12/6/17.
//  Copyright © 2017 Shayne Guiliano. All rights reserved.
//

import UIKit

// NTD - move these variables to a static class tuning file
struct Tuning {
    // NTD - Why only 63?
    static let stopCount = 44
    static let goCount = 20
    static let debug = false
    
    static var stimulusId = 0
    static var pid:String = ""
    static var studyId:String = ""
    static var studyNote:String = ""
    static var visitId:Int = -1
    
    static func setSetId(value:Int) {
        stimulusId = value
    }
    
    static func getLeftImage()->UIImage! {
        return UIImage(named:"\(stimulusId)left")
    }
    
    static func getRightImage()->UIImage! {
        return UIImage(named:"\(stimulusId)right")
    }
}

// State machine for handling a round of interaction
enum nextState:Int {
    case LEADIN = 0
    case SYMBOL = 1
    case CHECKSYMBOL = 2
    case STOPPING = 3
    case FAILED = 4
    case SUCCEEDED
    case STEPFORWARD
    case INTERRUPTED
    case STOPPING_SUCCEEDED
    case DEBUGGING
    case ROUND_PENDING
}

// Possible states for the sim to enter each round
enum PendingState : Int {
    case left=0,right,leftStop,rightStop
    
    func getLeftRightStateIndex()->Int {
        if (self == .left || self == .leftStop )
        {
            return 0
        }
        else
        {
            return 1
        }
    }
}

// DEBUG and tracking data
struct StateChange : Codable {
    let time:CFTimeInterval
    let name:String
    
    init(_ time:CFTimeInterval,_ name:String) {
        self.time = time
        self.name = name
    }
}

struct StateChanges : Codable {
    let stateChanges:[StateChange]
    let id:String
    
    init(_ id:String,_ stateChanges:[StateChange]) {
        self.stateChanges = stateChanges
        self.id = id
    }
}

class MainLoop: UIViewController {

    @IBOutlet weak var debugLabel:UILabel!
//
    @IBOutlet weak var leftImage:UIImageView!
    @IBOutlet weak var rightImage:UIImageView!
    @IBOutlet weak var noImage:UIImageView!
    @IBOutlet weak var startNextRoundView:UIView!
    @IBOutlet weak var debugStack:UIStackView!
    @IBOutlet weak var back:UIButton!
    @IBAction func backButtonPressed() {
        returnToSplash()
    }
    
    @IBOutlet weak var debugView:UIScrollView!
    
    @IBAction func pressedStartRound() {
        startNextRoundView.isHidden = true
        restartRound()
    }
    
    var fullEventSet:[PendingState] = []
    var loop:Timer?
    var frame = 0
    var startTime:CFTimeInterval = -1.0
    let fps = 100000.0
    let timePerFrame = 0.000001
    var roundIndex = 0 // 0 = practice?
    
    var times:[CFTimeInterval] = [] // debug, remove later
    
    var lastStateChangeTime:CFTimeInterval = 0.0
    
    var stateChangeLength:CFTimeInterval = 0.49999999 // 0.49999999 yield close to 5 on average
    
    var currentTime:CFTimeInterval = 0.0
    
    var step = 0
    
    var nextState:nextState = .LEADIN
    
    let timeForSymbol = 1.0
    var userTimeForStop = 0.5
    let leadinTime = 0.5
    let roundStartTime = 2.0
    
    
    var visibleAssetId = 0
    
    // NTD - Tracking
    var stateChanges:[StateChange] = [] // debug, remove later
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        leftImage.image = Tuning.getLeftImage()
        rightImage.image = Tuning.getRightImage()
        // NTD: This needs to go into the state machine!
        
        restartRound()
        
        // Start the update loop
        loop = Timer.scheduledTimer(timeInterval: 1.0/fps, target: self, selector: #selector(MainLoop.update), userInfo: nil, repeats: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MainLoop.resumeSim), name: NSNotification.Name("resume"), object: nil)
    }
    
    @objc func resumeSim() {
        if (roundIndex < 3) {
            nextState = .INTERRUPTED
            stateChangeLength = 0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        if (loop != nil) {
            loop?.invalidate()
            loop = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupRound() {
        // First, create a random set of stop/go using the ratios
        fullEventSet.removeAll()
        
        // Fill the set, 0 = stop-left, 1 = stop-right, 2 = go-left, 3 = go-right
        for index in 1 ... Tuning.goCount {
            print(index)
            // equal chance to be left/right
            if (arc4random() % 10 < 5) {
                fullEventSet.append(.left)
            } else {
                fullEventSet.append(.right)
            }
        }
        
        for i in 1 ... Tuning.stopCount {
            // Half left, half right
            if (i <= Tuning.stopCount / 2) {
                fullEventSet.append(.leftStop)
            } else {
                fullEventSet.append(.rightStop)
            }
        }
        
        fullEventSet.shuffle()
        
        // NTD - Save the state set
        //print(fullEventSet)
    }
    
    func makeEasier() {
        analytic.resultingDelayChange = -0.05
        userTimeForStop -= 0.05
        if (userTimeForStop  < 0.05) {
            analytic.resultingDelayChange = 0
            userTimeForStop = 0.05
        }
    }
    
    func makeHarder() {
        analytic.resultingDelayChange = 0.05
        userTimeForStop += 0.05
        if (userTimeForStop > 1.0) {
            analytic.resultingDelayChange = 0
            userTimeForStop = 1.0
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func saveAnalyticsSet() {
        
        let name = "\(Int(CACurrentMediaTime()))-\(Tuning.pid.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyId.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyNote.replacingOccurrences(of: " ", with: "-"))-\(Tuning.stimulusId)-\(Tuning.visitId).csv"
        
        let filename = getDocumentsDirectory().appendingPathComponent(name)
        
        do {
            let str = analyticSet.buildCSV()
            try str.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
        
        exportFiles()
    }
    
    func saveStateMachineHistory() {
        
        let name = "\(Int(CACurrentMediaTime()))-\(Tuning.pid.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyId.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyNote.replacingOccurrences(of: " ", with: "-"))-\(Tuning.stimulusId)-\(Tuning.visitId).txt"
        
        let filename = getDocumentsDirectory().appendingPathComponent(name)
        
        do {
            let jsonToSave = try JSONEncoder().encode(StateChanges(name, stateChanges))
            let str = String.init(data: jsonToSave, encoding: .utf8)
            try str!.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
        
        exportFiles()
    }
    
    func exportFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            //print(fileURLs)
            
        } catch {
            //print("Error while enumerating files \(destinationFolder.path): \(error.localizedDescription)")
        }
    }
    
    func endSession() {
        saveAnalyticsSet()
        
        let summary0 = Summary()
        summary0.process(analyticSet.analyticsRound0)
        
        let summary1 = Summary()
        summary1.process(analyticSet.analyticsRound1)
        
        let summary2 = Summary()
        summary2.process(analyticSet.analyticsRound2)
        
        let superSummary = SuperSummary()
        superSummary.summaries.append(summary0)
        superSummary.summaries.append(summary1)
        superSummary.summaries.append(summary2)
        
        saveSummary(superSummary)
        saveStateMachineHistory()
        //showDebug()
        //returnToSplash()
        
        back.isHidden = false
    }
    
    func saveSummary(_ summary:SuperSummary) {
        let name = "\(Int(CACurrentMediaTime()))-\(Tuning.pid.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyId.replacingOccurrences(of: " ", with: "-"))-\(Tuning.studyNote.replacingOccurrences(of: " ", with: "-"))-\(Tuning.stimulusId)-\(Tuning.visitId)_summary.csv"
        
        let filename = getDocumentsDirectory().appendingPathComponent(name)
        
        do {
            let str = summary.produceCSV()
            try str.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
        
        exportFiles()
    }
    
    func returnToSplash() {
        // First, let's save everything!
        
        
        self.dismiss(animated: true) {
        
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // Determine if it was correct right or left.
        if (step < fullEventSet.count) {
            for touch in touches {
                // NTD - Is this the fastest way top determine side?
                let location = touch.location(in: self.view)
                if (nextState == .ROUND_PENDING) {
                    // do nothing
                } else
                if (nextState == .SYMBOL) {
                    // Do nothing?
                    // Any other states to do nothing?
                    if (location.x > self.view.frame.size.width / 2) {
                        trackStateChange(StateChange(CACurrentMediaTime(),"Leadin Touched Down Right Side"))
                    } else {
                        trackStateChange(StateChange(CACurrentMediaTime(),"Leadin Touched Down Left Side"))
                    }
                }
                else
                if (location.x > self.view.frame.size.width / 2) {
                    // touched right!
                    // reaction time since the start of symbol
                    analytic.reactionTime = CACurrentMediaTime() - analytic.trialStartTimestamp - analytic.actualSignalDelay
                    analytic.sideTouched = 1
                    switch (fullEventSet[step]) {
                    case .right:
                        // Correct Direction!
                        nextState = .SUCCEEDED
                        stateChangeLength = 0
                        trackStateChange(StateChange(CACurrentMediaTime(),"Touch Right Correctly"))
                        makeHarder()
                        break
                    case .left:
                        // Failed Direction!
                        nextState = .FAILED
                        stateChangeLength = 0
                        makeEasier()
                        trackStateChange(StateChange(CACurrentMediaTime(),"Failed Left, Touched Right"))
                        break
                    case .leftStop:
                        if (nextState == .CHECKSYMBOL) {
                            // Success! The stop hasn't shown yet!
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed by touching Right early on Stop Left"))
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        } else {
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed to Stop Left, Touched Right"))
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        }
                        break
                    case .rightStop:
                        
                        if (nextState == .CHECKSYMBOL) {
                            // Succeeded by arriving early!
                            //trackStateChange(StateChange(CACurrentMediaTime(),"Succeeded in Stop Right, Touched Early"))
                            //nextState = .SUCCEEDED
                            //makeHarder()
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed in Stop Right, Touched Right Early"))
                            
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        } else {
                            // Failed!
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed to Stop Right, Touched Right"))
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        }
                        break
                    }
                } else {
                    analytic.sideTouched = 0
                    // touched left!
                    analytic.reactionTime = CACurrentMediaTime() - analytic.trialStartTimestamp - analytic.actualSignalDelay
                    
                    switch (fullEventSet[step]) {
                    case .left:
                        // Correct Direction!
                        nextState = .SUCCEEDED
                        stateChangeLength = 0
                        makeHarder()
                        trackStateChange(StateChange(CACurrentMediaTime(),"Touched Left Correctly"))
                        break
                    case .right:
                        // Failed Direction!
                        nextState = .FAILED
                        stateChangeLength = 0
                        makeEasier()
                        trackStateChange(StateChange(CACurrentMediaTime(),"Failed Right, Touched Left"))
                        break
                    case .leftStop:
                        if (nextState == .CHECKSYMBOL) {
                            // NTD - Review whether clicking early before store shows should be success?
                            // Succeeded by arriving early!
                            //trackStateChange(StateChange(CACurrentMediaTime(),"Succeeded in Stop Left, Touched Early"))
                            //nextState = .SUCCEEDED
                            //makeHarder()
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed in Stop Left, Touched Left Early"))
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        } else {
                            nextState = .FAILED
                            stateChangeLength = 0
                            makeEasier()
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed to Stop Left, Touched Left"))
                        }
                        break
                    case .rightStop:
                        // Failed!
                        if (nextState == .CHECKSYMBOL) {
                            // Success! The stop hasn't shown yet!
                             // NTD - Review whether clicking early before store shows should be success?
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed by touching Left early on Stop Right"))
                            nextState = .FAILED
                            makeEasier()
                            stateChangeLength = 0
                        } else {
                            nextState = .FAILED
                            stateChangeLength = 0
                            makeEasier()
                            trackStateChange(StateChange(CACurrentMediaTime(),"Failed to Stop Right, Touched Left"))
                        }
                        break
                    }
                }
            }
        }
    }
    
    func disableArt() {
        leftImage.isHidden = true
        rightImage.isHidden = true
        noImage.isHidden = true
    }
    
    func trackStateChange(_ change:StateChange) {
        
        stateChanges.append(change)
        if (Tuning.debug) {
            print(change)
        }
    }
    
    func restartRound() {
        disableArt()
        setupRound()
        
        analyticSet.clearIndex(roundIndex)
        
        step = 0
        nextState = .LEADIN
        stateChangeLength = 0
        currentTime = CACurrentMediaTime()
        trackStateChange(StateChange(currentTime,"====START ROUND \(roundIndex)===="))
    }
    
    func restartRoundAfterInterrupt() {
        disableArt()
        setupRound()
        
        analyticSet.clearIndex(roundIndex)
        
        step = 0
        nextState = .ROUND_PENDING
        startNextRoundView.isHidden = false
        stateChangeLength = 0
        currentTime = CACurrentMediaTime()
        trackStateChange(StateChange(currentTime,"====START ROUND \(roundIndex)===="))
    }
    
    var analytic:Analytic = Analytic()
    var roundStartTimestamp:CFTimeInterval = 0
    var analyticSet:AnalyticSet = AnalyticSet()
    
    // This method is called every time a state change that was scheduled actually occurs.
    func runSymState() {
        // State Machine
        
        switch (nextState) {
        case .LEADIN:
            
            // If there's an existing analytic, save it!
            analytic = Analytic()
            
            if (step == 0) {
                stateChangeLength = roundStartTime
                roundStartTimestamp = CACurrentMediaTime()
                analytic.trialStartTimestamp = roundStartTimestamp
            } else {
                stateChangeLength = leadinTime
                analytic.trialStartTimestamp = CACurrentMediaTime()
            }
            
            analytic.trialNumber = step
            analytic.participantId = Tuning.pid
            analytic.numberOfStop = Tuning.stopCount
            analytic.numberOfGo = Tuning.goCount
            analytic.roundId = roundIndex
            analytic.visitId = Tuning.visitId
            analytic.stimulusType = Tuning.stimulusId
            analytic.trialType = fullEventSet[step].rawValue
            analytic.stopDelay = userTimeForStop
            
            
            // Make sure everything is turned off.
            disableArt()
            nextState = .SYMBOL
            // debugging time tracking
            // NTD Tuning macro?
            trackStateChange(StateChange(currentTime,"LEADIN-\(fullEventSet[step])"))
            break
        case .SYMBOL:
            // Figure out what needs to be turned on.
            switch (fullEventSet[step]) {
            case .right:
                rightImage.isHidden = false
                stateChangeLength = timeForSymbol
                break
            case .left:
                leftImage.isHidden = false
                stateChangeLength = timeForSymbol
                break
            case .leftStop:
                leftImage.isHidden = false
                stateChangeLength = userTimeForStop
                break
            case .rightStop:
                rightImage.isHidden = false
                stateChangeLength = userTimeForStop
                break
            }
            analytic.actualSignalDelay = CACurrentMediaTime() - analytic.trialStartTimestamp
            nextState = .CHECKSYMBOL
            trackStateChange(StateChange(currentTime,"SYMBOL"))
            // Setup the timing based on whether there is a stop or not.
            break
        case .CHECKSYMBOL:
            // This means we are either ending it, or showing the stop symbol and going to STOPPED
            switch (fullEventSet[step]) {
            case .right:
                stateChangeLength = 0
                rightImage.isHidden = true
                nextState = .STEPFORWARD
                
                trackStateChange(StateChange(currentTime,"CHECKSYMBOL-RIGHT-\(userTimeForStop)"))
                break
            case .left:
                stateChangeLength = 0
                leftImage.isHidden = true
                nextState = .STEPFORWARD
                trackStateChange(StateChange(currentTime,"CHECKSYMBOL-LEFT-\(userTimeForStop)"))
                break
            case .leftStop:
                // stop delay is time from sumbol show minus stop delay
                analytic.actualStopDelay = CACurrentMediaTime() - analytic.trialStartTimestamp - analytic.actualSignalDelay
                noImage.isHidden = false
                stateChangeLength = timeForSymbol - userTimeForStop
                nextState = .STOPPING
                trackStateChange(StateChange(currentTime,"CHECKSYMBOL-SETUPLEFTSTOP-\(userTimeForStop)"))
                break
            case .rightStop:
                analytic.actualStopDelay = CACurrentMediaTime() - analytic.trialStartTimestamp - analytic.actualSignalDelay
                analytic.actualSignalStopDelay = CACurrentMediaTime()
                noImage.isHidden = false
                stateChangeLength = timeForSymbol - userTimeForStop
                nextState = .STOPPING
                trackStateChange(StateChange(currentTime,"CHECKSYMBOL-SETUPRIGHTSTOP-\(userTimeForStop)"))
                break
            }
            break
        case .STOPPING:
            stateChangeLength = 0
            disableArt()
            nextState = .STOPPING_SUCCEEDED
            trackStateChange(StateChange(currentTime,"STOPPING"))
            break
        case .STOPPING_SUCCEEDED:
            analytic.userResult = 2 // stopping succeeded
            makeHarder()
            trackStateChange(StateChange(currentTime,"STOPPING SUCCEEDED"))
            stateChangeLength = 0
            nextState = .STEPFORWARD
            break
        case .SUCCEEDED:
            analytic.userResult = 1 // touched succeeded
            // Happens when the puts finger down in time on right/left
            // Do whatever tracking is needed!
            disableArt()
            // Maybe
            nextState = .STEPFORWARD
            trackStateChange(StateChange(currentTime,"SUCCEEDED"))
            break
        case .FAILED:
            analytic.userResult = 0 // touched failed
            // Happens when the user puts wrong input in.
            // Do whatever tracking is needed!
            disableArt()
            // Maybe
            nextState = .STEPFORWARD
            trackStateChange(StateChange(currentTime,"FAILED"))
            break
        case .STEPFORWARD:
            step = step + 1
            
            // CHECK FOR END OF ROUND!
            if (step >= fullEventSet.count) {
                
                let now = CACurrentMediaTime()
                analytic.actualTimeSinceStart = now - roundStartTimestamp
                analytic.actualTrialDuration = now - analytic.trialStartTimestamp
                
                analyticSet.saveAnalyticWithIndexSet(analytic, roundIndex)
                
                // We are done with this round!
                // For now, let's reset it and keep going
                roundIndex = roundIndex + 1
                
                if (roundIndex == 3) {
                    trackStateChange(StateChange(CACurrentMediaTime(),"====END SESSION \(roundIndex-1)===="))
                    nextState = .DEBUGGING
                    endSession()
                } else if (roundIndex < 3) {
                    trackStateChange(StateChange(CACurrentMediaTime(),"====END ROUND \(roundIndex-1)===="))
                    stateChangeLength = 0
                    nextState = .ROUND_PENDING
                    startNextRoundView.isHidden = false
                }
            } else {
            
                let now = CACurrentMediaTime()
                analytic.actualTrialDuration = now - analytic.trialStartTimestamp
                analytic.actualTimeSinceStart = now - roundStartTimestamp
                
                // Go to next step!
                stateChangeLength = 0
                nextState = .LEADIN
                
                analyticSet.saveAnalyticWithIndexSet(analytic, roundIndex)
            }
            break
        case .ROUND_PENDING:
            // Do nothing.
            stateChangeLength = 9999999
            break
        case .INTERRUPTED:
            // Restart
            trackStateChange(StateChange(CACurrentMediaTime(),"====ROUND INTERRUPTED - RESTARTED \(roundIndex)===="))
            restartRoundAfterInterrupt()
            break
        case .DEBUGGING:
            break
        }
        
    }
    
    @objc func update() {
        currentTime = CACurrentMediaTime()
        
        // State Checking
        // The system is fastes when this is the only check that needs to happen on most frames,
        // the rest of the login needs to know that all setup and state changes are
        // handled through a single door using lastStateChangeTime and stateChangeLength,
        // the logic flow will essentially set those times and then wait for the next state change to occur
        // once it does occur, the logic for changing visualization or whatever will happen.
        // The input handling state changes also need to take this into account.
        if (currentTime - lastStateChangeTime > stateChangeLength) {
            
            if (startTime == -1.0) {
                startTime = currentTime
            } else {
                lastStateChangeTime = currentTime
                
                runSymState()
                
                
            }
        }
        
        // This is debug used to track the time framing, remove in production release
        // NTD Setup release macro in build settings to remove on release code, only debug.
  
        if (Tuning.debug) {
            times.append(currentTime) // debug, remove later
            frame = frame + 1
        }
    }
    
    
    /////////////////////////////////////
    /////////////////////////////////////
    // DEBUG
    @IBAction func stop() {
        let stopTime = CACurrentMediaTime()
        loop?.invalidate()
        //print("starttime: \(startTime) - frame:\(frame)")
        let timeSinceStart = stopTime - startTime
        let timePerFrame = timeSinceStart / Double(frame)
        let framesPerSec = 1.0 / timePerFrame
        debugLabel.text = "time per frame: \(timePerFrame) fps: \(Int(framesPerSec))"
        //print(stateChanges)
        for subview in debugStack.arrangedSubviews {
            debugStack.removeArrangedSubview(subview)
        }
        for i in 0 ... stateChanges.count - 1 {
        //for stateChange in stateChanges {
            let label = UILabel()
            if (i == 0) {
                label.text = "Start Time:\(stateChanges[0])"
            } else {
                label.text = "\(stateChanges[i].time) - \(stateChanges[i].time - stateChanges[i-1].time)"
            }
            
            debugStack.addArrangedSubview(label)
        }
    }
    
    func showDebug() {
        saveStateMachineHistory()
        
        //print(stateChanges)
        back.isHidden = false
        debugView.isHidden = false
        for subview in debugStack.arrangedSubviews {
            debugStack.removeArrangedSubview(subview)
        }
        
        let pid = UILabel()
        pid.text = "PID:\(String(describing: Tuning.pid)) StudyID:\(String(describing: Tuning.studyId)) Note:\(String(describing: Tuning.studyNote))"
        debugStack.addArrangedSubview(pid)
        
        let studyorder = UILabel()
        studyorder.text = "Event Set: \(fullEventSet)"
        studyorder.numberOfLines = 0
        debugStack.addArrangedSubview(studyorder)
        
        
        for i in 0 ... stateChanges.count - 1 {
            //for stateChange in stateChanges {
            let label = UILabel()
            label.text = "\(stateChanges[i])"
            
            debugStack.addArrangedSubview(label)
        }
    }
    
    // DEBUG
    @IBAction func start() {
        loop?.invalidate()
        loop = nil
        stateChanges.removeAll()
        times.removeAll()
        frame = 0
        loop = Timer.scheduledTimer(timeInterval: 1.0/fps, target: self, selector: #selector(MainLoop.update), userInfo: nil, repeats: true)
        frame = 0
        
        
    }

}
