import Foundation
import RxSwift
import RxCocoa
import UniswapKit
import CurrencyKit
import EthereumKit

class SwapViewModelNew {
    private let disposeBag = DisposeBag()

    public let service: SwapServiceNew
    public let switchService: AmountTypeSwitchService
    public let swapAdapter: ISwapAdapter
    private let pendingAllowanceService: SwapPendingAllowanceService

    private let viewItemHelper: SwapViewItemHelper

    private var isLoadingRelay = BehaviorRelay<Bool>(value: false)
    private var swapErrorRelay = BehaviorRelay<String?>(value: nil)
    private var additionTradeInfoViewItemRelay = BehaviorRelay<[AdditionalTradeInfoViewItem]>(value: [])
    private var tradeOptionsViewItemRelay = BehaviorRelay<TradeOptionsViewItem?>(value: nil)
    private var advancedSettingsVisibleRelay = BehaviorRelay<Bool>(value: false)
    private var proceedActionRelay = BehaviorRelay<ActionState>(value: .hidden)
    private var approveActionRelay = BehaviorRelay<ActionState>(value: .hidden)
    private var openConfirmRelay = PublishRelay<SendEvmData>()

    private var openApproveRelay = PublishRelay<SwapAllowanceService.ApproveData>()

    private let scheduler = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "io.horizontalsystems.unstoppable.swap_view_model")

    init(service: SwapServiceNew, switchService: AmountTypeSwitchService, swapAdapter: ISwapAdapter, pendingAllowanceService: SwapPendingAllowanceService, viewItemHelper: SwapViewItemHelper) {
        self.service = service
        self.switchService = switchService
        self.swapAdapter = swapAdapter
        self.pendingAllowanceService = pendingAllowanceService
        self.viewItemHelper = viewItemHelper

        subscribeToService()

        sync(state: service.state)
        sync(errors: service.errors)
        sync(adapterState: swapAdapter.state)
    }

    private func subscribeToService() {
        subscribe(scheduler, disposeBag, service.stateObservable) { [weak self] in self?.sync(state: $0) }
        subscribe(scheduler, disposeBag, service.errorsObservable) { [weak self] in self?.sync(errors: $0) }
        subscribe(scheduler, disposeBag, swapAdapter.stateObservable) { [weak self] in self?.sync(adapterState: $0) }
//        subscribe(scheduler, disposeBag, swapAdapter.swapTradeOptionsObservable) { [weak self] in self?.sync(swapTradeOptions: $0) }
        subscribe(scheduler, disposeBag, pendingAllowanceService.isPendingObservable) { [weak self] in self?.sync(isApprovePending: $0) }
    }

    private func sync(state: SwapServiceNew.State? = nil) {
        let state = state ?? service.state

        isLoadingRelay.accept(state == .loading)
        syncProceedAction()
    }

    private func sync(errors: [Error]? = nil) {
        let errors = errors ?? service.errors

        let filtered = errors.filter { error in
            switch error {
            case let error as UniswapKit.Kit.TradeError: return error != .zeroAmount
            case _ as EvmTransactionService.GasDataError: return false
            case _ as SwapService.SwapError: return false
            default: return true
            }
        }

        swapErrorRelay.accept(filtered.first?.convertedError.smartDescription)

        syncApproveAction()
        syncProceedAction()
    }

    private func sync(adapterState: SwapAdapterState) {
        switch adapterState {
        case .ready(let trade, _):
            additionTradeInfoViewItemRelay.accept(additionalTradeInfoViewItems(trade: trade))
            advancedSettingsVisibleRelay.accept(true)
        default:
            additionTradeInfoViewItemRelay.accept([])
            advancedSettingsVisibleRelay.accept(false)
        }

        syncProceedAction()
        syncApproveAction()
    }

    private func sync(swapTradeOptions: SwapTradeOptions) {
        tradeOptionsViewItemRelay.accept(tradeOptionsViewItem(swapTradeOptions: swapTradeOptions))
    }

    private func sync(isApprovePending: Bool) {
        syncProceedAction()
        syncApproveAction()
    }

    private func syncProceedAction() {
        if case .ready = service.state {
            proceedActionRelay.accept(.enabled(title: "swap.proceed_button".localized))
        } else if case .ready = swapAdapter.state {
            if service.errors.contains(where: { .insufficientBalanceIn == $0 as? SwapService.SwapError }) {
                proceedActionRelay.accept(.disabled(title: "swap.button_error.insufficient_balance".localized))
            } else if service.errors.contains(where: { .forbiddenPriceImpactLevel == $0 as? SwapService.SwapError }) {
                proceedActionRelay.accept(.disabled(title: "swap.button_error.impact_too_high".localized))
            } else if pendingAllowanceService.isPending == true {
                proceedActionRelay.accept(.hidden)
            } else {
                proceedActionRelay.accept(.disabled(title: "swap.proceed_button".localized))
            }
        } else {
            proceedActionRelay.accept(.hidden)
        }
    }

    private func syncApproveAction() {
        if case .ready = swapAdapter.state {
            if service.errors.contains(where: { .insufficientBalanceIn == $0 as? SwapService.SwapError || .forbiddenPriceImpactLevel == $0 as? SwapService.SwapError }) {
                approveActionRelay.accept(.hidden)
            } else if pendingAllowanceService.isPending == true {
                approveActionRelay.accept(.disabled(title: "swap.approving_button".localized))
            } else if service.errors.contains(where: { .insufficientAllowance == $0 as? SwapService.SwapError }) {
                approveActionRelay.accept(.enabled(title: "button.approve".localized))
            } else {
                approveActionRelay.accept(.hidden)
            }
        } else {
            approveActionRelay.accept(.hidden)
        }
    }

    private func additionalTradeInfoViewItems(trade: Trade) -> [AdditionalTradeInfoViewItem] {
        trade.additionalInfo.flatMap { info -> AdditionalTradeInfoViewItem? in
            switch info.value {
            case let .price(value: value, baseCoin: baseCoin, quoteCoin: quoteCoin):
                let price = viewItemHelper.priceValue(executionPrice: value, coinIn: baseCoin, coinOut: quoteCoin)
                return price.map { AdditionalTradeInfoViewItem.textViewItem(title: info.title, text: $0.formattedString) }
            case let .percentage(percentage: percentage, level: level):
                let value = viewItemHelper.percentage(percentage: percentage, level: level, minLevel: .warning)
                let colorType = AdditionalTradeInfoColor.color(level)
                return value.map { AdditionalTradeInfoViewItem.textViewItem(title: info.title, text: $0, color: colorType)}
            case let .coinAmount(amount: amount, coin: coin):
                let coinAmount = viewItemHelper.coinAmount(amount: amount, coin: coin)
                return AdditionalTradeInfoViewItem.textViewItem(title: info.title, text: coinAmount)
            case .swapRoute:
                return nil //skip for now
            }
        }
    }

    private func tradeOptionsViewItem(swapTradeOptions: SwapTradeOptions) -> TradeOptionsViewItem {
        TradeOptionsViewItem(slippage: viewItemHelper.slippage(swapTradeOptions.allowedSlippage),
                deadline: viewItemHelper.deadline(swapTradeOptions.ttl),
                recipient: swapTradeOptions.recipient?.title)
    }

}

