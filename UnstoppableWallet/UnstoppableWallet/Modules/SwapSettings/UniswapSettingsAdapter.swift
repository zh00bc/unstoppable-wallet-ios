import UniswapKit
import EthereumKit
import RxCocoa
import RxSwift

class UniswapSettingsAdapter {
    private var recommendedSlippageBounds: ClosedRange<Decimal> { 0.1...1 }
    private var limitSlippageBounds: ClosedRange<Decimal> { 0.01...20 }
    private var recommendedDeadlineBounds: ClosedRange<TimeInterval> { 600...1800 }

    private let resolutionService: AddressResolutionService
    private let addressParser: IAddressParser
    private let decimalParser: IAmountDecimalParser

    private(set) var state: SwapSettingsState {
        didSet {
            stateRelay.accept(state)
        }
    }
    private var stateRelay = PublishRelay<SwapSettingsState>()

    var slippage: Decimal {
        didSet {
            sync()
        }
    }

    var deadline: TimeInterval {
        didSet {
            sync()
        }
    }

    var recipient: Address? {
        didSet {
            sync()
        }
    }

    init(resolutionService: AddressResolutionService, addressParser: IAddressParser, decimalParser: IAmountDecimalParser, tradeOptions: SwapTradeOptions) {
        self.resolutionService = resolutionService
        self.addressParser = addressParser
        self.decimalParser = decimalParser
        slippage = tradeOptions.allowedSlippage
        deadline = tradeOptions.ttl
        recipient = tradeOptions.recipient

        state = .valid
        sync()
    }

    // slippage

    private var existSlippageViewModel: SwapDecimalSettingsViewModel?

    private var slippageViewModel: SwapDecimalSettingsViewModel {
        if let existSlippageViewModel = existSlippageViewModel {
            return existSlippageViewModel
        }

        let initialValue: String? = slippage != TradeOptions.defaultSlippage ?
                            slippage.description : nil

        let bounds = recommendedSlippageBounds
        let shortcuts = [
            InputShortcut(title: "\(bounds.lowerBound.description)%", value: bounds.lowerBound.description),
            InputShortcut(title: "\(bounds.upperBound.description)%", value: bounds.upperBound.description),
        ]

        let slippageViewModel = SwapDecimalSettingsViewModel(
                id: "slippage",
                placeholder: TradeOptions.defaultSlippage.description,
                initialValue: initialValue,
                shortcuts: shortcuts)

        slippageViewModel.header = "swap.advanced_settings.slippage".localized
        slippageViewModel.footer = "swap.advanced_settings.slippage.footer".localized
        slippageViewModel.onChange = { [weak self] in self?.onSlippageChange(text: $0) }
        slippageViewModel.isValid = { [weak self] in self?.isSlippageValid(text: $0) ?? true }

        existSlippageViewModel = slippageViewModel
        return slippageViewModel
    }

    private func onSlippageChange(text: String?) {
        guard let value = decimalParser.parseAnyDecimal(from: text) else {
            slippage = TradeOptions.defaultSlippage
            return
        }

        slippage = value
    }

    private func isSlippageValid(text: String) -> Bool {
        guard let amount = decimalParser.parseAnyDecimal(from: text) else {
            return false
        }

        return amount.decimalCount <= 2
    }

    // deadline

    private func toString(_ value: Double) -> String {
        Decimal(floatLiteral: floor(value / 60)).description
    }

    private var existDeadlineViewModel: SwapDecimalSettingsViewModel?

    private var deadlineViewModel: SwapDecimalSettingsViewModel {
        if let existDeadlineViewModel = existDeadlineViewModel {
            return existDeadlineViewModel
        }

        let initialValue = deadline != TradeOptions.defaultTtl ?
                toString(deadline) : nil

        let bounds = recommendedDeadlineBounds
        let shortcuts = [
            InputShortcut(title: "swap.advanced_settings.deadline_minute".localized(toString(bounds.lowerBound)), value: toString(bounds.lowerBound)),
            InputShortcut(title: "swap.advanced_settings.deadline_minute".localized(toString(bounds.upperBound)), value: toString(bounds.upperBound)),
        ]

        let deadlineViewModel = SwapDecimalSettingsViewModel(
                id: "deadline",
                placeholder: toString(TradeOptions.defaultTtl),
                initialValue: initialValue,
                shortcuts: shortcuts)

        deadlineViewModel.header = "swap.advanced_settings.deadline".localized
        deadlineViewModel.footer = "swap.advanced_settings.deadline.footer".localized
        deadlineViewModel.onChange = { [weak self] in self?.onDeadlineChange(text: $0) }
        deadlineViewModel.isValid = { [weak self] in self?.isDeadlineValid(text: $0) ?? true }

        existDeadlineViewModel = deadlineViewModel
        return deadlineViewModel
    }

