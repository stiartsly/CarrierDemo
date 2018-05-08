import Foundation
import ElastosCarrier

class DeviceViewController: UITableViewController {
    var device : Device?
    var status : [String: Any]!
    var hud : MBProgressHUD?
    
    private var _observer : NSObjectProtocol?
    private var videoLayer : AVSampleBufferDisplayLayer?
    private var videoView: UIImageView?
    
    @IBOutlet weak var bulbStatus: UIButton!
    @IBOutlet weak var bulbSwitch: UISwitch!
    @IBOutlet weak var torchSwitch: UISwitch!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var audioPlayButton: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var videoPlayButton: UIButton!
    @IBOutlet weak var videoContentView: UIView!

    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "setting"), style: .plain, target: self, action: #selector(configDeviceInfo))
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "返回", style: .plain, target: self, action: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(onReceivedStatus), name: DeviceManager.DeviceStatusChanged, object: nil)

        if let deviceInfo = self.device {
            navigationItem.title = deviceInfo.deviceName
            status = deviceInfo.status!

            hud = MBProgressHUD(view: self.view)
            hud!.graceTime = 0.5
            self.view.addSubview(hud!)

            _observer = NotificationCenter.default.addObserver(forName: DeviceManager.DeviceListChanged, object: nil, queue: OperationQueue.main, using: {
                [unowned self] _ in
                if DeviceManager.sharedInstance.status == .Connected {
                    if DeviceManager.sharedInstance.devices.contains(deviceInfo) {
                        self.navigationItem.title = self.device?.deviceName
                    }
                }
            })
        }
        else {
            navigationItem.title = "本机"
            try! DeviceManager.sharedInstance.getDeviceStatus() { result in
                self.status = result
            }
        }

        if let bulbStatus = status["bulb"] as? Bool {
            self.bulbStatus.isSelected = bulbStatus
            self.bulbSwitch.setOn(bulbStatus, animated: false)
        }

        if let torchStatus = status["torch"] as? Bool {
            self.torchSwitch.setOn(torchStatus, animated: false)
            self.torchSwitch.isEnabled = true
        }

        if let brightness = status["brightness"] as? Float {
            self.brightnessSlider.value = brightness
        }

        if let ring = status["ring"] as? Bool {
            self.audioPlayButton.isSelected = ring
            self.volumeSlider.value = status["volume"] as! Float
        }

        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 30))
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.tableView.layoutMargins = UIEdgeInsets.zero
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.splitViewController?.navigationController?.isNavigationBarHidden = true
        self.tableView.separatorStyle = splitViewController!.isCollapsed ? .singleLine : .none
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.splitViewController?.navigationController?.isNavigationBarHidden = splitViewController?.navigationController?.topViewController == splitViewController

        if let videoPlayButton = videoPlayButton {
            if videoPlayButton.isSelected {
                if let currentDevice = device {
                    currentDevice.stopVideoPlay()
                }
                else {
                    DeviceManager.sharedInstance.stopVideoPlay()
                }
                videoPlayButton.isSelected = false
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var height : CGFloat = 0.1

        switch section {
        case 0:
            if status["bulb"] != nil {
                height = 20
            }

        case 1:
            if status["torch"] != nil {
                height = 20
            }

        case 2:
            if status["brightness"] != nil {
                height = 20
            }

        case 3:
            if status["ring"] != nil {
                height = 20
            }

        case 4:
            if status["camera"] != nil {
                height = 20
            }

        default:
            break
        }

        return height
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        var height : CGFloat = 0.1

        switch section {
        case 0:
            if status["bulb"] != nil {
                height = 30
            }

        case 1:
            if status["torch"] != nil {
                height = 30
            }

        case 2:
            if status["brightness"] != nil {
                height = 30
            }

        case 3:
            if status["ring"] != nil {
                height = 30
            }

        case 4:
            if status["camera"] != nil {
                height = 30
            }

        default:
            break
        }

        return height
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title : String? = nil

        switch section {
        case 0:
            if status["bulb"] != nil {
                title = "示例"
            }

        case 1:
            if status["torch"] != nil {
                title = "手电筒"
            }

        case 2:
            if status["brightness"] != nil {
                title = "亮度"
            }

        case 3:
            if status["ring"] != nil {
                title = "声音"
            }

        case 4:
            if status["camera"] != nil {
                title = "摄像头"
            }

        default:
            break
        }

        return title
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height : CGFloat = 0

        switch indexPath.section {
        case 0:
            if status["bulb"] != nil {
                height = 60
            }

        case 1:
            if status["torch"] != nil {
                height = 60
            }

        case 2:
            if status["brightness"] != nil {
                height = 60
            }

        case 3:
            if status["ring"] != nil {
                height = 60
            }

        case 4:
            if status["camera"] != nil {
                let width = tableView.bounds.size.width;
                height = width * 3 / 4
                videoLayer?.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: height))
            }

        default:
            break
        }

        return height
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.layoutMargins = UIEdgeInsets.zero
        
        if (self.splitViewController!.isCollapsed) {
            cell.backgroundColor = UIColor.white
            cell.backgroundView = nil
        }
        else if cell.frame.size.height > 0 {
            let cornerRadius : CGFloat = 6.0
            let layer: CAShapeLayer = CAShapeLayer()
            let pathRef:CGMutablePath = CGMutablePath()
            let bounds: CGRect = cell.bounds.insetBy(dx: 10, dy: 0)
            var addLine: Bool = false
            
            if (indexPath.row == 0 && indexPath.row == tableView.numberOfRows(inSection: indexPath.section)-1) {
                pathRef.__addRoundedRect(transform: nil, rect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            } else if (indexPath.row == 0) {
                pathRef.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
                pathRef.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.minY), tangent2End: CGPoint(x: bounds.midX, y: bounds.minY), radius: cornerRadius)
                pathRef.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.midY), radius: cornerRadius)
                pathRef.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
                addLine = true
            } else if (indexPath.row == tableView.numberOfRows(inSection: indexPath.section)-1) {
                pathRef.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
                pathRef.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.midX, y: bounds.maxY), radius: cornerRadius)
                pathRef.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.midY), radius: cornerRadius)
                pathRef.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            } else {
                pathRef.addRect(bounds)
                addLine = true
            }
            
            layer.path = pathRef
            layer.fillColor = UIColor.white.cgColor
            
            if (addLine == true) {
                let lineLayer: CALayer = CALayer()
                let lineHeight: CGFloat = (1.0 / UIScreen.main.scale)
                lineLayer.frame = CGRect(origin: CGPoint(x: bounds.minX+8, y: bounds.size.height-lineHeight), size: CGSize(width: bounds.size.width-8, height: lineHeight))
                lineLayer.backgroundColor = tableView.separatorColor?.cgColor
                layer.addSublayer(lineLayer)
            }
            
            let backgroundView: UIView = UIView(frame: bounds)
            backgroundView.layer.insertSublayer(layer, at: 0)
            backgroundView.backgroundColor = UIColor.clear
            cell.backgroundView = backgroundView
            cell.backgroundColor = UIColor.clear
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        tableView.reloadData()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        tableView.separatorStyle = newCollection.horizontalSizeClass == .regular ? .none : .singleLine
    }
    
    @IBAction func bulbSwitchChanged(_ sender: UISwitch) {
        let newStatus = sender.isOn
        print("bulbSwitchChanged : \(newStatus)")
        
        do {
            try DeviceManager.sharedInstance.setBulbStatus(newStatus, device: self.device)
            hud?.show(animated: true)
        }
        catch {
            NSLog("open/close bulb failed : \(error.localizedDescription)")
            DispatchQueue.main.async {
                sender.setOn(!newStatus, animated: true)
            }
        }
    }
    
    @IBAction func torchSwitchChanged(_ sender: UISwitch) {
        let newStatus = sender.isOn
        print("torchSwitchChanged : \(newStatus)")
        
        do {
            try DeviceManager.sharedInstance.setTorchStatus(newStatus, device: self.device)
            hud?.show(animated: true)
        }
        catch {
            NSLog("open/close torch failed : \(error.localizedDescription)")
            DispatchQueue.main.async {
                sender.setOn(!newStatus, animated: true)
            }
        }
    }
    
    @IBAction func brightnessSliderValueChanged(_ sender: UISlider) {
        print("brightnessSliderValueChanged : \(sender.value)")
        do {
            try DeviceManager.sharedInstance.setBrightness(sender.value, device: self.device)
            hud?.show(animated: true)
        }
        catch {
            NSLog("set brightness failed : \(error.localizedDescription)")
        }
    }
    
    @IBAction func audioPlayButtonClicked(_ sender: UIButton) {
        do {
            if sender.isSelected {
                try DeviceManager.sharedInstance.stopAudioPlay(self.device)
                sender.isSelected = false
            } else {
                try DeviceManager.sharedInstance.startAudioPlay(self.device)
                sender.isSelected = true
            }
            
            hud?.show(animated: true)
        }
        catch {
            NSLog("set brightness failed : \(error.localizedDescription)")
        }
    }
    
    @IBAction func volumeSliderValueChanged(_ sender: UISlider) {
        print("volumeSliderValueChanged : \(sender.value)")
        do {
            try DeviceManager.sharedInstance.setVolume(sender.value, device: self.device)
            hud?.show(animated: true)
        }
        catch {
            NSLog("set volume failed : \(error.localizedDescription)")
        }
    }
    
    @IBAction func videoPlayButtonClicked(_ sender: UIButton) {
        if sender.isSelected {
            if let currentDevice = device {
                currentDevice.stopVideoPlay()
            }
            else {
                DeviceManager.sharedInstance.stopVideoPlay()
            }
            sender.isSelected = false
        }
        else {
            if videoView == nil {
                videoView = UIImageView.init(frame: self.videoContentView.bounds)
                videoView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                videoView!.backgroundColor = UIColor.clear
                videoView!.contentMode = .scaleAspectFill
                self.videoContentView.addSubview(videoView!)
                self.videoContentView.bringSubview(toFront: self.videoPlayButton)
            }

            if videoLayer == nil {
                videoLayer = AVSampleBufferDisplayLayer()
                videoLayer!.frame = self.videoContentView.bounds
                videoLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
                self.videoContentView.layer.insertSublayer(videoLayer!, at: 0)
            }

            if let currentDevice = device {
                if currentDevice.startVideoPlay(videoView!, videoLayer!) {
                    sender.isSelected = true
                }
            }
            else {
                DeviceManager.sharedInstance.startVideoPlay(videoLayer!)
                sender.isSelected = true
            }
        }
    }

    @objc private func onReceivedStatus(_ notification: Notification) {
        guard device?.deviceId == (notification.object as? String) else {
            return
        }
        
        if let status = notification.userInfo {
            DispatchQueue.main.async {
                if let bulbStatus = status["bulb"] as? Bool {
                    self.bulbStatus.isSelected = bulbStatus
                    self.bulbSwitch.setOn(bulbStatus, animated: false)
                }

                if let torchStatus = status["torch"] as? Bool {
                    self.torchSwitch.setOn(torchStatus, animated: false)
                    self.torchSwitch.isEnabled = true
                }

                if let brightness = status["brightness"] as? Float {
                    self.brightnessSlider.value = brightness
                }
                
                if let audioPlay = status["ring"] as? Bool {
                    self.audioPlayButton.isSelected = audioPlay
                }
                
                if let volume = status["volume"] as? Float {
                    self.volumeSlider.value = volume
                }
                
                self.hud?.hide(animated: true)
            }
        }
    }
    
    @objc private func configDeviceInfo() {
        let deviceInfoVC = DeviceInfoViewController()
        deviceInfoVC.device = self.device
        navigationController?.show(deviceInfoVC, sender: nil)
    }
}
