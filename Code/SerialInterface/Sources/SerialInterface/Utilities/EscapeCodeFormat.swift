enum EscapeCodeFormat: String {
  case bold = "1"
  case black = "30"
  case red = "31"
  case green = "32"
  case yellow = "33"
  case blue = "34"
  case magenta = "35"
  case cyan = "36"
  case white = "37"
  
  static let reset = "\u{001B}[0m"
  
  func apply(to text: String) -> String {
    return "\u{001B}[\(self.rawValue)m\(text)\(Self.reset)"
  }
}
