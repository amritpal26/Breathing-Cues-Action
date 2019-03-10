//
//  Settings.swift
//  Breathing Cues
//
//  Created by Amritpal Singh on 2018-08-23.
//  Copyright © 2018 Amritpal Singh. All rights reserved.
//

import UIKit
import UserNotifications

class SettingViewController: UITableViewController{
    
    @IBOutlet weak var usernameSummary: UILabel!
    let USER_NAME_PREF = "user_name_pref"
    let SOUND_PREF = "Sound_Pref"
    let VIBRATION_PREF = "Vibration_Pref"
    let REMINDER1_PREF = "Reminder1_Pref"
    let REMINDER2_PREF = "Reminder2_Pref"
    let REMINDER1_TIME_PREF = "Reminder1_time_Pref"
    let REMINDER2_TIME_PREF = "Reminder2_time_Pref"
    let IDENTIFIER1 = "reminder1"
    let IDENTIFIER2 = "reminder2"
    
    var userDefaults = UserDefaults.standard
    
    @IBOutlet var tableViewOutlet: UITableView!
    @IBOutlet weak var soundSwitch: UISwitch!
    @IBOutlet weak var vibrationSwitch: UISwitch!
    @IBOutlet weak var reminder_1Switch: UISwitch!
    @IBOutlet weak var reminder_2Switch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let soundDef = userDefaults.bool(forKey: SOUND_PREF)
        let vibrationDef = userDefaults.bool(forKey: VIBRATION_PREF)
        let reminder1Def = userDefaults.bool(forKey: REMINDER1_PREF)
        let reminder2Def = userDefaults.bool(forKey: REMINDER2_PREF)
        
        setupUserSummary()
        
        soundSwitch.setOn(soundDef, animated: false)
        vibrationSwitch.setOn(vibrationDef, animated: false)
        reminder_1Switch.setOn(reminder1Def, animated: false)
        reminder_2Switch.setOn(reminder2Def, animated: false)
    }
    
    @IBAction func soundChanged(_ sender: UISwitch) {
        let value = sender.isOn
        userDefaults.set(value, forKey: SOUND_PREF)
    }
    @IBAction func vibrationChanged(_ sender: UISwitch) {
        let value = sender.isOn
        userDefaults.set(value, forKey: VIBRATION_PREF)
    }
    @IBAction func reminder_1Changed(_ sender: UISwitch) {
        let value = sender.isOn
        userDefaults.set(value, forKey: REMINDER1_PREF)
        
        if value{
            triggerNotification(reminder: 1)
        }else{
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [IDENTIFIER1])
        }
    }
    
    @IBAction func reminder_2Changed(_ sender: UISwitch) {
        let value = sender.isOn
        userDefaults.set(value, forKey: REMINDER2_PREF)
        
        if value{
            triggerNotification(reminder: 2)
        }else{
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [IDENTIFIER2])
        }
    }
    
    func setupUserSummary(){
        if userDefaults.object(forKey: USER_NAME_PREF) != nil{
            let name = userDefaults.string(forKey: USER_NAME_PREF)
            usernameSummary.text = name
            let indexPath = IndexPath(row: 0, section: 0)
            let cell = tableView(tableViewOutlet, cellForRowAt: indexPath)
            cell.isUserInteractionEnabled = false
            cell.selectionStyle = UITableViewCellSelectionStyle.gray
        }else{
            usernameSummary.text = "default"
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 1 && (indexPath.row == 1 || indexPath.row == 3)){
            let alert = UIAlertController(title: "Set Time", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
            alert.isModalInPopover = true
            
            let timePickerFrame = UIDatePicker(frame: CGRect(x: 5, y: 20, width: 250, height: 140))
            timePickerFrame.datePickerMode = .time
            
            var date = Date()
            if indexPath.row == 1{
                if (userDefaults.object(forKey: REMINDER1_TIME_PREF) != nil){
                    date = userDefaults.object(forKey: REMINDER1_TIME_PREF) as! Date
                    timePickerFrame.setDate(date, animated: false)
                }
            }else{
                if (userDefaults.object(forKey: REMINDER2_TIME_PREF) != nil){
                    date = userDefaults.object(forKey: REMINDER2_TIME_PREF) as! Date
                    timePickerFrame.setDate(date, animated: false)
                }
            }
            
            alert.view.addSubview(timePickerFrame)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            if indexPath.row == 1{
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (UIAlertAction) in
                    let date = timePickerFrame.date
                    self.userDefaults.set(date, forKey: self.REMINDER1_TIME_PREF)
                    
                    if self.userDefaults.bool(forKey: self.REMINDER1_PREF){
                        self.triggerNotification(reminder: 1)
                    }
                }))
            }else{
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (UIAlertAction) in
                    let date = timePickerFrame.date
                    self.userDefaults.set(date, forKey: self.REMINDER2_TIME_PREF)
                    
                    if self.userDefaults.bool(forKey: self.REMINDER2_PREF){
                        self.triggerNotification(reminder: 2)
                    }
                }))
            }
            self.present(alert,animated: true, completion: nil )
        }else if(indexPath.section == 0 && indexPath.row == 0){
            let alert = UIAlertController(title: "Set User Name", message: "\n", preferredStyle: .alert)
            alert.isModalInPopover = true
            
            alert.addTextField(configurationHandler: {(textField) in
                textField.placeholder = "Enter name"})
            alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { (UIAlertAction) in
                let name: String = (alert.textFields!.first as! UITextField).text!
                if name != ""{
                    self.userDefaults.set(name, forKey: self.USER_NAME_PREF)
                    self.setupUserSummary()
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func triggerNotification(reminder: Int){
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Time to do the relaxing exercise"
        content.badge = 1
        
        if reminder == 1{
            if (userDefaults.object(forKey: REMINDER1_TIME_PREF) != nil){
                let date = userDefaults.object(forKey: REMINDER1_TIME_PREF) as! Date
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: IDENTIFIER1, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }else{
            if (userDefaults.object(forKey: REMINDER2_TIME_PREF) != nil){
                let date = userDefaults.object(forKey: REMINDER2_TIME_PREF) as! Date
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                var components = DateComponents()
                print(hour)
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: IDENTIFIER2, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
}

