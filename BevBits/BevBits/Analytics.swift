//
//  Analytics.swift
//  BevBits
//
//  Created by Shayne Guiliano on 2/12/18.
//  Copyright © 2018 CHAICore. All rights reserved.
//

import Foundation

class Analytic {
    // Properties
    // NTD - Bug why are starts and stops not equal to 64?
    // NTD - Should stopSSD be actual or all proposed?
    public var participantId:String = ""
    public var visitId:Int = -1
    public var roundId:Int = -1
    public var numberOfGo:Int = 22
    public var numberOfStop:Int = 44
    public var stimulusType:Int = -1 // 0-3
    
    public var trialNumber:Int = -1 // index of trial count
    public var trialType:Int = -1 // go or stop 
    public var stopDelay:Double = -1 // proposed time in millisecs
    public var actualStopDelay:Double = -1.0 // actual time since start
    public var userResult:Int = -1 // 6 states, touched no touch + success or failure,
    public var sideTouched:Int = -1
    public var resultingDelayChange:Double = -1 // +/- 50 added at end depending on success/failure
    public var reactionTime:Double = -1.0 // time from start of symbol to when a finger first touched the screen.
    public var actualTimeSinceStart:Double = -1.0 //time from start of round to end.
    public var actualSignalDelay:Double = -1.0 // time since start of trial to when symbols actually shows
    public var actualSignalStopDelay:Double = -1.0 // start time in seconds since start of round
    public var actualTrialDuration:Double = -1.0 // amount of time from start to end of trial
    
    public var trialStartTimestamp:CFTimeInterval = 0
    
    func wasSuccessfulGo()->Bool {
        if (trialType <= 1
            && userResult == 1) {
            return true
        } else {
            return false
        }
    }
    
    func wasGo()->Bool {
        if (trialType <= 1) {
            return true
        } else {
            return false
        }
    }
    
    func wasStopInhibited()->Bool {
        if (trialType > 1
            && userResult == 2) {
            return true
        } else {
            return false
        }
    }
    
    func getCSVLine()->String {
        return "\(participantId),\(visitId),\(roundId),\(numberOfGo),\(numberOfStop),\(stimulusType),\(trialNumber),\(trialType),\(stopDelay),\(actualStopDelay),\(userResult),\(sideTouched),\(resultingDelayChange),\(reactionTime),\(actualTimeSinceStart),\(actualSignalDelay),\(actualSignalStopDelay),\(actualTrialDuration),\(trialStartTimestamp)\n"
    }
}

class AnalyticSet {
    func getHeader()->String {
        return "participantId,visitId,roundId,numberOfGo,numberOfStop,stimulusType,trialNumber,trialType,stopDelay,actualStopDelay,userResult,sideTouched,resultingDelayChange,reactionTime,actualTimeSinceStart,actualSignalDelay,actualSignalStopDelay,actualTrialDuration,trialStartTimestamp\n"
        
    }
    
    public var round1Start = 0.0
    public var round2Start = 0.0
    public var round3Start = 0.0
    
    func saveRoundStart(_ index:Int, timestamp:CFTimeInterval) {
        if (index == 0) {
            round1Start = timestamp
        } else if (index == 1) {
            round2Start = timestamp
        } else {
            round3Start = timestamp
        }
    }
    
    public var analyticsRound0:[Analytic] = []
    public var analyticsRound1:[Analytic] = []
    public var analyticsRound2:[Analytic] = []
    
    func buildCSV()->String {
        var stringBuilder = getHeader()
        for analytic in analyticsRound0 {
            stringBuilder += analytic.getCSVLine()
        }
        for analytic in analyticsRound1 {
            stringBuilder += analytic.getCSVLine()
        }
        for analytic in analyticsRound2 {
            stringBuilder += analytic.getCSVLine()
        }
        print(stringBuilder)
        return stringBuilder
    }
    
    func saveAnalyticWithIndexSet(_ analytic:Analytic, _ index:Int) {
        if (index == 0) {
             analyticsRound0.append(analytic)
        } else if (index == 1) {
             analyticsRound1.append(analytic)
        } else {
             analyticsRound2.append(analytic)
        }
    }
    func clearIndex(_ index:Int) {
        if (index == 0) {
            analyticsRound0.removeAll()
        } else if (index == 1) {
            analyticsRound1.removeAll()
        } else {
            analyticsRound2.removeAll()
        }
    }
    
}

class SuperSummary {
    var summaries:[Summary] = []
    
    var dataString = ""
    
    func produceCSV()->String {
        dataString = ""
        dataString = summaries[0].getHeader()
        for summary in summaries {
            dataString += summary.getString()
        }
        print("test:\(dataString)")
        return dataString
    }
}

class Summary {
    public var participantId = ""
    public var timeDate = ""
    public var timestamp = -Double(Int.max)
    public var stimuliType = -1
    public var visitId = -1
    public var meanGoRT = -Double(Int.max)
    public var medianGoRT = -Double(Int.max)
    public var stdDevGoRT = -Double(Int.max)
    public var percentGoResponse = -Double(Int.max)
    public var percentInhibition = -Double(Int.max)
    public var meanSSD = -Double(Int.max)
    public var medianSSD = -Double(Int.max)
    public var stdevSSD = -Double(Int.max)
    public var quantileSSRT = -Double(Int.max)
    public var note = ""
    
