/// The resource or cost category represented by one Resources row.
enum CloudTreeMachineResourceMetric: String, Equatable {
    case cpu
    case memory
    case disk
    case usage

    /// The SF Symbol shown in the row's icon slot, so readings sit on the same
    /// grid as terminal, display, and port rows.
    var symbolName: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .usage: return "dollarsign.circle"
        }
    }
}
