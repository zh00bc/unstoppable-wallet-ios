import Foundation
import UniswapKit

class SwapSettingsViewModelFactory {
    private var recommendedSlippageBounds: ClosedRange<Decimal> { 0.1...1 }
    private var limitSlippageBounds: ClosedRange<Decimal> { 0.01...20 }
    private var recommendedDeadlineBounds: ClosedRange<TimeInterval> { 600...1800 }

    private let resolutionService: AddressResolutionService
    private let addressParser: IAddressParser

    init(resolutionService: AddressResolutionService, addressParser: IAddressParser) {
        self.resolutionService = resolutionService
        self.addressParser = addressParser
    }

    func slippageViewModel(slippage: Decimal) -> SwapDecimalSettingsViewModel {
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

        return slippageViewModel
    }

    private func toString(_ value: Double) -> String {
        Decimal(floatLiteral: floor(value / 60)).description
    }

    func deadlineViewModel(deadline: TimeInterval) -> SwapDecimalSettingsViewModel {
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

        return deadlineViewModel
    }

    func recipientAddressViewModel(recipient: Address?) -> SwapAddressSettingsViewModel {

        let recipientViewModel = SwapAddressSettingsViewModel(
                resolutionService: resolutionService,
                addressParser: addressParser,
                id: "recipient",
                placeholder: nil,
                initialAddress: recipient)

        recipientViewModel.header = "swap.advanced_settings.recipient_address".localized
        recipientViewModel.footer = "swap.advanced_settings.recipient.footer".localized


        return recipientViewModel
    }


}
