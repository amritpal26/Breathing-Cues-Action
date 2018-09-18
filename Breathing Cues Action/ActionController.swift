//
//  ViewController.swift
//  Breathing Cues Action
//
//  Created by Amritpal Singh on 2018-09-07.
//  Copyright © 2018 Amritpal Singh. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox
import UICircularProgressRing
import Firebase

class ActionController: UIViewController {

    enum BreathingState{
        case NEW_TIMER, PAUSED, STOPPED, INHALE, EXHALE, HOLD, END_TIMER
    }
    
    var ref: DatabaseReference!

    //audioPlayers.
    var beepAudioPlayer = AVAudioPlayer()
    var endAudioPlayer = AVAudioPlayer()

    // Keys for data in plist.
    let timerSecondsKey = "TimerSeconds"
    let hold1SecondsKey = "SecondListContinousHold"
    let actionSecondsKey = "SecondListContinous"

    // Time factor for all milli variables.
    var FACTOR: float_t = 10

    // Keys for userDefaults for saving data between insatnces.
    let USER_NAME_PREF = "user_name_pref"
    let INHALE_PREF = "inhale_pref"
    let HOLD_1_PREF = "hold_1_pref"
    let EXHALE_PREF = "exhale_pref"
    let HOLD_2_PREF = "hold_2_pref"
    let TIMER_PREF = "timer_pref"
    let SOUND_PREF = "Sound_Pref"
    let VIBRATION_PREF = "Vibration_Pref"

    // Colors for the expandable circle view.
    let INHALE_COLOR = UIColor(hex: "00bfff")
    let HOLD_COLOR = UIColor(hex: "ffbf00")
    let EXHALE_COLOR = UIColor(hex: "bfff00")

    // USed to identify pickers.
    let INHALE_EXHALE_TAG = 1
    let HOLD_TAG = 2
    let TIMER_TAG = 3

    // Constants for the IDS pf pickers used to identify the picker for filling the data and setting them up.
    let TIMER_PICKER_ID = 0
    let INHALE_PICKER_ID = 1
    let HOLD1_PICKER_ID = 2
    let EXHALE_PICKER_ID = 3
    let HOLD2_PICKER_ID = 4

    // Data colleted from the plist for the picker views.
    var timerSeconds: [float_t] = []
    var holdSeconds: [float_t] = []
    var actionSeconds: [float_t] = []

    // Variables for holding the values for the picker views.
    var selectedTimerTime: float_t = 15
    var selectedInhaleTime: float_t = 1
    var selectedExhaleTime: float_t = 1
    var selectedHold1Time: float_t = 0
    var selectedHold2Time: float_t = 0
    var remainingTimerMillis: Int = 15000
    var timerTimeMillis: Int = 0;

    // Varibales for a cycle.
    var inhaleRangeMillis: Int = 0
    var hold1RangeMillis: Int = 0
    var exhaleRangeMillis: Int = 0
    var hold2RangeMillis: Int = 0
    var cycleRangeMillis: Int = 0
    var millisElapsedTotal: Int = 0
    var currentCycleNumber: Int = 0

    // Variables for expandable circle.
    var max: Int = 0
    var scaledMax: Int = 100
    var progress: Int = 0
    var scaledProgress: float_t = 1

    // Other varibles.
    var selectedRow: Int = 1
    let userDefaults = UserDefaults.standard
    var timer = Timer()
    var breathingState = BreathingState.NEW_TIMER
    var isSoundEnabled = false
    var isVibrationEnabled = false

    // Outlet connections.
    @IBOutlet weak var timerBtn: UIButton!
    @IBOutlet weak var clock: UILabel!
    @IBOutlet weak var inhale: UIButton!
    @IBOutlet weak var hold1: UIButton!
    @IBOutlet weak var exhale: UIButton!
    @IBOutlet weak var hold2: UIButton!
    @IBOutlet weak var actionProgress: UIView!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var totalTime: UIButton!
    @IBOutlet weak var progressView: UICircularProgressRing!


    override func viewDidLoad() {
        super.viewDidLoad()

        loadData()
        setupBtnsData()
        setupActionProgress()
        setupSoundAndVibration()
        
        FirebaseApp.configure()
        ref = Database.database().reference()

    }

    override func viewDidDisappear(_ animated: Bool) {
        breathingState = BreathingState.STOPPED
        unlockPickers()
        stopTimer()
        actionProgress.backgroundColor = INHALE_COLOR
    }

