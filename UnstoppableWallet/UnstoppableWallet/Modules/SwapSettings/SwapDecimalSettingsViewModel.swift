import RxCocoa

class SwapDecimalSettingsViewModel {
    let id: String
    let placeholder: String?
    let initialValue: String?
    let shortcuts: [InputShortcut]

    var header: String?
    var footer: String?

    var isValid: ((String) -> Bool)?
    var onChange: ((String?) -> ())?

    private let cautionRelay = BehaviorRelay<Caution?>(value: nil)
    var caution: Caution? {
        didSet {
            cautionRelay.accept(caution)
        }
    }

    public init(id: String, placeholder: String?, initialValue: String?, shortcuts: [InputShortcut]) {
        self.id = id
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.shortcuts = shortcuts
    }

}

extension SwapDecimalSettingsViewModel: ISwapDecimalSettingsViewModel {

    var cautionDriver: Driver<Caution?> {
        cautionRelay.asDriver()
    }

    func onChange(text: String?) {
        onChange?(text)
    }

    func isValid(text: String) -> Bool {
        isValid?(text) ?? true
    }

}
