import Foundation
import ElastosCarrier
import QRCode

class MyInfoController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "我"

        if let carrierInst = DeviceManager.sharedInstance.carrierInst {
            if let myInfo = try? carrierInst.getSelfUserInfo() {
                nameLabel.text = myInfo.name;
                
                let qrCodeWidth = qrCodeImageView.bounds.size.width * UIScreen.main.scale;
                let address = carrierInst.getAddress()
                var qrCode = QRCode(address)
                qrCode?.size = CGSize(width: qrCodeWidth, height: qrCodeWidth)
                qrCodeImageView.image = qrCode?.image

                return
            }
        }

        messageLabel.text = "尚未成功连接服务器"
    }
}
