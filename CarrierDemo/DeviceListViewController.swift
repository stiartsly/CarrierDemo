import UIKit
import ElastosCarrier

class DeviceListViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.isEditing = false;
        
        NotificationCenter.default.addObserver(forName: DeviceManager.DeviceListChanged, object: nil, queue: OperationQueue.main, using: {_ in
            self.tableView.isEditing = false;
            self.tableView.reloadData()
            
            if let hud = MBProgressHUD(for: self.view) {
                hud.hide(animated: true)
            }
            
            let navigationController = self.splitViewController!.isCollapsed ?
            (self.splitViewController!.viewControllers[0] as! UINavigationController).topViewController as? UINavigationController
            : self.splitViewController!.viewControllers[self.splitViewController!.viewControllers.count-1] as? UINavigationController
            let deviceViewController = navigationController?.viewControllers[0] as? DeviceViewController
            if let selectedDevice = deviceViewController?.device {
                let index = DeviceManager.sharedInstance.devices.index(of: selectedDevice)
                if DeviceManager.sharedInstance.status == .Connected && index != nil {
                    self.tableView.selectRow(at: IndexPath(row: index!+1, section: 0), animated: false, scrollPosition: .none)
                }
                else {
                    if self.splitViewController!.isCollapsed {
                        _ = navigationController?.navigationController?.popViewController(animated: true)
                    }
                    else {
                        let indexPath = IndexPath(row: 0, section: 0)
                        self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        self.tableView(self.tableView, didSelectRowAt: indexPath)
                        //self.performSegue(withIdentifier: "showDetail", sender: self.tableView.cellForRow(at: indexPath))
                    }
                }
            }
            else {
                if !self.splitViewController!.isCollapsed && self.tableView.indexPathForSelectedRow == nil {
                    self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
                }
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        splitViewController?.navigationController?.isNavigationBarHidden = true
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.splitViewController!.isCollapsed && self.tableView.indexPathForSelectedRow == nil {
            self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        }
        DeviceManager.sharedInstance.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        splitViewController?.navigationController?.isNavigationBarHidden = splitViewController?.navigationController?.topViewController == splitViewController
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "showDetail" {
//            let controller = (segue.destination as! UINavigationController).topViewController as! DeviceViewController
//            if let indexPath = self.tableView.indexPathForSelectedRow {
//                controller.device = indexPath.row > 0 ? DeviceManager.sharedInstance.devices[indexPath.row-1] : nil
//            }
//            else {
//                controller.device = nil
//            }
//        }
//    }

    @IBAction func showMyInfo(_ sender: Any) {
        //let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let myInfoVC = storyboard!.instantiateViewController(withIdentifier: "MyInfoViewControllerIdentity")
        splitViewController?.navigationController?.show(myInfoVC, sender: nil)
    }
    
    @IBAction func addDevice(_ sender: Any) {
        let scanVC = ScanViewController();
        splitViewController?.navigationController?.show(scanVC, sender: nil)
    }
}


// MARK: - UITableViewDataSource
extension DeviceListViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DeviceManager.sharedInstance.devices.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier:"DeviceCell", for: indexPath)
        cell.tag = indexPath.row
        
        if indexPath.row == 0 {
            cell.imageView?.image = UIImage(named: "local")
            cell.textLabel?.text = "本机"
            
            switch DeviceManager.sharedInstance.status {
            case .Disconnected:
                cell.detailTextLabel?.text = "离线"
                cell.detailTextLabel?.textColor = UIColor.gray
                cell.accessoryView?.isHidden = true
                
            default:
                cell.detailTextLabel?.text = nil
                cell.accessoryView?.isHidden = false
            }
        }
        else if indexPath.row <= DeviceManager.sharedInstance.devices.count {
            cell.imageView?.image = UIImage(named: "remote")
            
            let device = DeviceManager.sharedInstance.devices[indexPath.row-1]
            
            cell.textLabel?.text = device.deviceName
            cell.detailTextLabel?.text = nil
            cell.accessoryView?.isHidden = device.deviceInfo.status != CarrierConnectionStatus.Connected
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return indexPath.row > 0 ? .delete : .none
    }
}

// MARK: - UITableViewDelegate
extension DeviceListViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset = tableView.separatorInset;
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.row <= DeviceManager.sharedInstance.devices.count {
                let device = DeviceManager.sharedInstance.devices[indexPath.row-1]
                
                let hud = MBProgressHUD(view: self.view)
                hud.mode = .text;
                hud.removeFromSuperViewOnHide = true;
                self.view.addSubview(hud)
                hud.show(animated: true);
                
                do {
                    try DeviceManager.sharedInstance.carrierInst?.removeFriend(device.deviceId)
                    hud.label.text = "正在处理";
                } catch {
                    NSLog("friendRemove error : \(error.localizedDescription)")
                    hud.label.text = "删除设备失败";
                    hud.hide(animated: true, afterDelay: 1.0)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.row <= DeviceManager.sharedInstance.devices.count else {
            return false
        }
        
        if indexPath.row > 0 {
            guard DeviceManager.sharedInstance.status == .Connected else {
                return false
            }
            
            let device = DeviceManager.sharedInstance.devices[indexPath.row-1]
            guard device.deviceInfo.status == CarrierConnectionStatus.Connected else {
                return false
            }
        }
        
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let detailVC = self.storyboard!.instantiateViewController(withIdentifier: "detailVC")
            self.splitViewController?.showDetailViewController(detailVC, sender: nil)
            return
        }

        let device : Device = DeviceManager.sharedInstance.devices[indexPath.row-1]
        if device.status != nil {
            let detailVC = self.storyboard!.instantiateViewController(withIdentifier: "detailVC")
            let controller = (detailVC as! UINavigationController).topViewController as! DeviceViewController
            controller.device = device
            self.splitViewController?.showDetailViewController(detailVC, sender: nil)
            return
        }

        let hud = MBProgressHUD(view: self.view)
        hud.removeFromSuperViewOnHide = true;
        self.view.addSubview(hud)

        do {
            try DeviceManager.sharedInstance.getDeviceStatus(device) { result in
                if result != nil {
                    hud.hide(animated: true)

                    let detailVC = self.storyboard!.instantiateViewController(withIdentifier: "detailVC")
                    let controller = (detailVC as! UINavigationController).topViewController as! DeviceViewController
                    controller.device = device
                    self.splitViewController?.showDetailViewController(detailVC, sender: nil)
                }
                else {
                    hud.mode = .text;
                    hud.label.text = "获取设备状态失败";
                    hud.hide(animated: true, afterDelay: 1);

                    if self.splitViewController!.isCollapsed {
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                    else {
                        let navigationController = self.splitViewController!.viewControllers[self.splitViewController!.viewControllers.count-1] as? UINavigationController
                        let deviceViewController = navigationController?.viewControllers[0] as? DeviceViewController
                        if let selectedDevice = deviceViewController?.device {
                            let index = DeviceManager.sharedInstance.devices.index(of: selectedDevice)
                            self.tableView.selectRow(at: IndexPath(row: index!+1, section: 0), animated: false, scrollPosition: .none)
                        }
                        else {
                            self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
                        }
                    }
                }
            }

            hud.graceTime = 0.5
            hud.show(animated: true)
        }
        catch {
            hud.mode = .text;
            hud.label.text = "获取设备状态失败";
            hud.show(animated: true)
            hud.hide(animated: true, afterDelay: 1);

            if self.splitViewController!.isCollapsed {
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
            else {
                let navigationController = self.splitViewController!.viewControllers[self.splitViewController!.viewControllers.count-1] as? UINavigationController
                let deviceViewController = navigationController?.viewControllers[0] as? DeviceViewController
                if let selectedDevice = deviceViewController?.device {
                    let index = DeviceManager.sharedInstance.devices.index(of: selectedDevice)
                    self.tableView.selectRow(at: IndexPath(row: index!+1, section: 0), animated: false, scrollPosition: .none)
                }
                else {
                    self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
                }
            }
        }
    }
}
