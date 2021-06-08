import Foundation
import EthereumKit
import UniswapKit
import RxSwift
import RxRelay
import CoinKit

class UniswapAdapter {
    private static let warningPriceImpact: Decimal = 1
    private static let forbiddenPriceImpact: Decimal = 5
    private var swapDataDisposeBag = DisposeBag()
    private var lastBlockDisposeBag = DisposeBag()

    private let uniswapKit: UniswapKit.Kit
    private let settingsAdapterFactory: SwapSettingsAdapterFactory

    var state: SwapAdapterState = .notReady() {
        didSet {
            stateRelay.accept(state)
        }
    }
    private let stateRelay = PublishRelay<SwapAdapterState>()

    private let swapTradeOptionsRelay = PublishRelay<SwapTradeOptions>()
    var swapTradeOptions = SwapTradeOptions() {
        didSet {
            swapTradeOptionsRelay.accept(swapTradeOptions)
            syncTradeData()
        }
    }

    private(set) var fromCoin: Coin? {
        didSet {
            fromCoinRelay.accept(fromCoin)
        }
    }
    private let fromCoinRelay = PublishRelay<Coin?>()

    private(set) var toCoin: Coin? {
        didSet {
            toCoinRelay.accept(toCoin)
        }
    }
    private let toCoinRelay = PublishRelay<Coin?>()

    private(set) var fromAmount: Decimal? {
        didSet {
            fromAmountRelay.accept(fromAmount ?? 0)
        }
    }
    private let fromAmountRelay = PublishRelay<Decimal>()

    private(set) var toAmount: Decimal? {
        didSet {
            toAmountRelay.accept(toAmount ?? 0)
        }
    }
    private let toAmountRelay = PublishRelay<Decimal>()

    let changeTypeAllowed: Bool = true
    private(set) var amountType: AmountType = .exactFrom {
        didSet {
            amountTypeRelay.accept(amountType)
        }
    }
    let amountTypeRelay = PublishRelay<AmountType>()

    private var swapData: SwapData?
    private var uniswapTradeData: TradeData?

    init(uniswapKit: UniswapKit.Kit, settingsAdapterFactory: SwapSettingsAdapterFactory, evmKit: EthereumKit.Kit, fromCoin: Coin? = nil) {
        self.uniswapKit = uniswapKit
        self.settingsAdapterFactory = settingsAdapterFactory
        self.fromCoin = fromCoin

        subscribe(lastBlockDisposeBag, evmKit.lastBlockHeightObservable) { [weak self] _ in self?.syncSwapData() }
    }

    private func swapToken(coin: CoinKit.Coin) throws -> UniswapKit.Token {
        switch coin.type {
        case .erc20(let address):
            let address = try EthereumKit.Address(hex: address)
            return uniswapKit.token(contractAddress: address, decimals: coin.decimal)
        case .bep20(let address):
            let address = try EthereumKit.Address(hex: address)
            return uniswapKit.token(contractAddress: address, decimals: coin.decimal)
        case .ethereum, .binanceSmartChain: return uniswapKit.etherToken
        default: throw SwapError.invalidToken
        }
    }
    
    private func syncSwapData() {
        guard let fromCoin = fromCoin, let toCoin = toCoin else {
            state = .notReady()
            return
        }

        if swapData == nil {
            state = .loading
        }

        swapDataDisposeBag = DisposeBag()

        swapDataSingle(fromCoin: fromCoin, toCoin: toCoin)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .subscribe(onSuccess: { [weak self] swapData in
                    print("SwapData:\n\(swapData)")

                    self?.update(swapData: swapData)
                }, onError: { error in
                    print("SWAP DATA ERROR: \(error)")
                })
                .disposed(by: swapDataDisposeBag)
    }

    private func update(swapData: SwapData) {
        self.swapData = swapData
        syncTradeData()
    }

    private func swapDataSingle(fromCoin: Coin, toCoin: Coin) -> Single<SwapData> {
        do {
            let fromToken = try swapToken(coin: fromCoin)
            let toToken = try swapToken(coin: toCoin)

            return uniswapKit.swapDataSingle(tokenIn: fromToken, tokenOut: toToken)
        } catch {
            return Single.error(error)
        }
    }

    private func tradeData(swapData: SwapData, amount: Decimal, amountType: AmountType) throws -> TradeData {
        switch amountType {
        case .exactFrom: return try uniswapKit.bestTradeExactIn(swapData: swapData, amountIn: amount, options: swapTradeOptions.tradeOptions)
        case .exactTo: return try uniswapKit.bestTradeExactOut(swapData: swapData, amountOut: amount, options: swapTradeOptions.tradeOptions)
        }
    }

    private func syncTradeData() {
        guard let fromCoin = fromCoin, let toCoin = toCoin, let swapData = swapData else {
            uniswapTradeData = nil
            return
        }

        let amount = amountType == .exactFrom ? fromAmount : toAmount
        guard let amount = amount, amount != 0 else {
            state = .notReady()
            return
        }

        do {
            print("trade options: \(swapTradeOptions.recipient?.title ?? "N/A") : \(swapTradeOptions.allowedSlippage.description) : \(swapTradeOptions.ttl.description)")
            let tradeData = try tradeData(swapData: swapData, amount: amount, amountType: amountType)
            try handle(tradeData: tradeData, fromCoin: fromCoin, toCoin: toCoin)
        } catch {
            state = .notReady(errors: [error])
        }

        print("Trade data updated!")
    }

