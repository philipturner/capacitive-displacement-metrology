extension String {
    // Escape character prefix
    private var esc: String { "\u{001B}[" }
    
    // Foreground colors
    var red: String     { "\(esc)31m\(self)\(esc)0m" }
    var green: String   { "\(esc)32m\(self)\(esc)0m" }
    var yellow: String  { "\(esc)33m\(self)\(esc)0m" }
    var blue: String    { "\(esc)34m\(self)\(esc)0m" }
    var cyan: String    { "\(esc)36m\(self)\(esc)0m" }
    
    // Text styles
    var bold: String    { "\(esc)1m\(self)\(esc)0m" }
    
    // Custom RGB (True Color)
    func rgb(r: Int, g: Int, b: Int) -> String {
        return "\(esc)38;2;\(r);\(g);\(b)m\(self)\(esc)0m"
    }
}
