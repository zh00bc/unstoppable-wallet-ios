import RxSwift
import RxCocoa

class SwapSettingsViewModel {
    private let disposeBag = DisposeBag()

    private let swapSettingsAdapter: ISwapSettingsAdapter

    private let actionRelay = BehaviorRelay<ActionState>(value: .enabled)

    init(swapSettingsAdapter: ISwapSettingsAdapter) {
        self.swapSettingsAdapter = swapSettingsAdapter

        swapSettingsAdapter.stateObservable
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .subscribe(onNext: { [weak self] _ in
                    self?.syncAction()
                })
                .disposed(by: disposeBag)
    }

    private func syncAction() {
        switch swapSettingsAdapter.state {
        case .valid:
            actionRelay.accept(.enabled)
        case let .invalid(cause: text):
            guard let text = text else {
                return
            }

            actionRelay.accept(.disabled(title: text))
        }
    }

}

extension SwapSettingsViewModel {

    var settingsItems: [ISwapSettingsViewModel] {
        swapSettingsAdapter.settingsItems
    }

    public var actionDriver: Driver<ActionState> {
        actionRelay.asDriver()
    }

    public func doneDidTap() -> Bool {
        if case .valid = swapSettingsAdapter.state {
            swapSettingsAdapter.applySettings()
            return true
        }
        return false
    }

}

extension SwapSettingsViewModel {

    enum ActionState {
        case enabled
        case disabled(title: String)
    }

}