    override func viewDidAppear(_ animated: Bool) {
        isSoundEnabled = userDefaults.bool(forKey: SOUND_PREF)
        isVibrationEnabled = userDefaults.bool(forKey: VIBRATION_PREF)
        actionProgress.backgroundColor = INHALE_COLOR

        print(isSoundEnabled)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func inhalePicker(_ sender: UIButton) {
        setPickers(tag: INHALE_EXHALE_TAG, pickerId: INHALE_PICKER_ID)
        resetLabels()
    }

    @IBAction func hold1Picker(_ sender: UIButton) {
        setPickers(tag: HOLD_TAG, pickerId: HOLD1_PICKER_ID)
        resetLabels()
    }

    @IBAction func exhalePicker(_ sender: UIButton) {
        setPickers(tag: INHALE_EXHALE_TAG, pickerId: EXHALE_PICKER_ID)
        resetLabels()
    }

    @IBAction func hold2Picker(_ sender: UIButton) {
        setPickers(tag: HOLD_TAG, pickerId: HOLD2_PICKER_ID)
        resetLabels()
    }

    @IBAction func timerPicker(_ sender: UIButton) {
        setPickers(tag: TIMER_TAG, pickerId: TIMER_PICKER_ID)
        resetLabels()
    }
    @IBAction func startBtnPressed(_ sender: Any) {
        if breathingState == BreathingState.NEW_TIMER || breathingState == BreathingState.PAUSED || breathingState == BreathingState.STOPPED{
            startTimer()
        }else{
            breathingState = BreathingState.PAUSED
            stopTimer()
        }
    }
    @IBAction func timerLabelPressed(_ sender: Any) {
        if breathingState == BreathingState.INHALE || breathingState == BreathingState.EXHALE || breathingState == BreathingState.HOLD {
            breathingState = BreathingState.PAUSED
            stopTimer()
        }else{
            remainingTimerMillis = 0
            millisElapsedTotal = 0
            startTimer()
        }
    }

    func loadData(){
        let path = Bundle.main.path(forResource:"pickerData", ofType: "plist")
        let dict:NSDictionary = NSDictionary(contentsOfFile: path!)!

        if (dict.object(forKey: "TimerSeconds") != nil) {
            if let secArray = dict.object(forKey: "TimerSeconds") as? [float_t] {
                timerSeconds = secArray
                print(secArray)
            }
        }
        if (dict.object(forKey: "SecondListContinous") != nil) {
            if let secArray = dict.object(forKey: "SecondListContinous") as? [float_t] {
                actionSeconds = secArray
                print(secArray)
            }
        }
        if (dict.object(forKey: "SecondListContinousHold") != nil) {
            if let secArray = dict.object(forKey: "SecondListContinousHold") as? [float_t] {
                holdSeconds = secArray
                print(secArray)
            }
        }
    }

    func setupBtnsData(){
        let selectedTimerRow = userDefaults.integer(forKey: TIMER_PREF)
        let selectedInhaleRow = userDefaults.integer(forKey: INHALE_PREF)
        let selectedHold1Row = userDefaults.integer(forKey: HOLD_1_PREF)
        let selectedExhaleRow = userDefaults.integer(forKey: EXHALE_PREF)
        let selectedHold2Row = userDefaults.integer(forKey: HOLD_2_PREF)

        timerBtn.setTitle(convertToString(totalSeconds: timerSeconds[selectedTimerRow]), for: .normal)
        inhale.setTitle(convertToString(totalSeconds: actionSeconds[selectedInhaleRow]), for: .normal)
        hold1.setTitle(convertToString(totalSeconds: holdSeconds[selectedHold1Row]), for: .normal)
        exhale.setTitle(convertToString(totalSeconds: actionSeconds[selectedExhaleRow]), for: .normal)
        hold2.setTitle(convertToString(totalSeconds: holdSeconds[selectedHold2Row]), for: .normal)

        selectedTimerTime = timerSeconds[selectedTimerRow]
        selectedInhaleTime = actionSeconds[selectedInhaleRow]
        selectedHold1Time = holdSeconds[selectedHold1Row]
        selectedExhaleTime = actionSeconds[selectedExhaleRow]
        selectedHold2Time = holdSeconds[selectedHold2Row]

        remainingTimerMillis = Int(selectedTimerTime * 10)
        totalTime.isOpaque = false
    }

    func setupActionProgress(){
        actionProgress.backgroundColor = INHALE_COLOR
        actionProgress.layer.masksToBounds = true
        let screenWidth = UIScreen.main.bounds.width
        let viewWidth = screenWidth - 120 // 120 is the sum of all the  horizonatal constraints.
        actionProgress.layer.cornerRadius = viewWidth / 2
        actionProgress.clipsToBounds = true
    }

    func setupSoundAndVibration(){
        do{
            let beepAudioPath = Bundle.main.path(forResource: "beep", ofType: "mp3")
            beepAudioPlayer = try AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: beepAudioPath!))

            let endAudioPath = Bundle.main.path(forResource: "final", ofType: "mp3")
            endAudioPlayer = try AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: endAudioPath!))
        }catch{
            print(error)
        }
    }

    func startTimer(){
        if breathingState == BreathingState.PAUSED || breathingState == BreathingState.NEW_TIMER || breathingState == BreathingState.STOPPED{

            totalTime.isOpaque = true
            breathingState = BreathingState.NEW_TIMER
            inhaleRangeMillis = Int(selectedInhaleTime * FACTOR)
            hold1RangeMillis = inhaleRangeMillis + Int(selectedHold1Time * FACTOR)
            exhaleRangeMillis = hold1RangeMillis + Int(selectedExhaleTime * FACTOR)
            hold2RangeMillis = exhaleRangeMillis + Int(selectedHold2Time * FACTOR)

            cycleRangeMillis = hold2RangeMillis
            
            let numberOfCycles = (Int(selectedTimerTime * FACTOR) / cycleRangeMillis) + 1
            timerTimeMillis = numberOfCycles * cycleRangeMillis
            remainingTimerMillis = Int(timerTimeMillis)
            progressView.maxValue = CGFloat(remainingTimerMillis)
            print("timer: ", selectedTimerTime ,"cycleRange:", cycleRangeMillis, "numCycles: ", numberOfCycles )
            setActionMax(max: cycleRangeMillis)

            // Start the timer.
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: (#selector(ActionController.timerResponse)), userInfo: nil, repeats: true)
            lockPickers()
        }
    }

    @objc func timerResponse(){
        if remainingTimerMillis > 0{
            print(remainingTimerMillis)

            progressView.value = UICircularProgressRing.ProgressValue(millisElapsedTotal)
            currentCycleNumber = millisElapsedTotal / cycleRangeMillis

            // decrement the remining time.
            remainingTimerMillis -= 1
            millisElapsedTotal += 1

            if (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) < inhaleRangeMillis {
                if breathingState != BreathingState.INHALE{
                    playSound(isEnd: false)
                    vibrate(isEnd: false)
                    breathingState = BreathingState.INHALE
                    actionProgress.backgroundColor = INHALE_COLOR
                    print(breathingState)
                    startBtn.setTitle("Inhale", for: .normal)
                }

                setActionMax(max: Int(selectedInhaleTime * 10))
                let inhaleProgressMillis = (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis))
                let progressSec: float_t = float_t(inhaleProgressMillis / 10)
                let inhaleTimer = selectedInhaleTime - progressSec
                totalTime.setTitle(getRemainingTimeString(totalSeconds: inhaleTimer), for: .normal)
                setActionProgress(progress: inhaleProgressMillis)


            }else if (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) < hold1RangeMillis {
                if breathingState != BreathingState.HOLD{
                    playSound(isEnd: false)
                    vibrate(isEnd: false)
                    breathingState = BreathingState.HOLD
                    actionProgress.backgroundColor = HOLD_COLOR
                    print(breathingState)
                    startBtn.setTitle("Hold", for: .normal)
                }

                let progressMillis = (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) - inhaleRangeMillis
                let progressSec: float_t = float_t(progressMillis / 10)
                let holdTimer = selectedHold1Time - progressSec
                totalTime.setTitle(getRemainingTimeString(totalSeconds: holdTimer), for: .normal)

            }else if (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) < exhaleRangeMillis {
                if breathingState != BreathingState.EXHALE{
                    playSound(isEnd: false)
                    vibrate(isEnd: false)
                    breathingState = BreathingState.EXHALE
                    actionProgress.backgroundColor = EXHALE_COLOR
                    print(breathingState)
                    startBtn.setTitle("Exhale", for: .normal)
                }

                setActionMax(max: Int(selectedExhaleTime * 10))

                let progressMillis = (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) - hold1RangeMillis
                let exhaleNegProgressMillis = (exhaleRangeMillis + (currentCycleNumber * cycleRangeMillis)) - millisElapsedTotal
                let progressSec: float_t = float_t(progressMillis / 10)
                let exhaleTimer = selectedExhaleTime - progressSec
                totalTime.setTitle(getRemainingTimeString(totalSeconds: exhaleTimer), for: .normal)
                setActionProgress(progress: exhaleNegProgressMillis)

            }else if (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) < hold2RangeMillis {
                if breathingState != BreathingState.HOLD{
                    playSound(isEnd: false)
                    vibrate(isEnd: false)
                    breathingState = BreathingState.HOLD
                    actionProgress.backgroundColor = HOLD_COLOR
                    print("Hold 2")
                    startBtn.setTitle("Hold", for: .normal)
                }

                let progressMillis = (millisElapsedTotal - (currentCycleNumber * cycleRangeMillis)) - exhaleRangeMillis
                let progressSec: float_t = float_t(progressMillis / 10)
                let holdTimer = selectedHold2Time - progressSec
                totalTime.setTitle(getRemainingTimeString(totalSeconds: holdTimer), for: .normal)
            }
        }else{
            breathingState = BreathingState.END_TIMER
            stopTimer()
            sendDataToDatabase()
            playSound(isEnd: true)
        }
        let totalSecsElapsed = millisElapsedTotal / 10
        clock.text = convertToSecString(totalSeconds: totalSecsElapsed)
    }

    func stopTimer(){
        totalTime.setTitle("0", for: .normal)
        totalTime.isOpaque = false
        timer.invalidate()
        unlockPickers()

        print(breathingState)
        if remainingTimerMillis <= 0 && breathingState == BreathingState.END_TIMER {
            startBtn.setTitle("Start", for: .normal)
            totalTime.setTitle("0:00", for: .normal)
            progressView.value = progressView.maxValue
            remainingTimerMillis = 0
            millisElapsedTotal = 0
            playSound(isEnd: true)
            breathingState = BreathingState.STOPPED
        }
        else{
            startBtn.setTitle("Continue", for: .normal)
            totalTime.setTitle("Restart", for: .normal)
            //            progressView.value = 0
        }
    }

    func lockPickers(){
        timerBtn.isEnabled = false
        inhale.isEnabled = false
        hold1.isEnabled = false
        exhale.isEnabled = false
        hold2.isEnabled = false
    }

    func unlockPickers(){
        timerBtn.isEnabled = true
        inhale.isEnabled = true
        hold1.isEnabled = true
        exhale.isEnabled = true
        hold2.isEnabled = true
    }

    func playSound(isEnd: Bool){
        if isSoundEnabled{
            if isEnd{
                if beepAudioPlayer.isPlaying{
                    beepAudioPlayer.stop()
                }
                endAudioPlayer.play()
            }else{
                if beepAudioPlayer.isPlaying{
                    beepAudioPlayer.stop()
                }
                beepAudioPlayer.play()
            }
        }
    }

    func vibrate(isEnd: Bool){
        if isVibrationEnabled{
            if isEnd{

            }else{
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    func convertToString(totalSeconds: float_t) -> String {
        if totalSeconds > 10{
            let minutes: Int = Int(totalSeconds / 60)
            let secs:Int = Int(totalSeconds) % 60

            if secs > 9{
                return String(minutes) + ":" + String(secs)
            }else{
                return String(minutes) + ":0" + String(secs)
            }
        }else{
            let str = (totalSeconds.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalSeconds) : String(totalSeconds))
            return str
        }
    }
    
    func convertToSecString(totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds > 9{
            return String(minutes) + ":" + String(seconds)
        }else{
            return String(minutes) + ":0" + String(seconds)
        }
    }

    func getRemainingTimeString(totalSeconds: float_t) -> String{
        let secs: Int = Int(totalSeconds)
        return String(secs)
    }

    func resetLabels(){
//        stopTimer()

        totalTime.setTitle("0", for: .normal)
        startBtn.setTitle("Start", for: .normal)
        remainingTimerMillis = 0
        millisElapsedTotal = 0
    }
}

extension ActionController: UIPickerViewDataSource{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == INHALE_EXHALE_TAG{
            return actionSeconds.count
        }else if pickerView.tag == HOLD_TAG{
            return holdSeconds.count
        }else{
            return timerSeconds.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == INHALE_EXHALE_TAG {
            return convertToString(totalSeconds: actionSeconds[row])
        }else if pickerView.tag == HOLD_TAG{
            return convertToString(totalSeconds: holdSeconds[row])
        }else{
            return convertToString(totalSeconds: timerSeconds[row])
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int){
        selectedRow = row
    }

    func setPickers(tag: Int, pickerId: Int){
        let alert = UIAlertController(title: "Select Time", message: "\n\n\n\n\n\n", preferredStyle: .alert)
        alert.isModalInPopover = true

        let pickerFrame = UIPickerView(frame: CGRect(x: 5, y: 20, width: 250, height: 140))
        pickerFrame.tag = tag

        alert.view.addSubview(pickerFrame)
        pickerFrame.dataSource = self
        pickerFrame.delegate = self

        switch(pickerId){
        case self.TIMER_PICKER_ID:
            let selectedTimerRow = userDefaults.integer(forKey: TIMER_PREF)
            pickerFrame.selectRow(selectedTimerRow, inComponent: 0, animated: false)
            break
        case self.INHALE_PICKER_ID:
            let selectedInhaleRow = userDefaults.integer(forKey: INHALE_PREF)
            pickerFrame.selectRow(selectedInhaleRow, inComponent: 0, animated: false)
            break
        case self.HOLD1_PICKER_ID:
            let selectedHold1Row = userDefaults.integer(forKey: HOLD_1_PREF)
            pickerFrame.selectRow(selectedHold1Row, inComponent: 0, animated: false)
            break
        case self.EXHALE_PICKER_ID:
            let selectedExhaleRow = userDefaults.integer(forKey: EXHALE_PREF)
            pickerFrame.selectRow(selectedExhaleRow, inComponent: 0, animated: false)
            break
        case self.HOLD2_PICKER_ID:
            let selectedHold2Row = userDefaults.integer(forKey: HOLD_2_PREF)
            pickerFrame.selectRow(selectedHold2Row, inComponent: 0, animated: false)
            break
        default:
            // do nothing.
            break
        }


        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (UIAlertAction) in
            self.selectedRow = pickerFrame.selectedRow(inComponent: 0)
            switch(pickerId){
            case self.TIMER_PICKER_ID:
                self.selectedTimerTime = self.timerSeconds[self.selectedRow]
                self.remainingTimerMillis = Int(self.selectedTimerTime * self.FACTOR)
                self.userDefaults.set(self.selectedRow, forKey: self.TIMER_PREF)
                self.timerBtn.setTitle(self.convertToString(totalSeconds: self.selectedTimerTime), for: .normal)
                break
            case self.INHALE_PICKER_ID:
                self.selectedInhaleTime = self.actionSeconds[self.selectedRow]
                self.userDefaults.set(self.selectedRow, forKey: self.INHALE_PREF)
                self.inhale.setTitle(self.convertToString(totalSeconds: self.selectedInhaleTime), for: .normal)
                break
            case self.HOLD1_PICKER_ID:
                self.selectedHold1Time = self.holdSeconds[self.selectedRow]
                self.userDefaults.set(self.selectedRow, forKey: self.HOLD_1_PREF)
                self.hold1.setTitle(self.convertToString(totalSeconds: self.selectedHold1Time), for: .normal)
                break
            case self.EXHALE_PICKER_ID:
                self.selectedExhaleTime = self.actionSeconds[self.selectedRow]
                self.userDefaults.set(self.selectedRow, forKey: self.EXHALE_PREF)
                self.exhale.setTitle(self.convertToString(totalSeconds: self.selectedExhaleTime), for: .normal)
                break
            case self.HOLD2_PICKER_ID:
                self.selectedHold2Time = self.holdSeconds[self.selectedRow]
                self.userDefaults.set(self.selectedRow, forKey: self.HOLD_2_PREF)
                self.hold2.setTitle(self.convertToString(totalSeconds: self.selectedHold2Time), for: .normal)
                break
            default:
                // do nothing.
                break
            }
        }))
        self.present(alert,animated: true, completion: nil )
    }
}

