import CoinKit
import UniswapKit

class SwapAdapterFactory {
    private let swapSettingsAdapterFactory: SwapSettingsAdapterFactory

    init(swapSettingsAdapterFactory: SwapSettingsAdapterFactory) {
        self.swapSettingsAdapterFactory = swapSettingsAdapterFactory
    }

    func adapter(dex: SwapModule.DexNew, coinIn: Coin?) -> ISwapAdapter? {
        guard let evmKit = dex.evmKit else {
            return nil
        }

        switch dex.provider {
        case .uniswap, .pancake:
            return UniswapAdapter(
                    uniswapKit: UniswapKit.Kit.instance(evmKit: evmKit),
                    settingsAdapterFactory: swapSettingsAdapterFactory,
                    evmKit: evmKit,
                    fromCoin: coinIn)

        case .oneInch: fatalError()
        }
    }

}
