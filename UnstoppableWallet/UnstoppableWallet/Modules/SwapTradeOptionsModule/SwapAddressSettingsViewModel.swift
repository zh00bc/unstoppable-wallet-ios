import RxSwift
import RxCocoa

class SwapAddressSettingsViewModel {
    private let resolutionService: AddressResolutionService
    private let addressParser: IAddressParser
    private let disposeBag = DisposeBag()

    let id: String
    let placeholder: String?
    var initialAddress: Address?

    var header: String?
    var footer: String?

    var onAddressChanged: ((Address?) -> ())?
    var onAmountChanged: ((Decimal?) -> ())?

    private let cautionRelay = BehaviorRelay<Caution?>(value: nil)
    var caution: Caution? {
        didSet {
            cautionRelay.accept(caution)
        }
    }

    private let setTextRelay = PublishRelay<String?>()

    private var editing = false
    private var forceShowError = false

    init(resolutionService: AddressResolutionService, addressParser: IAddressParser, id: String, placeholder: String?, initialAddress: Address?) {
        self.resolutionService = resolutionService
        self.addressParser = addressParser
        self.id = id
        self.placeholder = placeholder
        self.initialAddress = initialAddress

        resolutionService.resolveFinishedObservable
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .subscribe(onNext: { [weak self] address in
                    self?.forceShowError = true

                    if let address = address {
                        self?.onAddressChanged?(address)
                    } else {
                        self?.sync()
                    }
                })
                .disposed(by: disposeBag)

        sync()
    }

    private func sync() {
        if (editing && !forceShowError) || resolutionService.isResolving {
            cautionRelay.accept(nil)
        } else {
            cautionRelay.accept(caution)
        }
    }

}

extension SwapAddressSettingsViewModel: ISwapAddressSettingsViewModel {

    var isLoadingDriver: Driver<Bool> {
        resolutionService.isResolvingObservable.asDriver(onErrorJustReturn: false)
    }

    var cautionDriver: Driver<Caution?> {
        cautionRelay.asDriver()
    }

    var setTextSignal: Signal<String?> {
        setTextRelay.asSignal()
    }

    func onChange(text: String?) {
        forceShowError = false

        onAddressChanged?(text.map { Address(raw: $0) })
        resolutionService.set(text: text)
    }

    func onFetch(text: String?) {
        guard let text = text, !text.isEmpty else {
            return
        }

        let addressData = addressParser.parse(paymentAddress: text)

        setTextRelay.accept(addressData.address)
        onChange(text: addressData.address)

        if let amount = addressData.amount {
            onAmountChanged?(Decimal(amount))
        }
    }

    func onChange(editing: Bool) {
        if editing {
            forceShowError = true
        }

        self.editing = editing
        sync()
    }

}