    private func onDeadlineChange(text: String?) {
        guard let value = decimalParser.parseAnyDecimal(from: text) else {
            deadline = TradeOptions.defaultTtl
            return
        }

        deadline = NSDecimalNumber(decimal: value).doubleValue * 60
    }

    private func isDeadlineValid(text: String) -> Bool {
        guard let amount = decimalParser.parseAnyDecimal(from: text) else {
            return false
        }

        return amount.decimalCount <= 0
    }

    // recipient address
    private var existRecipientAddressViewModel: SwapAddressSettingsViewModel?

    private var recipientAddressViewModel: SwapAddressSettingsViewModel {
        if let existRecipientAddressViewModel = existRecipientAddressViewModel {
            return existRecipientAddressViewModel
        }

        let initialValue = recipient
        let bounds = recommendedDeadlineBounds
        let shortcuts = [
            InputShortcut(title: "swap.advanced_settings.deadline_minute".localized(toString(bounds.lowerBound)), value: toString(bounds.lowerBound)),
            InputShortcut(title: "swap.advanced_settings.deadline_minute".localized(toString(bounds.upperBound)), value: toString(bounds.upperBound)),
        ]

        let recipientViewModel = SwapAddressSettingsViewModel(
                resolutionService: resolutionService,
                addressParser: addressParser,
                id: "recipient",
                placeholder: nil,
                initialAddress: recipient)

        recipientViewModel.header = "swap.advanced_settings.recipient_address".localized
        recipientViewModel.footer = "swap.advanced_settings.recipient.footer".localized
        recipientViewModel.onAddressChanged = { [weak self] in self?.recipient = $0 }

        existRecipientAddressViewModel = recipientViewModel
        return recipientViewModel
    }


    private func sync() {
        var errors = [Error]()

        var tradeOptions = SwapTradeOptions()

        if let recipient = recipient, !recipient.raw.isEmpty {
            do {
                _ = try EthereumKit.Address(hex: recipient.raw)
                tradeOptions.recipient = recipient

                recipientAddressViewModel.caution = nil
            } catch {
                let error = AddressError.invalidAddress

                recipientAddressViewModel.caution = Caution(text: error.smartDescription, type: .error)
                errors.append(AddressError.invalidAddress)
            }
        }

        var slippageError: Error?

        if slippage == .zero {
            slippageError = SlippageError.zeroValue
        } else if slippage > limitSlippageBounds.upperBound {
            slippageError = SlippageError.tooHigh(max: limitSlippageBounds.upperBound)
        } else if slippage < limitSlippageBounds.lowerBound {
            slippageError = SlippageError.tooLow(min: limitSlippageBounds.lowerBound)
        }

        slippageViewModel.caution = slippageError.map { Caution(text: $0.smartDescription, type: .error) }
        if let slippageError = slippageError {
            errors.append(slippageError)
        } else {
            tradeOptions.allowedSlippage = slippage
        }

        if !deadline.isZero {
            tradeOptions.ttl = deadline
        } else {
            errors.append(DeadlineError.zeroValue)
        }

        if let error = errors.first {
            var cause: String? = nil
            switch error {
            case is UniswapSettingsAdapter.AddressError:
                cause = "swap.advanced_settings.error.invalid_address".localized
            case is UniswapSettingsAdapter.SlippageError:
                cause = "swap.advanced_settings.error.invalid_slippage".localized
            case is UniswapSettingsAdapter.DeadlineError:
                cause = "swap.advanced_settings.error.invalid_deadline".localized
            default: ()
            }

            state = .invalid(cause: cause)
        } else {
            state = .valid
        }
    }

}

extension UniswapSettingsAdapter: ISwapSettingsAdapter {

    var settingsItems: [ISwapSettingsViewModel] {
        [
            recipientAddressViewModel,
            slippageViewModel,
            deadlineViewModel
        ]
    }

    var settingsItemsObservable: Observable<[ISwapSettingsViewModel]> {
        fatalError("settingsItemsObservable has not been implemented")
    }


    var stateObservable: Observable<SwapSettingsState> {
        stateRelay.asObservable()
    }

}

extension UniswapSettingsAdapter {

    enum AddressError: Error {
        case invalidAddress
    }

    enum SlippageError: Error {
        case zeroValue
        case tooLow(min: Decimal)
        case tooHigh(max: Decimal)
    }

    enum DeadlineError: Error {
        case zeroValue
    }


}

extension UniswapSettingsAdapter.AddressError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "send.error.invalid_address".localized
        }
    }

}

extension UniswapSettingsAdapter.SlippageError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .tooLow: return "swap.advanced_settings.error.lower_slippage".localized
        case .tooHigh(let max): return "swap.advanced_settings.error.higher_slippage".localized(max.description)
        default: return nil
        }
    }

}
