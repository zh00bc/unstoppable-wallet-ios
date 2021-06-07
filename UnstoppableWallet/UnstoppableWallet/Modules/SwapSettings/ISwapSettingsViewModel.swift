import RxCocoa

protocol ISwapSettingsViewModel: class {
    var id: String { get }
    var header: String? { get }
    var footer: String? { get }
}

extension ISwapSettingsViewModel {
    var header: String? { nil }
    var footer: String? { nil }
}

protocol ISwapBooleanSettingsViewModel: ISwapSettingsViewModel {
    var title: String? { get }
    func onChange(value: Bool)
}

protocol ISwapEditableSettingsViewModel: ISwapSettingsViewModel {
    var placeholder: String? { get }

    func onChange(text: String?)

    var cautionDriver: Driver<Caution?> { get }
}

extension ISwapEditableSettingsViewModel {
    var placeholder: String? { nil }
}

protocol ISwapDecimalSettingsViewModel: ISwapEditableSettingsViewModel {
    var initialValue: String? { get }
    var shortcuts: [InputShortcut] { get }

    func isValid(text: String) -> Bool
}

protocol ISwapAddressSettingsViewModel: ISwapEditableSettingsViewModel {
    var initialAddress: Address? { get }
    var isLoadingDriver: Driver<Bool> { get }

    var setTextSignal: Signal<String?> { get }

    func onFetch(text: String?)
    func onChange(editing: Bool)
}
