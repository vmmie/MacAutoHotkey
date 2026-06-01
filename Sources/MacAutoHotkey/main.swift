import Foundation

let cli = CommandLineInterface()
do {
    try cli.run(arguments: CommandLine.arguments)
} catch let error as AHKError {
    fputs("macahk: \(error.message)\n", stderr)
    exit(1)
} catch {
    fputs("macahk: \(error.localizedDescription)\n", stderr)
    exit(1)
}
