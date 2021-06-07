import UIKit
import RxSwift

class RecipientAddressInputCellNew: AddressInputCell {
    private let viewModel: ISwapAddressSettingsViewModel
    private let disposeBag = DisposeBag()

    init(viewModel: ISwapAddressSettingsViewModel) {
        self.viewModel = viewModel

        super.init()

        inputPlaceholder = viewModel.placeholder
        inputText = viewModel.initialAddress?.title
        onChangeText = { [weak self] in self?.viewModel.onChange(text: $0) }
        onFetchText = { [weak self] in self?.viewModel.onFetch(text: $0) }
        onChangeEditing = { [weak self] in self?.viewModel.onChange(editing: $0) }

        subscribe(disposeBag, viewModel.cautionDriver) { [weak self] in
            self?.set(cautionType: $0?.type)
        }
        subscribe(disposeBag, viewModel.isLoadingDriver) { [weak self] in
            self?.set(isLoading: $0)
        }
        subscribe(disposeBag, viewModel.setTextSignal) { [weak self] in
            self?.inputText = $0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