extension SwapViewModelNew {

    var isLoadingDriver: Driver<Bool> {
        isLoadingRelay.asDriver()
    }

    var swapErrorDriver: Driver<String?> {
        swapErrorRelay.asDriver()
    }

    var additionTradeInfoDriver: Driver<[SwapViewModelNew.AdditionalTradeInfoViewItem]> {
        additionTradeInfoViewItemRelay.asDriver()
    }

    var tradeOptionsViewItemDriver: Driver<TradeOptionsViewItem?> {
        tradeOptionsViewItemRelay.asDriver()
    }

    var advancedSettingsVisibleDriver: Driver<Bool> {
        advancedSettingsVisibleRelay.asDriver()
    }

    var proceedActionDriver: Driver<ActionState> {
        proceedActionRelay.asDriver()
    }

    var approveActionDriver: Driver<ActionState> {
        approveActionRelay.asDriver()
    }

    var openApproveSignal: Signal<SwapAllowanceService.ApproveData> {
        openApproveRelay.asSignal()
    }

    var openConfirmSignal: Signal<SendEvmData> {
        openConfirmRelay.asSignal()
    }

    func onTapSwitch() {
        swapAdapter.switchCoins()
    }

    func onTapApprove() {
        guard let approveData = service.approveData else {
            return
        }

        openApproveRelay.accept(approveData)
    }

    func didApprove() {
        pendingAllowanceService.syncAllowance()
    }

    func onTapProceed() {
//        guard case .ready(let transactionData) = service.state else {
//            return
//        }
//
//        guard case let .ready(trade) = swapAdapter.state else {
//            return
//        }
//
//        let swapInfo = SendEvmData.SwapInfo(
//                estimatedOut: swapAdapter.fromAmount,
//                estimatedIn: swapAdapter.toAmount,
//                slippage: viewItemHelper.slippage(swapAdapter.swapTradeOptions.allowedSlippage),
//                deadline: viewItemHelper.deadline(swapAdapter.swapTradeOptions.ttl),
//                recipientDomain: swapAdapter.swapTradeOptions.recipient?.domain,
//                price: viewItemHelper.priceValue(executionPrice: trade.tradeData.executionPrice, coinIn: swapAdapter.coinIn, coinOut: swapAdapter.coinOut)?.formattedString,
//                priceImpact: viewItemHelper.percentage(trade: trade)?.value
//        )
//
//        openConfirmRelay.accept(SendEvmData(transactionData: transactionData, additionalInfo: .swap(info: swapInfo)))
    }

}

extension SwapViewModelNew {

    enum AdditionalTradeInfoColor {
        case normal
        case warning
        case forbidden

        static func color(_ level: PercentageLevel) -> Self {
            switch level {
            case .normal: return .normal
            case .warning: return .warning
            case .forbidden: return .forbidden
            }
        }
    }

    enum AdditionalTradeInfoViewItem {
        case textViewItem(title: String, text: String, color: AdditionalTradeInfoColor = .normal)
    }

    struct TradeOptionsViewItem {
        let slippage: String?
        let deadline: String?
        let recipient: String?
    }

    enum ActionState {
        case hidden
        case enabled(title: String)
        case disabled(title: String)
    }

}
