import UniswapKit
import EthereumKit
import RxCocoa
import RxSwift

class UniswapSettingsAdapter {
    private var recommendedSlippageBounds: ClosedRange<Decimal> { 0.1...1 }
    private var limitSlippageBounds: ClosedRange<Decimal> { 0.01...20 }
    private var recommendedDeadlineBounds: ClosedRange<TimeInterval> { 600...1800 }

    private let decimalParser: IAmountDecimalParser
    private let swapSettingsFactory: SwapSettingsViewModelFactory

    weak var delegate: UniswapAdapter?

    private var slippageViewModel: SwapDecimalSettingsViewModel
    private var deadlineViewModel: SwapDecimalSettingsViewModel
    private var recipientAddressViewModel: SwapAddressSettingsViewModel

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

    init(swapSettingsFactory: SwapSettingsViewModelFactory, decimalParser: IAmountDecimalParser, tradeOptions: SwapTradeOptions) {
        self.swapSettingsFactory = swapSettingsFactory
        self.decimalParser = decimalParser

        slippage = tradeOptions.allowedSlippage
        deadline = tradeOptions.ttl
        recipient = tradeOptions.recipient

        slippageViewModel = swapSettingsFactory.slippageViewModel(slippage: slippage)
        deadlineViewModel = swapSettingsFactory.deadlineViewModel(deadline: deadline)
        recipientAddressViewModel = swapSettingsFactory.recipientAddressViewModel(recipient: recipient)

        state = .valid

        slippageViewModel.onChange = { [weak self] in self?.onSlippageChange(text: $0) }
        slippageViewModel.isValid = { [weak self] in self?.isSlippageValid(text: $0) ?? true }

        deadlineViewModel.onChange = { [weak self] in self?.onDeadlineChange(text: $0) }
        deadlineViewModel.isValid = { [weak self] in self?.isDeadlineValid(text: $0) ?? true }

        recipientAddressViewModel.onAddressChanged = { [weak self] in self?.recipient = $0 }

        sync()
    }

    // slippage

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

    func applySettings() {
        delegate?.swapTradeOptions = SwapTradeOptions(allowedSlippage: slippage, ttl: deadline, recipient: recipient)
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
