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
    private let swapAdapterFactory: SwapAdapterFactory

    private(set) var swapAdapter: ISwapAdapter
    var swapSettingsAdapter: ISwapSettingsAdapter { swapAdapter.swapSettingsAdapter }
    private(set) var dex: SwapModule.DexNew

    private let onUpdateProviderRelay = PublishRelay<()>()

    init?(localStorage: ILocalStorage, swapAdapterFactory: SwapAdapterFactory, initialFromCoin: Coin? = nil) {
        self.swapAdapterFactory = swapAdapterFactory
        self.localStorage = localStorage

        let blockchain: SwapModule.DexNew.Blockchain
        switch initialFromCoin?.type {
        case .ethereum, .erc20: blockchain = .ethereum
        case .binanceSmartChain, .bep20: blockchain = .binanceSmartChain
        case nil: blockchain = .ethereum
        default: return nil
        }

        let currentProvider = Self.defaultProvider(localStorage: localStorage, blockchain: blockchain)
        dex = SwapModule.DexNew(blockchain: blockchain, provider: currentProvider)

        guard let adapter = swapAdapterFactory.adapter(dex: dex, coinIn: initialFromCoin) else {
            return nil
        }

        swapAdapter = adapter
    }

    private func update(provider: SwapModule.DexNew.Provider) {
        dex = SwapModule.DexNew(blockchain: dex.blockchain, provider: provider)

        // todo: need to configure adapters
        guard let adapter = swapAdapterFactory.adapter(dex: dex, coinIn: nil) else {
            return
        }

        swapAdapter = adapter
        onUpdateProviderRelay.accept(())
    }

}

extension SwapAdapterManager {

    var routerAddress: EthereumKit.Address {
        swapAdapter.routerAddress
    }

    var onUpdateProviderObservable: Observable<()> {
        onUpdateProviderRelay.asObservable()
    }

    func set(provider: SwapModule.DexNew.Provider) {
        guard provider != dex.provider else {
            return
        }

        update(provider: provider)
    }

}
