import Foundation

// MARK: - tuple applying

func apply<Input, Output>(_ function: (Input) -> Output, _ tuple: Input) -> Output {
    function(tuple)
}

precedencegroup TupleApplyingPrecedence {
    higherThan: CastingPrecedence
    lowerThan: RangeFormationPrecedence
    associativity: left
}

infix operator <-: TupleApplyingPrecedence
func <- <Input, Output>(function: (Input) -> Output, tuple: Input) -> Output {
    apply(function, tuple)
}
