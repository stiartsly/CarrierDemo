import Foundation
import ElastosCarrier

class DeviceInfoViewController : UITableViewController {
    var device : Device?
    private var _observer : NSObjectProtocol?
    
    convenience init() {
        self.init(style: .grouped)
    }
    
    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let deviceInfo = device {
            navigationItem.title = device?.deviceName
            
            _observer = NotificationCenter.default.addObserver(forName: DeviceManager.DeviceListChanged, object: nil, queue: OperationQueue.main, using: {
                [unowned self] _ in
                if DeviceManager.sharedInstance.status == .Connected {
                    if DeviceManager.sharedInstance.devices.contains(deviceInfo) {
                        self.navigationItem.title = self.device?.deviceName
                        self.tableView.reloadData()
                        MBProgressHUD.hide(for: self.view, animated: true)
                    }
                }
            })
        }
        else {
            navigationItem.title = "本机"
            
            _observer = NotificationCenter.default.addObserver(forName: DeviceManager.SelfInfoChanged, object: nil, queue: OperationQueue.main, using: {
                [unowned self] _ in
                self.tableView.reloadData()
                MBProgressHUD.hide(for: self.view, animated: true)
            })
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension DeviceInfoViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return device == nil ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 6 : 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell : UITableViewCell! = tableView.dequeueReusableCell(withIdentifier:"DeviceInfoCell")
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "DeviceInfoCell")
        }
        
        if indexPath.section == 0 {
            var userInfo : CarrierUserInfo?
            if device == nil {
                userInfo = try? DeviceManager.sharedInstance.carrierInst.getSelfUserInfo()
                cell.accessoryType = .disclosureIndicator
            }
            else {
                userInfo = device!.deviceInfo
                cell.accessoryType = .none
            }
            
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "名称"
                cell.detailTextLabel?.text = userInfo?.name
            case 1:
                cell.textLabel?.text = "电话"
                cell.detailTextLabel?.text = userInfo?.phone
            case 2:
                cell.textLabel?.text = "邮箱"
                cell.detailTextLabel?.text = userInfo?.email
            case 3:
                cell.textLabel?.text = "性别"
                cell.detailTextLabel?.text = userInfo?.gender
            case 4:
                cell.textLabel?.text = "地区"
                cell.detailTextLabel?.text = userInfo?.region
            case 5:
                cell.textLabel?.text = "签名"
                cell.detailTextLabel?.text = userInfo?.briefDescription
            default:
                break
            }
        }
        else {
            cell.textLabel?.text = "备注名"
            cell.detailTextLabel?.text = device?.deviceInfo.label
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return device == nil || indexPath.section > 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 && indexPath.row == 3 {
            let alertController = UIAlertController(title: "请选择性别", message: nil, preferredStyle: .actionSheet)
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            let maleAction = UIAlertAction(title: "男", style: .default) {
                [unowned self] action in
                self.setSelfGender(action.title!)
            }
            let femaleAction = UIAlertAction(title: "女", style: .default) {
                [unowned self] action in
                self.setSelfGender(action.title!)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(maleAction)
            alertController.addAction(femaleAction)
            
            if let popover = alertController.popoverPresentationController {
                let cell = tableView.cellForRow(at: indexPath)
                popover.sourceView = cell
                popover.sourceRect = cell!.bounds
                popover.permittedArrowDirections = .right // UIPopoverArrowDirection(rawValue: 0)
            }
            present(alertController, animated: true, completion: nil)
            return
        }
        
        var tilte : String? = nil
        var text : String? = nil
        var keyboardType : UIKeyboardType = .default
        var selector : Selector
        
        if indexPath.section == 0 {
            let userInfo = try? DeviceManager.sharedInstance.carrierInst.getSelfUserInfo()
            
            switch indexPath.row {
            case 0:
                tilte = "请输入名称"
                text = userInfo?.name
                selector = #selector(setSelfName)
            case 1:
                tilte = "请输入电话号码"
                text = userInfo?.phone
                keyboardType = .phonePad
                selector = #selector(setSelfPhone)
            case 2:
                tilte = "请输入电子邮箱"
                text = userInfo?.email
                keyboardType = .emailAddress
                selector = #selector(setSelfEmail)
            case 4:
                tilte = "请输入地区"
                text = userInfo?.region
                selector = #selector(setSelfRegion)
            case 5:
                tilte = "请输入签名"
                text = userInfo?.briefDescription
                selector = #selector(setSelfDescription)
            default:
                return
            }
        }
        else {
            tilte = "请输入备注名"
            text = device?.deviceInfo.label
            selector = #selector(setDeviceLabel)
        }
        
        let alertController = UIAlertController(title: tilte, message: nil, preferredStyle: .alert)
        alertController.addTextField() { textField in
            textField.text = text
            textField.keyboardType = keyboardType
            textField.clearButtonMode = .whileEditing
            NotificationCenter.default.addObserver(self, selector: #selector(self.alertTextFieldDidChange), name: .UITextFieldTextDidChange, object: textField)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) {
            [unowned self] _ in
            NotificationCenter.default.removeObserver(self, name: .UITextFieldTextDidChange, object: nil)
        }
        alertController.addAction(cancelAction)
        
        let okAction = UIAlertAction(title: "确定", style: .default) {
            [unowned self] _ in
            NotificationCenter.default.removeObserver(self, name: .UITextFieldTextDidChange, object: nil)
            let textField = alertController.textFields!.first!
            self.perform(selector, with: textField.text)
        }
        okAction.isEnabled = !(text?.isEmpty ?? true)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func alertTextFieldDidChange(notification: Notification) {
        if let alertController = presentedViewController as? UIAlertController {
            let textFields = alertController.textFields!.first! as UITextField
            let okAction = alertController.actions.last! as UIAlertAction
            okAction.isEnabled = !(textFields.text!.isEmpty)
        }
    }
}

extension DeviceInfoViewController {

    @objc(setSelfName:)
    func setSelfName(_ name: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.name != name {
                myInfo.name = name
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("修改名称失败")
        }
    }

    @objc(setSelfPhone:)
    func setSelfPhone(_ phone: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.phone != phone {
                myInfo.phone = phone
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("设置电话号码失败")
        }
    }

    @objc(setSelfEmail:)
    func setSelfEmail(_ email: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.email != email {
                myInfo.email = email
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("设置邮箱失败")
        }
    }

    @objc(setSelfGender:)
    func setSelfGender(_ gender: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.gender != gender {
                myInfo.gender = gender
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("设置性别失败")
        }
    }

    @objc(setSelfRegion:)
    func setSelfRegion(_ region: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.region != region {
                myInfo.region = region
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //tableView.reloadRows(at: [IndexPath(row: 4, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("设置区域失败")
        }
    }

    @objc(setSelfDescription:)
    func setSelfDescription(_ description: String) {
        do {
            let carrier = DeviceManager.sharedInstance.carrierInst!
            let myInfo = try carrier.getSelfUserInfo()
            if myInfo.briefDescription != description {
                myInfo.briefDescription = description
                try carrier.setSelfUserInfo(myInfo)
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //tableView.reloadRows(at: [IndexPath(row: 5, section: 0)], with: .automatic)
            }
        } catch  {
            showToast("设置备注名失败")
        }
    }

    @objc(stDeviceLabel:)
    func setDeviceLabel(_ label: String) {
        do {
            if device!.deviceInfo.label != label {
                let carrier = DeviceManager.sharedInstance.carrierInst!
                try carrier.setFriendLabel(forFriend: device!.deviceId, newLabel: label)
                
                MBProgressHUD.showAdded(to: self.view, animated: true)
                //device!.deviceInfo.label = label
                //self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .automatic)
            }
        } catch  {
            showToast("设置备注名失败")
        }
    }
    
    func showToast(_ text: String) {
        let hud = MBProgressHUD(view: self.view)
        self.view.addSubview(hud);
        hud.removeFromSuperViewOnHide = true;
        hud.minSize = CGSize.zero;
        hud.mode = .text;
        hud.label.text = text;
        hud.show(animated: true);
        hud.hide(animated: true, afterDelay: 1);
    }
}