    private func handle(tradeData: TradeData, fromCoin: Coin, toCoin: Coin) throws {
        switch tradeData.type {
        case .exactIn: toAmount = tradeData.amountOut
        case .exactOut: fromAmount = tradeData.amountIn
        }

        guard let fromAmount = fromAmount, let toAmount = toAmount else {
            return
        }

        //TODO handle additionalInfo and nullable values
        var additionalTradeInfos = [AdditionalTradeInfo]()

        if let executionPrice = tradeData.executionPrice {
            let value = AdditionalTradeInfoValue.price(value: executionPrice, baseCoin: fromCoin, quoteCoin: toCoin)
            additionalTradeInfos.append(AdditionalTradeInfo(title: "swap.price".localized, value: value))
        }

        if let priceImpact = tradeData.priceImpact {
            let level: PercentageLevel
            if priceImpact >= 0, priceImpact < Self.warningPriceImpact {
                level = .normal
            } else if priceImpact >= Self.forbiddenPriceImpact {
                level = .warning
            } else {
                level = .forbidden
            }

            let value = AdditionalTradeInfoValue.percentage(percentage: priceImpact, level: level)
            additionalTradeInfos.append(AdditionalTradeInfo(title: "swap.price_impact".localized, value: value))
        }

        switch tradeData.type {
        case .exactIn:
            if let amountOutMin = tradeData.amountOutMin {
                let value = AdditionalTradeInfoValue.coinAmount(amount: amountOutMin, coin: toCoin)
                additionalTradeInfos.append(AdditionalTradeInfo(title: "swap.minimum_got".localized, value: value))
            }
        case .exactOut:
            if let amountInMax = tradeData.amountInMax {
                let value = AdditionalTradeInfoValue.coinAmount(amount: amountInMax, coin: fromCoin)
                additionalTradeInfos.append(AdditionalTradeInfo(title: "swap.maximum_paid".localized, value: value))
            }
        }

        let trade = Trade(
                fromCoin: fromCoin,
                fromAmount: fromAmount,
                toCoin: toCoin,
                toAmount: toAmount,
                additionalInfo: additionalTradeInfos)

        let transactionData = try uniswapKit.transactionData(tradeData: tradeData)
        state = .ready(trade: trade, data: transactionData)
    }

    private func amountsEqual(amount1: Decimal?, amount2: Decimal?) -> Bool {
        if amount1 == nil, amount2 == nil {
            return true
        }

        guard let amount1 = amount1, let amount2 = amount2 else {
            return false
        }

        return amount1 == amount2
    }

}

extension UniswapAdapter: ISwapAdapter {

    var swapSettingsAdapter: ISwapSettingsAdapter {
        settingsAdapterFactory.uniswapSettingsAdapter(adapter: self)
    }

    var routerAddress: EthereumKit.Address {
        uniswapKit.routerAddress
    }

    var stateObservable: Observable<SwapAdapterState> {
        stateRelay.asObservable()
    }

    func set(from: CoinKit.Coin?) {
        guard fromCoin != from else {
            return
        }

        fromCoin = from

        if amountType == .exactTo {
            fromAmount = nil
        }

        if toCoin == from {
            toCoin = nil
            toAmount = nil
        }

        swapData = nil
        syncSwapData()
    }

    var fromCoinObservable: Observable<CoinKit.Coin?> {
        fromCoinRelay.asObservable()
    }

    func set(to: CoinKit.Coin) {
        guard toCoin != to else {
            return
        }

        toCoin = to

        if amountType == .exactFrom {
            toAmount = nil
        }

        if fromCoin == toCoin {
            fromCoin = nil
            fromAmount = nil
        }

        swapData = nil
        syncSwapData()
    }

    var toCoinObservable: Observable<CoinKit.Coin?> {
        toCoinRelay.asObservable()
    }

    func set(fromAmount: Decimal?) {
        amountType = .exactFrom

        if amountsEqual(amount1: fromAmount, amount2: self.fromAmount) {
            return
        }

        self.fromAmount = fromAmount
        toAmount = nil

        syncTradeData()
    }

    var fromAmountObservable: Observable<Decimal> {
        fromAmountRelay.asObservable()
    }

    func set(toAmount: Decimal?) {
        amountType = .exactTo

        if amountsEqual(amount1: toAmount, amount2: self.toAmount) {
            return
        }

        self.toAmount = toAmount
        fromAmount = nil

        syncTradeData()
    }

    var toAmountObservable: Observable<Decimal> {
        toAmountRelay.asObservable()
    }

    var amountTypeObservable: Observable<AmountType> {
        amountTypeRelay.asObservable()
    }

    func switchCoins() {
        let swapCoin = toCoin
        toCoin = fromCoin

        set(from: swapCoin)
    }

}
