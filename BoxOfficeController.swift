
import Foundation
import FirebaseDatabase
import FirebaseFunctions

protocol BoxOfficeControllerObserver {
    func updateRedemptionState(codeRedemptions: [BoxOfficeRedemption] )
}

class BoxOfficeController: Listenable<BoxOfficeControllerObserver> {
 
    private lazy var functions = Functions.functions()
    private var userRedemptionCodesRef: DatabaseReference?
    private (set) var codeRedemptions: [BoxOfficeRedemption] = [] {
        didSet {
            self.updateListeners { (listener, index) in
                listener.updateRedemptionState(codeRedemptions: codeRedemptions)
            }
        }
    }
    init(withAuthController auth: AuthenticationController) {
        super.init()
        
        auth.add(listener: self)
        
        guard let userId = auth.userId  else { return }
       
        updateRedemptionsRef(userId: userId)
    }
    
    func updateRedemptionsRef(userId: String) {
        userRedemptionCodesRef?.removeAllObservers()
        userRedemptionCodesRef = Database.database().reference().child("users/\(userId)/redemption-codes")
        userRedemptionCodesRef?.observe(DataEventType.value, with: redemptionCodesStatesObserver())
    }
    
    func redeemCode(stream: Stream, code: String, completion: @escaping ((BoxOfficeCodeState) -> Void)) {
        functions.httpsCallable("redeemBoxOfficeCode").call(["eventId": stream.id, "code": code]) { (result, err) in
            
            if let error = err as NSError? {
                if error.domain == FunctionsErrorDomain {
                    
                    let message = error.localizedDescription
                    completion(.invalidCode(message))
                } else {
                    completion(.failure)
                }
            } else {
                let codeState = ((result?.data as? [String: Any])?["state"] as? String)?.toCodeState() ?? .failure
                completion(codeState)
            }
        }
    }
    
    func canStream(streamId: String?) -> Bool {
        return codeRedemptions.contains { codeRedemption in codeRedemption.streamId == streamId && codeRedemption.state.isApplied }
    }
    
    private func redemptionCodesStatesObserver() -> ((DataSnapshot) -> Void) {
        return { (snapshot: DataSnapshot) in
            
            self.codeRedemptions = snapshot.children.compactMap({ s in s as? DataSnapshot }).compactMap({ codeSnapshot in
                // Code snapshot is a map with a single element mapping code -> state
                guard  let code = (codeSnapshot.value as? Dictionary<String, String>)?.first?.key,
                        let stateString = (codeSnapshot.value as? Dictionary<String, String>)?.first?.value else {
                            
                        return nil
                }
                        
                return BoxOfficeRedemption(code: code, streamId: codeSnapshot.key, state: stateString.toCodeState())
            })
        }
    
    }
    
    // MARK: Listenable
    
    @discardableResult override public func add(listener: BoxOfficeControllerObserver, priority: ListenerPriority = .low) -> Bool {
        listener.updateRedemptionState(codeRedemptions: codeRedemptions)
        return super.add(listener: listener, priority: priority)
    }
}


extension BoxOfficeController: AuthenticationControllerObservable {
    func authenticationController(_ authenticationController: AuthenticationController, didAuthenticateUser user: User) {
        updateRedemptionsRef(userId: user.uniqueId)
    }
    
    func authenticationController(_ authenticationController: AuthenticationController, didFailToAuthenticateWithError error: Error) {}
    func authenticationController(_ authenticationController: AuthenticationController, didSignOutUser user: User?, withError error: Error?) {}
    func authenticationController(_ authenticationController: AuthenticationController, didSendPasswordResetEmail email: String) {}
    func authenticationController(_ authenticationController: AuthenticationController, didFailToSendPasswordResetEmail error: Error) {}
    func authenticationController(_ authenticationController: AuthenticationController, didFailToSignOutUser user: User?, error: Error) {}
    func authenticationController(_ authenticationController: AuthenticationController, willPerformOperation operation: AuthenticationOperation) {}
}