    func process(_ analyticArray:[Analytic]) {
        // save it all here!
        
        // First,
        participantId = analyticArray[0].participantId
        let format = DateFormatter()
        format.dateFormat = "yyyy.MM.dd 'at' HH:mm:ss zzz"
        participantId = analyticArray[0].participantId
        timestamp = analyticArray[0].trialStartTimestamp
        stimuliType = analyticArray[0].stimulusType
        visitId = analyticArray[0].visitId
        
        // Determine average reaction time of go trial.
        var totalGoSuccesses = 0.0
        var totalStopInhibitions = 0.0
        var additiveRectionTimes = 0.0
        var additionStopSignalDelay = 0.0
        
        var reactionTimes:[Double] = []
        var stopSignalDelays:[Double] = []
        for analytic in analyticArray {
            if (analytic.wasSuccessfulGo()) {
                totalGoSuccesses = totalGoSuccesses + 1
                additiveRectionTimes = additiveRectionTimes + analytic.reactionTime
                reactionTimes.append(analytic.reactionTime)
            }
            
            if (analytic.wasStopInhibited()) {
                totalStopInhibitions = totalStopInhibitions + 1
            }
            
            // Stop signal delays
            if (analytic.wasGo() == false
                && analytic.actualStopDelay > 0) {
                stopSignalDelays.append(analytic.actualStopDelay)
                additionStopSignalDelay = additionStopSignalDelay + analytic.actualStopDelay
            }
        }
        
        reactionTimes.sort()
        
        meanGoRT = additiveRectionTimes / totalGoSuccesses
        
        if (reactionTimes.count > 0) {
            if (reactionTimes.count % 2 == 1) {
                // it selected the middle because of int rounding down + 1 index coincidence
                medianGoRT = reactionTimes[reactionTimes.count/2]
            } else
            if (reactionTimes.count % 2 == 0) {
                let evenMeanIndexPlusOne = reactionTimes.count/2
                
                if (reactionTimes.count > 1) {
                    medianGoRT = (reactionTimes[evenMeanIndexPlusOne] + reactionTimes[evenMeanIndexPlusOne - 1]) / 2.0
                } else {
                    // reactionTimes.count == 1
                    medianGoRT = reactionTimes[0]
                }
                
            }
        }
        else {
            medianGoRT = 0
        }
        
        percentGoResponse = totalGoSuccesses / Double(analyticArray[0].numberOfGo)
        percentInhibition = totalStopInhibitions / Double(analyticArray[0].numberOfStop)
        
        if (stopSignalDelays.count > 0) {
            meanSSD = additionStopSignalDelay / Double(stopSignalDelays.count)
            stopSignalDelays.sort()
            
            medianSSD = stopSignalDelays[stopSignalDelays.count/2]
            
            if (stopSignalDelays.count % 2 == 1) {
                // it selected the middle because of int rounding down + 1 index coincidence
                medianSSD = stopSignalDelays[stopSignalDelays.count/2]
            } else
                if (stopSignalDelays.count % 2 == 0) {
                    let evenMeanIndexPlusOne = stopSignalDelays.count/2
                    
                    if (stopSignalDelays.count > 1) {
                        medianSSD = (stopSignalDelays[evenMeanIndexPlusOne] + stopSignalDelays[evenMeanIndexPlusOne - 1]) / 2.0
                    } else {
                        //stopSignalDelays.count == 1
                        medianSSD = stopSignalDelays[0]
                    }
            }
        }
        
        stdDevGoRT = 0.0
        stdevSSD = 0.0
        
        // Std Deviation calculations from means
        for analytic in analyticArray {
            if (analytic.wasSuccessfulGo()) {
                stdDevGoRT = stdDevGoRT + (analytic.reactionTime - meanGoRT) * (analytic.reactionTime - meanGoRT)
            }
            
            if (analytic.wasGo() == false) {
                stdevSSD = stdevSSD + (analytic.actualStopDelay - meanSSD) * (analytic.actualStopDelay - meanSSD)
            }
        }
        
        let meanOfStdDif = stdDevGoRT / totalGoSuccesses
        stdDevGoRT = meanOfStdDif.squareRoot()
        print("stdDevGoRT");
        let meanOfStdDifSSD = stdevSSD / Double(stopSignalDelays.count)
        
        stdevSSD = meanOfStdDifSSD.squareRoot()
        
        let stopError = 1.0 - percentInhibition
        
        if (stopError < 1.0) {
            let quantileReactionTimeIndex = Int(Double(reactionTimes.count) * stopError)
            
            if (reactionTimes.count > 0) {
                quantileSSRT = reactionTimes[quantileReactionTimeIndex] - meanSSD
            }
        }
        
        print(reactionTimes)
    }
    
    func getHeader()->String {
        return "participantId,timeDate,timestamp,stimuliType,visitId,meanGoRT,medianGoRT,stdDevGoRT,percentGoResponse,percentInhibition,meanSSD,medianSSD,stdevSSD,quantileSSRT,note\n"
        
    }
    
    func getString()->String {
        return "\(participantId),\(timeDate),\(timestamp),\(stimuliType),\(visitId),\(meanGoRT),\(medianGoRT),\(stdDevGoRT),\(percentGoResponse),\(percentInhibition),\(meanSSD),\(medianSSD),\(stdevSSD),\(quantileSSRT),\(note)\n"
    }
    
    func getCSV()->String {
        print(getHeader() + getString())
        return getHeader() + getString()
    }
    
   
}
