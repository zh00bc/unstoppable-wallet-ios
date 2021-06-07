import Foundation
import EthereumKit
import RxSwift
import RxRelay
import CoinKit

class SwapAllowanceService {
    private let swapAdapterManager: SwapAdapterManager
    private let adapterManager: IAdapterManager

    private var coin: Coin?

    private let disposeBag = DisposeBag()
    private var lastBlockDisposeBag = DisposeBag()
    private var allowanceDisposeBag = DisposeBag()

    private let stateRelay = PublishRelay<State?>()
    private(set) var state: State? {
        didSet {
            if oldValue != state {
                stateRelay.accept(state)
            }
        }
    }

    init(swapAdapterManager: SwapAdapterManager, adapterManager: IAdapterManager) {
        self.swapAdapterManager = swapAdapterManager
        self.adapterManager = adapterManager

        subscribe(disposeBag, swapAdapterManager.onUpdateProviderObservable) { [weak self] _ in self?.subscribeEvmKit() }
        subscribeEvmKit()
    }

    private func subscribeEvmKit() {
        lastBlockDisposeBag = DisposeBag()

        swapAdapterManager.dex.evmKit.map { subscribe(ConcurrentDispatchQueueScheduler(qos: .userInitiated), lastBlockDisposeBag, $0.lastBlockHeightObservable) { [weak self] _ in
                self?.sync()
            }
        }
    }

    private func sync() {
        allowanceDisposeBag = DisposeBag()

        guard let coin = coin, let adapter = adapterManager.adapter(for: coin) as? IEip20Adapter else {
            state = nil
            return
        }

        if let state = state, case .ready = state {
            // no need to set loading, simply update to new allowance value
        } else {
            state = .loading
        }

        adapter
                .allowanceSingle(spenderAddress: swapAdapterManager.routerAddress, defaultBlockParameter: .latest)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .subscribe(onSuccess: { [weak self] allowance in
                    self?.state = .ready(allowance: CoinValue(coin: coin, value: allowance))
                }, onError: { [weak self] error in
                    self?.state = .notReady(error: error)
                })
                .disposed(by: allowanceDisposeBag)
    }

}

extension SwapAllowanceService {

    var stateObservable: Observable<State?> {
        stateRelay.asObservable()
    }

    func set(coin: Coin?) {
        self.coin = coin
        sync()
    }

    func approveData(amount: Decimal) -> ApproveData? {
        guard case .ready(let allowance) = state else {
            return nil
        }

        guard let coin = coin else {
            return nil
        }

        return ApproveData(
                dex: swapAdapterManager.dex,
                coin: coin,
                spenderAddress: swapAdapterManager.routerAddress,
                amount: amount,
                allowance: allowance.value
        )
    }

}

extension SwapAllowanceService {

    enum State: Equatable {
        case loading
        case ready(allowance: CoinValue)
        case notReady(error: Error)

        static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.ready(let lhsAllowance), .ready(let rhsAllowance)): return lhsAllowance == rhsAllowance
            default: return false
            }
        }
    }

    struct ApproveData {
        let dex: SwapModule.DexNew
        let coin: Coin
        let spenderAddress: EthereumKit.Address
        let amount: Decimal
        let allowance: Decimal
    }

}
