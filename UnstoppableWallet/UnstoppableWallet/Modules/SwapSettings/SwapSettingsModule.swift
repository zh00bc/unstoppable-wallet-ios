import UIKit
import ThemeKit

struct SwapSettingsModule {

    static func viewController(swapSettingAdapter: ISwapSettingsAdapter) -> UIViewController? {
        guard let ethereumCoin = App.shared.coinKit.coin(type: .ethereum) else {
            return nil
        }

        let addressParserFactory = AddressParserFactory()

        let viewModel = SwapSettingsViewModel(swapSettingsAdapter: swapSettingAdapter)

//        let recipientViewModel = RecipientAddressViewModel(
//                service: service,
//                resolutionService: AddressResolutionService(coinCode: ethereumCoin.code),
//                addressParser: addressParserFactory.parser(coin: ethereumCoin)
//        )
//        let slippageViewModel = SwapSlippageViewModel(service: service, decimalParser: AmountDecimalParser())
//        let deadlineViewModel = SwapDeadlineViewModel(service: service, decimalParser: AmountDecimalParser())

        let viewController = SwapSettingsView(viewModel: viewModel)

        return ThemeNavigationController(rootViewController: viewController)
    }

}
