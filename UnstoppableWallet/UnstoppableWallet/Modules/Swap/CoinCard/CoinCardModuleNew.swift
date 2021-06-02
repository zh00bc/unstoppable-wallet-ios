import UniswapKit
import RxSwift
import CoinKit

struct CoinCardModuleNew {

    static func fromCell(service: SwapServiceNew, swapAdapter: ISwapAdapter, switchService: AmountTypeSwitchService) -> SwapCoinCardCell {
        let coinCardService = SwapFromCoinCardServiceNew(service: service, swapAdapter: swapAdapter)

        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, rateManager: App.shared.rateManager)
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        let viewModel = SwapCoinCardViewModel(coinCardService: coinCardService, fiatService: fiatService)

        let amountInputViewModel = AmountInputViewModel(
                service: coinCardService,
                fiatService: fiatService,
                switchService: switchService,
                decimalParser: AmountDecimalParser()
        )
        return SwapCoinCardCell(viewModel: viewModel, amountInputViewModel: amountInputViewModel, title: "swap.you_pay".localized)
    }

    static func toCell(service: SwapServiceNew, swapAdapter: ISwapAdapter, switchService: AmountTypeSwitchService) -> SwapCoinCardCell {
        let coinCardService = SwapToCoinCardServiceNew(service: service, swapAdapter: swapAdapter)

        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, rateManager: App.shared.rateManager)
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        let viewModel = SwapCoinCardViewModel(coinCardService: coinCardService, fiatService: fiatService)

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

class SwapFromCoinCardServiceNew: ISwapCoinCardService, IAmountInputService {
    private let service: SwapServiceNew
    private let swapAdapter: ISwapAdapter

    init(service: SwapServiceNew, swapAdapter: ISwapAdapter) {
        self.service = service
        self.swapAdapter = swapAdapter
    }

    var dex: SwapModule.Dex { service.dex }
    var isEstimated: Bool { swapAdapter.amountType != .exactFrom }
    var amount: Decimal { swapAdapter.fromAmount ?? 0 }
    var coin: Coin? { swapAdapter.fromCoin }
    var balance: Decimal? { service.balanceFrom }

    var isEstimatedObservable: Observable<Bool> { swapAdapter.amountTypeObservable.map { $0 != .exactFrom } }
    var amountObservable: Observable<Decimal> { swapAdapter.fromAmountObservable }
    var coinObservable: Observable<Coin?> { swapAdapter.fromCoinObservable }
    var balanceObservable: Observable<Decimal?> { service.balanceFromObservable }
    var errorObservable: Observable<Error?> {
        service.errorsObservable.map {
            $0.first(where: { .insufficientBalanceFrom == $0 as? SwapServiceNew.SwapError })
        }
    }

    func onChange(amount: Decimal) {
        swapAdapter.set(fromAmount: amount)
    }

    func onChange(coin: Coin) {
        swapAdapter.set(from: coin)
    }

}

class SwapToCoinCardServiceNew: ISwapCoinCardService, IAmountInputService {
    private let service: SwapServiceNew
    private let swapAdapter: ISwapAdapter

    init(service: SwapServiceNew, swapAdapter: ISwapAdapter) {
        self.service = service
        self.swapAdapter = swapAdapter
    }

    var dex: SwapModule.Dex { service.dex }
    var isEstimated: Bool { swapAdapter.amountType != .exactTo }
    var amount: Decimal { swapAdapter.toAmount ?? 0 }
    var coin: Coin? { swapAdapter.toCoin }
    var balance: Decimal? { service.balanceTo }

    var isEstimatedObservable: Observable<Bool> { swapAdapter.amountTypeObservable.map { $0 != .exactTo } }
    var amountObservable: Observable<Decimal> { swapAdapter.toAmountObservable }
    var coinObservable: Observable<Coin?> { swapAdapter.toCoinObservable }
    var balanceObservable: Observable<Decimal?> { service.balanceToObservable }
    var errorObservable: Observable<Error?> {
        Observable<Error?>.just(nil)
    }

    func onChange(amount: Decimal) {
        swapAdapter.set(toAmount: amount)
    }

    func onChange(coin: Coin) {
        swapAdapter.set(to: coin)
    }

}