extension ActionController: UIPickerViewDelegate{

}

// Functions for setting up the action progress circle.
extension ActionController{
    func setActionProgress(progress: Int){
        scaledProgress = (float_t(progress - 0) / float_t(max * 2)) + 0.50
        self.progress = progress
        UIView.animate(withDuration: 0.1, animations: {
            self.actionProgress.transform = CGAffineTransform(scaleX: CGFloat(self.scaledProgress), y: CGFloat(self.scaledProgress))
        })
    }

    func setActionMax(max: Int){
        self.max = max
        scaledMax = (max - 0) / 100
    }

    func getActionMax() -> Int{
        return max
    }

    func getActionProgress() -> Int{
        return progress
    }

    func getScaledActionMax() -> Int{
        return scaledMax
    }

    func getScaledActionProgress() -> float_t{
        return scaledProgress
    }
    
    func sendDataToDatabase(){
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ccc MMM dd, yyyy hh:mm:ss"
        let result = formatter.string(from: date)
        if userDefaults.object(forKey: USER_NAME_PREF) != nil{
            let userName = userDefaults.string(forKey: USER_NAME_PREF)
            ref.child("users").child(userName!).childByAutoId().setValue(result)
        }else{
            ref.child("users").child("default").childByAutoId().setValue(result)
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0

        var rgbValue: UInt64 = 0

        scanner.scanHexInt64(&rgbValue)

        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff

        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }


}

