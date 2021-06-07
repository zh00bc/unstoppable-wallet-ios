import Foundation
import RxRelay
import RxSwift
import CoinKit
import EthereumKit
import UniswapKit

class SwapAdapterManager {
    private static func defaultProvider(localStorage: ILocalStorage, blockchain: SwapModule.DexNew.Blockchain) -> SwapModule.DexNew.Provider {
        localStorage.defaultProvider(blockchain: blockchain)
    }

    private let localStorage: ILocalStorage
    private let decimalParser: IAmountDecimalParser

    private(set) var currentProvider: SwapModule.DexNew.Provider

    private(set) var swapAdapter: ISwapAdapter
    private(set) var swapSettingsAdapter: ISwapSettingsAdapter
    private(set) var dex: SwapModule.DexNew

    private let ethereumCoin: Coin

    private let onUpdateProviderRelay = PublishRelay<()>()

    init?(localStorage: ILocalStorage, decimalParser: IAmountDecimalParser, initialFromCoin: Coin? = nil) {
        guard let ethereumCoin = App.shared.coinKit.coin(type: .ethereum) else {
            return nil
        }
        self.ethereumCoin = ethereumCoin

        self.localStorage = localStorage
        self.decimalParser = decimalParser

        let blockchain: SwapModule.DexNew.Blockchain
        switch initialFromCoin?.type {
        case .ethereum, .erc20: blockchain = .ethereum
        case .binanceSmartChain, .bep20: blockchain = .binanceSmartChain
        case nil: blockchain = .ethereum
        default: return nil
        }

        currentProvider = Self.defaultProvider(localStorage: localStorage, blockchain: blockchain)
        dex = SwapModule.DexNew(blockchain: blockchain, provider: currentProvider)

        guard let evmKit = dex.evmKit else {
            return nil
        }

        switch currentProvider {
        case .uniswap, .pancake:
            swapAdapter = Self.swapAdapter(evmKit: evmKit, provider: currentProvider, coinIn: initialFromCoin)
            swapSettingsAdapter = Self.swapSettingsAdapter(coin: ethereumCoin, provider: currentProvider, decimalParser: decimalParser)
        case .oneInch: fatalError()
        }

    }

    private func updateProvider() {
        dex = SwapModule.DexNew(blockchain: dex.blockchain, provider: currentProvider)
        guard let evmKit = dex.evmKit else {
            return
        }

        // todo: need to configure adapters
        switch currentProvider {
        case .uniswap, .pancake:
            swapAdapter = Self.swapAdapter(evmKit: evmKit, provider: currentProvider, coinIn: nil) // todo: set right coin
            swapSettingsAdapter = Self.swapSettingsAdapter(coin: ethereumCoin, provider: currentProvider, decimalParser: decimalParser)
        case .oneInch: fatalError()
        }

        onUpdateProviderRelay.accept(())
    }

    //todo: move to factory
    private static func swapAdapter(evmKit: EthereumKit.Kit, provider: SwapModule.DexNew.Provider, coinIn: Coin?) -> ISwapAdapter {
        switch provider {
        case .uniswap, .pancake:
            return UniswapAdapter(
                    uniswapKit: UniswapKit.Kit.instance(evmKit: evmKit),
                    evmKit: evmKit,
                    fromCoin: coinIn)
        case .oneInch: fatalError()
        }
    }

    //todo: move to factory
    private static func swapSettingsAdapter(coin: Coin, provider: SwapModule.DexNew.Provider, decimalParser: IAmountDecimalParser) -> ISwapSettingsAdapter {
        switch provider {
        case .uniswap, .pancake:
            return UniswapSettingsAdapter(
                    resolutionService: AddressResolutionService(coinCode: coin.code),
                    addressParser: AddressParserFactory().parser(coin: coin),
                    decimalParser: decimalParser,
                    tradeOptions: SwapTradeOptions())
        case .oneInch: fatalError()
        }
    }

}

extension SwapAdapterManager {

    var routerAddress: EthereumKit.Address {
        swapAdapter.routerAddress
    }

    var onUpdateProviderObservable: Observable<()> {
        onUpdateProviderRelay.asObservable()
    }

    func set(currentProvider: SwapModule.DexNew.Provider) {
        guard currentProvider != self.currentProvider else {
            return
        }

        self.currentProvider = currentProvider
        updateProvider()
    }

}
