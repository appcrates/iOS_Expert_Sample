

import UIKit
import Stripe
import Alamofire
import FirebaseDatabase
import PassKit

class CheckingOutViewController: UIViewController {
    
    // MARK:- STRIPE CARD VIEWS VARS
    lazy var cardTextField: STPPaymentCardTextField = {
        let cardTextField = STPPaymentCardTextField()
        return cardTextField
    }()
    lazy var payButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 5
        button.backgroundColor = .systemBlue
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        button.setTitle("Pay", for: .normal)
        button.addTarget(self, action: #selector(getToken), for: .touchUpInside)
        return button
    }()
    
    
    lazy var cardImage: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "card")
        iv.layer.cornerRadius = 5
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    
    // MARK:- APPLE PAY BUILTIN BUTTON
    let applePayButton: PKPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
    
    
    //    MARK:- VALUES INITIALIZED FROM PREVIOUS VC
    var amount: Float = 1
    var streamID: String = ""
    var item: MediaPlaybackItem?
    var stream: Stream?
    var amountInUSD: Float = 0
    var usdCurrencyConversionRate: Float = 0.0
    

    //    MARK:- LOADING INDICATOR VARS
    var activityIndicator = UIActivityIndicatorView()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    var strLabel = UILabel()
    let messageFrame = UIView()
    
    // MARK:- SDLC METHODS
    override func viewDidLoad() {
        super.viewDidLoad()
    
        let convertedStr = String(format: "%.2f", amount * currencyConversionRate)
        var localCurrency = Defaults.shared.getCurrency()
        
        self.setButtonsAndViews()
        
        
        let orLabel = UILabel()
        orLabel.text = "or"
        orLabel.textAlignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = self.stream!.title
        titleLabel.textAlignment = .center
        
        
        if let artworkUrl = stream!.metadataArtworkUrl() {
            self.cardImage.setFadeInImage(with: URL(string: artworkUrl))
        }
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, self.getPriceLabel(), cardTextField, payButton, orLabel, applePayButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cardImage)
        view.addSubview(stackView)
        
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                stackView.leftAnchor.constraint(equalToSystemSpacingAfter: view.leftAnchor, multiplier: 2),
                view.rightAnchor.constraint(equalToSystemSpacingAfter: stackView.rightAnchor, multiplier: 2),
                stackView.topAnchor.constraint(equalToSystemSpacingBelow: cardImage.bottomAnchor, multiplier: 2),
            ])
        } else {
            // Fallback on earlier versions
        }
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.dissmissSelf), name: Notification.Name("dissmissCheckoutVC"), object: nil)
    }
    
    
    // MARK:- INIT VIEWS METHODS
    func setButtonsAndViews() {
        self.payButton.isEnabled = false
        self.applePayButton.isEnabled = false
        
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (timer) in
            self.payButton.isEnabled = true
            self.applePayButton.isEnabled = true
        }
        
        if Stripe.deviceSupportsApplePay() {
            applePayButton.isHidden = false
        }
        else {
            orLabel.isHidden = true
            applePayButton.isHidden = true
        }
        
        applePayButton.addTarget(self, action: #selector(handleApplePayButtonTapped), for: .touchUpInside)
        cardImage.frame = CGRect(x: 25, y: 0, width: self.view.frame.size.width - 50, height: self.view.frame.size.width - 50)
    }
    
    func getPriceLabel() -> UILabel {
        let priceLabel = UILabel()
        priceLabel.text = "\(String(describing: localCurrency))\(String(describing: convertedStr))"
        priceLabel.textAlignment = .center
        
        return priceLabel
    }
    
    
    // MARK:- PAYMENT METHODS
    @objc func getToken() {
        
        activityIndicator("Loading")
        
        // Create an STPCardParams instance
        let cardParams = STPCardParams()
        cardParams.number = cardTextField.cardNumber
        cardParams.expMonth = cardTextField.expirationMonth
        cardParams.expYear = cardTextField.expirationYear
        cardParams.cvc = cardTextField.cvc
        
        STPAPIClient.shared().createToken(withCard: cardParams) { (token, error) in
            
            let obj = token
            if let tokenId = token?.tokenId {
                self.paymentOnServer(token: tokenId)
            }
        }
    }
    
    func paymentOnServer(token: String) {
        
        print("currency amount in dollars is \(self.amountInUSD)")
        
        StripeClient.shared.completeCharge(with: token, amount: self.amountInUSD) { (success, error, response) in
            
            self.effectView.removeFromSuperview()
            
            if success {
                self.addToPurchasedEvents(streamId: self.streamID)
                self.displayAlert(title: "Congratulations", message: "Payment Success!", paymentSuccess: true)
            }
            else if error != nil {
                self.cardTextField.clear()
                self.displayAlert(title: "Alert", message: error!.localizedDescription, paymentSuccess: false)
            }
        }
    }
    
    
    // MARK:- STREAM HANDELING AFTER PAYMENT
    func addToPurchasedEvents(streamId: String) {
        
        var uid = ""
        if let id = UserDefaults.standard.string(forKey: "uid") {
            uid = id
        }
        var ref: DatabaseReference!
        ref = Database.database().reference()
        
        ref.child("users/\(String(describing: uid))/eventsPurchased/").child(streamId).setValue(true) {
            (error:Error?, ref:DatabaseReference) in
            if let error = error {
              print("test: Data could not be saved: \(error).")
            } else {
                print("test: Data saved successfully!")
                
                
                if isKeyPresentInUserDefaults(key: "purchased_event_ids") {
                    var wishListIds = UserDefaults.standard.stringArray(forKey: "purchased_event_ids")!
                    wishListIds.append(self.streamID)
                    UserDefaults.standard.setValue(wishListIds, forKey: "purchased_event_ids")
                }
                else {
                    let wishListIds: [String] = [self.streamID]
                    UserDefaults.standard.setValue(wishListIds, forKey: "purchased_event_ids")
                }
                
                if self.item != nil {
                    NotificationCenter.default.post(name: Notification.Name("eventPurchasedNoti"), object: nil, userInfo: ["item": self.item!])
                }
                else {
                    NotificationCenter.default.post(name: Notification.Name("eventPurchasedNoti"), object: nil)
                }
            }
        }
    }
    
    
    // MARK:- HELPING METHODS
    func activityIndicator(_ title: String) {
        strLabel.removeFromSuperview()
        activityIndicator.removeFromSuperview()
        effectView.removeFromSuperview()
        strLabel = UILabel(frame: CGRect(x: 50, y: 0, width: 160, height: 46))
        strLabel.text = title
        strLabel.font = .systemFont(ofSize: 14, weight: .medium)
        strLabel.textColor = UIColor(white: 0.9, alpha: 0.7)
        effectView.frame = CGRect(x: view.frame.midX - strLabel.frame.width/2, y: view.frame.midY - strLabel.frame.height/2 , width: 160, height: 46)
        effectView.layer.cornerRadius = 15
        effectView.layer.masksToBounds = true
        activityIndicator = UIActivityIndicatorView(style: .white)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 46, height: 46)
        activityIndicator.startAnimating()
        effectView.contentView.addSubview(activityIndicator)
        effectView.contentView.addSubview(strLabel)
        view.addSubview(effectView)
    }
    
    
    func displayAlert(title: String, message: String, paymentSuccess: Bool) {
        
        if paymentSuccess {
            let vc = PaymentSuccess()
            vc.stream = self.stream
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        }
        else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                    self.cardTextField.clear()
                })
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    self.dismiss(animated: true, completion: nil)
                })
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @objc func dissmissSelf() {
        self.dismiss(animated: false, completion: nil)
        NotificationCenter.default.post(name: Notification.Name("dissmissDetailVC"), object: nil)
    }
}

// MARK:- PAYMENT METHODS
extension CheckingOutViewController: PKPaymentAuthorizationViewControllerDelegate {

    @objc func handleApplePayButtonTapped() {
        let merchantIdentifier = "merchant.com.beatstreamboxoffice.beatstream"
        let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: merchantIdentifier, country: "US", currency: "GBP")
        
        paymentRequest.requiredBillingAddressFields = PKAddressField.email
        
        // Configure the line items on the payment request
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Payment through Apple Pay", amount: NSDecimalNumber(value: self.amount)),
        ]
        
        let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        applePayController!.delegate = self
        present(applePayController!, animated: true, completion: nil)
    }
    
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        
        activityIndicator("Loading")
        STPAPIClient.shared().createToken(with: payment) { (token, error) in
            if let tokenId = token?.tokenId {
                self.paymentOnServer(token: tokenId)
            }
        }
        completion(PKPaymentAuthorizationStatus.success)
    }
    
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        print("payment AuthorizationViewController Did Finish")
        controller.dismiss(animated: true, completion: nil)
    }
}

extension CheckingOutViewController: STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        return self
    }
}
