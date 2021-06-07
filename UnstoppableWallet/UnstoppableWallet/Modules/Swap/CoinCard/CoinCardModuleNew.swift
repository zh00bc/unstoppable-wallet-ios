import UniswapKit
import RxSwift
import CoinKit

struct CoinCardModuleNew {

    static func fromCell(service: SwapServiceNew, swapAdapterManager: SwapAdapterManager, switchService: AmountTypeSwitchService) -> SwapCoinCardCell {
        let coinCardService = SwapFromCoinCardServiceNew(service: service, swapAdapterManager: swapAdapterManager)

        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, rateManager: App.shared.rateManager)
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        let viewModel = SwapCoinCardViewModelNew(coinCardService: coinCardService, fiatService: fiatService)

        let amountInputViewModel = AmountInputViewModel(
                service: coinCardService,
                fiatService: fiatService,
                switchService: switchService,
                decimalParser: AmountDecimalParser()
        )
        return SwapCoinCardCell(viewModel: viewModel, amountInputViewModel: amountInputViewModel, title: "swap.you_pay".localized)
    }

    static func toCell(service: SwapServiceNew, swapAdapterManager: SwapAdapterManager, switchService: AmountTypeSwitchService) -> SwapCoinCardCell {
        let coinCardService = SwapToCoinCardServiceNew(service: service, swapAdapterManager: swapAdapterManager)

        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, rateManager: App.shared.rateManager)
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        let viewModel = SwapCoinCardViewModelNew(coinCardService: coinCardService, fiatService: fiatService)

        let amountInputViewModel = AmountInputViewModel(
                service: coinCardService,
                fiatService: fiatService,
                switchService: switchService,
                decimalParser: AmountDecimalParser(),
                isMaxSupported: false
        )
        return SwapCoinCardCell(viewModel: viewModel, amountInputViewModel: amountInputViewModel, title: "swap.you_get".localized)
    }

}

class SwapFromCoinCardServiceNew: ISwapCoinCardServiceNew, IAmountInputService {
    private let service: SwapServiceNew
    private let swapAdapterManager: SwapAdapterManager

    init(service: SwapServiceNew, swapAdapterManager: SwapAdapterManager) {
        self.service = service
        self.swapAdapterManager = swapAdapterManager
    }

    var dex: SwapModule.DexNew { swapAdapterManager.dex }
    var isEstimated: Bool { swapAdapterManager.swapAdapter.amountType != .exactFrom }
    var amount: Decimal { swapAdapterManager.swapAdapter.fromAmount ?? 0 }
    var coin: Coin? { swapAdapterManager.swapAdapter.fromCoin }
    var balance: Decimal? { service.balanceFrom }

    var updateSubscriptions: Observable<()> { swapAdapterManager.onUpdateProviderObservable }
    var isEstimatedObservable: Observable<Bool> { swapAdapterManager.swapAdapter.amountTypeObservable.map { $0 != .exactFrom } }
    var amountObservable: Observable<Decimal> { swapAdapterManager.swapAdapter.fromAmountObservable }
    var coinObservable: Observable<Coin?> { swapAdapterManager.swapAdapter.fromCoinObservable }
    var balanceObservable: Observable<Decimal?> { service.balanceFromObservable }
    var errorObservable: Observable<Error?> {
        service.errorsObservable.map {
            $0.first(where: { .insufficientBalanceFrom == $0 as? SwapServiceNew.SwapError })
        }
    }

    func onChange(amount: Decimal) {
        swapAdapterManager.swapAdapter.set(fromAmount: amount)
    }

    func onChange(coin: Coin) {
        swapAdapterManager.swapAdapter.set(from: coin)
    }

}

class SwapToCoinCardServiceNew: ISwapCoinCardServiceNew, IAmountInputService {
    private let service: SwapServiceNew
    private let swapAdapterManager: SwapAdapterManager

    init(service: SwapServiceNew, swapAdapterManager: SwapAdapterManager) {
        self.service = service
        self.swapAdapterManager = swapAdapterManager
    }

    var dex: SwapModule.DexNew { swapAdapterManager.dex }

    var updateSubscriptions: Observable<()> { swapAdapterManager.onUpdateProviderObservable }
    var isEstimated: Bool { swapAdapterManager.swapAdapter.amountType != .exactTo }
    var amount: Decimal { swapAdapterManager.swapAdapter.toAmount ?? 0 }
    var coin: Coin? { swapAdapterManager.swapAdapter.toCoin }
    var balance: Decimal? { service.balanceTo }

    var isEstimatedObservable: Observable<Bool> { swapAdapterManager.swapAdapter.amountTypeObservable.map { $0 != .exactTo } }
    var amountObservable: Observable<Decimal> { swapAdapterManager.swapAdapter.toAmountObservable }
    var coinObservable: Observable<Coin?> { swapAdapterManager.swapAdapter.toCoinObservable }
    var balanceObservable: Observable<Decimal?> { service.balanceToObservable }
    var errorObservable: Observable<Error?> {
        Observable<Error?>.just(nil)
    }

    func onChange(amount: Decimal) {
        swapAdapterManager.swapAdapter.set(toAmount: amount)
    }

    func onChange(coin: Coin) {
        swapAdapterManager.swapAdapter.set(to: coin)
    }

}
