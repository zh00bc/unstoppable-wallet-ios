import Foundation
import EthereumKit
import UniswapKit
import RxSwift
import CoinKit

protocol ISwapAdapter: AnyObject {
    var swapSettingsAdapter: ISwapSettingsAdapter { get }
    var routerAddress: EthereumKit.Address { get }

    var state: SwapAdapterState { get }
    var stateObservable: Observable<SwapAdapterState> { get }

    func set(from: Coin?)
    var fromCoin: Coin? { get }
    var fromCoinObservable: Observable<Coin?> { get }

    func set(to: Coin)
    var toCoin: Coin? { get }
    var toCoinObservable: Observable<Coin?> { get }

    func set(fromAmount: Decimal?)
    var fromAmount: Decimal? { get }
    var fromAmountObservable: Observable<Decimal> { get }

    func set(toAmount: Decimal?)
    var toAmount: Decimal? { get }
    var toAmountObservable: Observable<Decimal> { get }

    var changeTypeAllowed: Bool { get }
    var amountType: AmountType { get }
    var amountTypeObservable: Observable<AmountType> { get }

    func switchCoins()
}

enum AmountType {
    case exactFrom, exactTo
}

struct AdditionalTradeInfo {
    let title: String
    let value: AdditionalTradeInfoValue
}

enum PercentageLevel: Int {
    case normal, warning, forbidden
}

enum AdditionalTradeInfoValue {
    case price(value: Decimal, baseCoin: Coin, quoteCoin: Coin)
    case percentage(percentage: Decimal, level: PercentageLevel = .normal)
    case coinAmount(amount: Decimal, coin: Coin)
    case swapRoute(route: [CoinKit.Coin])
}

struct Trade {
    let fromCoin: CoinKit.Coin
    let fromAmount: Decimal
    let toCoin: CoinKit.Coin
    let toAmount: Decimal

    let additionalInfo: [AdditionalTradeInfo]
}

enum SwapAdapterState {
    case loading
    case ready(trade: Trade, data: TransactionData)
    case notReady(errors: [Error] = [])
}

enum SwapError: Error {
    case invalidToken
    case editToAmountDisabled
    case noTradeData
}

protocol ISwapSettingsAdapter {
    var settingsItems: [ISwapSettingsViewModel] { get }
    var settingsItemsObservable: Observable<[ISwapSettingsViewModel]> { get }

    var state: SwapSettingsState { get }
    var stateObservable: Observable<SwapSettingsState> { get }

    func applySettings()
}

enum SwapSettingsState {
    case valid
    case invalid(cause: String?)
}
