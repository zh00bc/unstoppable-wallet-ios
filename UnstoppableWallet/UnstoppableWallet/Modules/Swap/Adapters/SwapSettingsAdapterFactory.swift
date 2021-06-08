import CoinKit
import UniswapKit

class SwapSettingsAdapterFactory {
    private let decimalParser: IAmountDecimalParser
    private let factory: SwapSettingsViewModelFactory

    init(decimalParser: IAmountDecimalParser, factory: SwapSettingsViewModelFactory) {
        self.decimalParser = decimalParser
        self.factory = factory
    }

    func uniswapSettingsAdapter(adapter: UniswapAdapter) -> UniswapSettingsAdapter {
        let settingsAdapter = UniswapSettingsAdapter(
                swapSettingsFactory: factory,
                decimalParser: decimalParser,
                tradeOptions: adapter.swapTradeOptions)

        settingsAdapter.delegate = adapter

        return settingsAdapter
    }

}
