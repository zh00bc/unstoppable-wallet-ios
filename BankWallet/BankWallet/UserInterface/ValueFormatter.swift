import Foundation

class ValueFormatter {
    static let instance = ValueFormatter()

    private let coinFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        formatter.roundingMode = .ceiling
        return formatter
    }()

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.roundingMode = .ceiling
        return formatter
    }()

    func format(coinValue: CoinValue, explicitSign: Bool = false) -> String? {
        let value = explicitSign ? abs(coinValue.value) : coinValue.value

        guard let formattedValue = coinFormatter.string(from: value as NSNumber) else {
            return nil
        }

        var result = "\(formattedValue) \(coinValue.coin)"

        if explicitSign {
            let sign = coinValue.value < 0 ? "-" : "+"
            result = "\(sign) \(result)"
        }

        return result
    }

    func format(currencyValue: CurrencyValue, approximate: Bool = false) -> String? {
        let formatter = currencyFormatter
        formatter.locale = Locale(identifier: currencyValue.currency.localeId)
        formatter.maximumFractionDigits = approximate ? 0 : 2

        var value = currencyValue.value

        if approximate {
            value = abs(value)
        }

        guard var result = formatter.string(from: value as NSNumber) else {
            return nil
        }

        if approximate {
            result = "~ \(result)"
        }

        return result
    }

}
