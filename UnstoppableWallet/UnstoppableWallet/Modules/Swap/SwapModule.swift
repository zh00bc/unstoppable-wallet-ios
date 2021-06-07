import Foundation
import RxSwift
import RxCocoa
import UniswapKit
import EthereumKit
import ThemeKit
import CurrencyKit
import BigInt
import CoinKit

//TODO: move to another place
func subscribe<T>(_ disposeBag: DisposeBag, _ driver: Driver<T>, _ onNext: ((T) -> Void)? = nil) {
    driver.drive(onNext: onNext).disposed(by: disposeBag)
}

func subscribe<T>(_ disposeBag: DisposeBag, _ signal: Signal<T>, _ onNext: ((T) -> Void)? = nil) {
    signal.emit(onNext: onNext).disposed(by: disposeBag)
}

func subscribe<T>(_ disposeBag: DisposeBag, _ observable: Observable<T>, _ onNext: ((T) -> Void)? = nil) {
    observable
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .subscribe(onNext: onNext)
            .disposed(by: disposeBag)
}

func subscribe<T>(_ scheduler: ImmediateSchedulerType, _ disposeBag: DisposeBag, _ observable: Observable<T>, _ onNext: ((T) -> Void)? = nil) {
    observable
            .observeOn(scheduler)
            .subscribe(onNext: onNext)
            .disposed(by: disposeBag)
}

struct SwapModule {

    struct ConfirmationAdditionalViewItem {
        let title: String
        let value: String?
    }

    struct ConfirmationAmountViewItem {
        let payTitle: String
        let payValue: String?
        let getTitle: String
        let getValue: String?
    }

    struct PriceImpactViewItem {
        let value: String
        let level: SwapTradeService.PriceImpactLevel
    }

    struct GuaranteedAmountViewItem {
        let title: String
        let value: String
    }

//    static func viewController(coinIn: Coin) -> UIViewController? {
//        switch coinIn.type {
//        case .ethereum, .erc20: return viewController(coinIn: coinIn)
//        case .binanceSmartChain, .bep20: return viewController(dex: .pancake, coinIn: coinIn)
//        default: return nil
//        }
//    }

    static func viewController(coinIn: Coin? = nil) -> UIViewController? {
        guard let swapAdapterManager = SwapAdapterManager(
                localStorage: App.shared.localStorage,
//                resolutionService: AddressResolutionService(coinCode: ethereumCoin.code),
//                addressParser: AddressParserFactory().parser(coin: ethereumCoin),
                decimalParser: AmountDecimalParser(),
                initialFromCoin: coinIn
        ) else {
            return nil      // for all not eip20 tokens
        }

        let allowanceService = SwapAllowanceService(
                swapAdapterManager: swapAdapterManager,
                adapterManager: App.shared.adapterManager
        )
        let pendingAllowanceService = SwapPendingAllowanceService(
                adapterManager: App.shared.adapterManager,
                allowanceService: allowanceService
        )

        let swapServiceNew = SwapServiceNew(
                swapAdapterManager: swapAdapterManager,
                allowanceService: allowanceService,
                pendingAllowanceService: pendingAllowanceService,
                adapterManager: App.shared.adapterManager
        )

        let allowanceViewModel = SwapAllowanceViewModel(service: swapServiceNew, allowanceService: allowanceService, pendingAllowanceService: pendingAllowanceService)

        let viewModelNew = SwapViewModelNew(service: swapServiceNew,
                switchService: AmountTypeSwitchService(),
                swapAdapterManager: swapAdapterManager,
                pendingAllowanceService: pendingAllowanceService,
                viewItemHelper: SwapViewItemHelper())

        let viewControllerNew = SwapViewControllerNew(
                viewModel: viewModelNew,
                allowanceViewModel: allowanceViewModel
        )

        return ThemeNavigationController(rootViewController: viewControllerNew)
    }

}

extension SwapModule {

    enum Dex {
        case uniswap
        case oneInchEth
        case pancake
        case oneInchBsc

        var evmKit: EthereumKit.Kit? {
            switch self {
            case .uniswap, .oneInchEth: return App.shared.ethereumKitManager.evmKit
            case .pancake, .oneInchBsc: return App.shared.binanceSmartChainKitManager.evmKit
            }
        }

        var coin: Coin? {
            switch self {
            case .uniswap, .oneInchEth: return App.shared.coinKit.coin(type: .ethereum)
            case .pancake, .oneInchBsc: return App.shared.coinKit.coin(type: .binanceSmartChain)
            }
        }

    }

    class DexNew {

        var blockchain: Blockchain {
            didSet {
                if !blockchain.allowedProviders.contains(provider) {
                    provider = blockchain.allowedProviders[0]
                }
            }
        }

        var provider: Provider {
            didSet {
                if !provider.allowedBlockchains.contains(blockchain) {
                    blockchain = provider.allowedBlockchains[0]
                }
            }
        }

        init(blockchain: Blockchain, provider: Provider) {
            self.blockchain = blockchain
            self.provider = provider
        }

        var evmKit: EthereumKit.Kit? {
            switch blockchain {
            case .ethereum: return App.shared.ethereumKitManager.evmKit
            case .binanceSmartChain: return App.shared.binanceSmartChainKitManager.evmKit
            }
        }

        var coin: Coin? {
            switch blockchain {
            case .ethereum: return App.shared.coinKit.coin(type: .ethereum)
            case .binanceSmartChain: return App.shared.coinKit.coin(type: .binanceSmartChain)
            }
        }

    }

}

extension SwapModule.DexNew {

    enum Blockchain: String {
        case ethereum
        case binanceSmartChain

        var allowedProviders: [Provider] {
            switch self {
            case .ethereum: return [.uniswap, .oneInch]
            case .binanceSmartChain: return [.pancake, .oneInch]
            }
        }

    }

    enum Provider: String {
        case uniswap
        case oneInch
        case pancake

        var allowedBlockchains: [Blockchain] {
            switch self {
            case .oneInch: return [.ethereum, .binanceSmartChain]
            case .uniswap: return [.ethereum]
            case .pancake: return [.binanceSmartChain]
            }
        }

    }

}

extension UniswapKit.Kit.TradeError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .tradeNotFound: return "swap.trade_error.not_found".localized
        default: return nil
        }
    }

}
