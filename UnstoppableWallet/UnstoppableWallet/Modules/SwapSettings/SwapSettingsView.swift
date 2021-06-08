import ThemeKit
import RxSwift
import RxCocoa
import SectionsTableView
import ComponentKit
import UIKit

class SwapSettingsView: ThemeViewController {
    private let disposeBag = DisposeBag()
    private var settingsDisposeBag = DisposeBag()

    private let viewModel: SwapSettingsViewModel
//    private let slippageViewModel: SwapSlippageViewModel
//    private let deadlineViewModel: SwapDeadlineViewModel

    private let tableView = SectionsTableView(style: .grouped)

//    private let recipientCell: RecipientAddressInputCell
//    private let recipientCautionCell: RecipientAddressCautionCell

//    private let slippageCell = ShortcutInputCell()
//    private let slippageCautionCell = FormCautionCell()
//
//    private let deadlineCell = ShortcutInputCell()

    private var settingsSections = [SectionProtocol]()

    private let buttonCell = ButtonCell(style: .default, reuseIdentifier: nil)

    init(viewModel: SwapSettingsViewModel) {
        self.viewModel = viewModel

//        recipientCell = RecipientAddressInputCell(viewModel: recipientViewModel)
//        recipientCautionCell = RecipientAddressCautionCell(viewModel: recipientViewModel)

        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "swap.advanced_settings".localized
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "button.cancel".localized, style: .plain, target: self, action: #selector(didTapCancel))

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .onDrag
        tableView.sectionDataSource = self

        tableView.registerHeaderFooter(forClass: SubtitleHeaderFooterView.self)
        tableView.registerHeaderFooter(forClass: BottomDescriptionHeaderFooterView.self)

//        recipientCell.onChangeHeight = { [weak self] in self?.reloadTable() }
//        recipientCell.onOpenViewController = { [weak self] in self?.present($0, animated: true) }

//        recipientCautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

        buttonCell.bind(style: .primaryYellow, title: "button.apply".localized) { [weak self] in
            self?.didTapApply()
        }

        subscribe(disposeBag, viewModel.actionDriver) { [weak self] actionState in
            switch actionState {
            case .enabled:
                self?.buttonCell.isEnabled = true
                self?.buttonCell.title = "button.apply".localized
            case .disabled(let title):
                self?.buttonCell.isEnabled = false
                self?.buttonCell.title = title
            }
        }

        syncSettingsItems()
        tableView.buildSections()
    }

    private func syncSettingsItems() {
        let disposeBag = DisposeBag()
        settingsSections = viewModel.settingsItems.compactMap { section(for: $0, disposeBag: disposeBag)  }

        settingsDisposeBag = disposeBag
    }

    @objc private func didTapApply() {
        if viewModel.doneDidTap() {
            dismiss(animated: true)
        } else {
            HudHelper.instance.showError(title: "alert.unknown_error".localized)
        }
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    private func header(hash: String, text: String?) -> ViewState<SubtitleHeaderFooterView> {
        guard let text = text else {
            return .margin(height: 0)
        }

        return .cellType(
                hash: hash,
                binder: { view in
                    view.bind(text: text)
                },
                dynamicHeight: { _ in
                    SubtitleHeaderFooterView.height
                }
        )
    }

    private func footer(hash: String, text: String?) -> ViewState<BottomDescriptionHeaderFooterView> {
        guard let text = text else {
            return .margin(height: 0)
        }

        return .cellType(
                hash: hash,
                binder: { view in
                    view.bind(text: text)
                },
                dynamicHeight: { width in
                    BottomDescriptionHeaderFooterView.height(containerWidth: width, text: text)
                }
        )
    }

    private func section(for item: ISwapSettingsViewModel, disposeBag: DisposeBag) -> SectionProtocol? {
        switch item {
        case let item as ISwapDecimalSettingsViewModel:
            let inputCell = ShortcutInputCell()

            inputCell.inputPlaceholder = item.placeholder
            inputCell.inputText = item.initialValue
            inputCell.set(shortcuts: item.shortcuts)
            inputCell.keyboardType = .decimalPad     // todo : variant
            inputCell.onChangeText = { [weak item] text in item?.onChange(text: text) }
            inputCell.isValidText = { [weak item] text in item?.isValid(text: text) ?? true }
            inputCell.onChangeHeight = { [weak self] in self?.reloadTable() }

            let inputRow = StaticRow(
                    cell: inputCell,
                    id: "\(item.id)-row",
                    dynamicHeight: { [weak inputCell] width in
                        inputCell?.height(containerWidth: width) ?? 0
                    }
            )

            let cautionCell = FormCautionCell()
            cautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

            let cautionRow = StaticRow(
                    cell: cautionCell,
                    id: "\(item.id)-caution",
                    dynamicHeight: { [weak cautionCell] width in
                        cautionCell?.height(containerWidth: width) ?? 0
                    }
            )

            subscribe(disposeBag, item.cautionDriver) { [weak cautionCell, weak inputCell] in
                inputCell?.set(cautionType: $0?.type)
                cautionCell?.set(caution: $0)
            }

            return Section(
                    id: "\(item.id)-section",
                    headerState: header(hash: "\(item.id)_header", text: item.header),
                    footerState: footer(hash: "\(item.id)_footer", text: item.footer),
                    rows: [inputRow, cautionRow]
            )

        case let item as ISwapAddressSettingsViewModel:
            let inputCell = RecipientAddressInputCellNew(viewModel: item)

            inputCell.onChangeHeight = { [weak self] in self?.reloadTable() }
            inputCell.onOpenViewController = { [weak self] in self?.present($0, animated: true) }

            let inputRow = StaticRow(
                    cell: inputCell,
                    id: "\(item.id)-row",
                    dynamicHeight: { [weak inputCell] width in
                        inputCell?.height(containerWidth: width) ?? 0
                    }
            )

            let cautionCell = FormCautionCell()
            subscribe(disposeBag, item.cautionDriver) { [weak cautionCell] in cautionCell?.set(caution: $0) }

            cautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

            let cautionRow = StaticRow(
                    cell: cautionCell,
                    id: "\(item.id)-caution",
                    dynamicHeight: { [weak cautionCell] width in
                        cautionCell?.height(containerWidth: width) ?? 0
                    }
            )

            return Section(
                    id: "\(item.id)-section",
                    headerState: header(hash: "\(item.id)_header", text: item.header),
                    footerState: footer(hash: "\(item.id)_footer", text: item.footer),
                    rows: [inputRow, cautionRow]
            )
        case let item as ISwapBooleanSettingsViewModel: return nil
        default: return nil
        }
    }

    private func reloadTable() {
        UIView.animate(withDuration: 0.2) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

}

extension SwapSettingsView: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        var sections: [SectionProtocol] =
        [
            Section(
                    id: "top-margin",
                    headerState: .margin(height: .margin12)
            )
        ]

        sections.append(contentsOf: settingsSections)
        sections.append(
                Section(
                    id: "button",
                    rows: [
                        StaticRow(
                                cell: buttonCell,
                                id: "button",
                                height: ButtonCell.height(style: .primaryYellow)
                        )
                    ]
            ))

        return sections
    }

}
