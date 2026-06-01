import CoreGraphics
import Foundation

enum KeyCodeMap {
    static let namedKeys: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, "space": 49, "tab": 48,
        "return": 36, "enter": 36, "escape": 53, "esc": 53, "delete": 51,
        "backspace": 51, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111
    ]

    static let printable: [Character: (keyCode: CGKeyCode, shift: Bool)] = [
        "a": (0, false), "b": (11, false), "c": (8, false), "d": (2, false),
        "e": (14, false), "f": (3, false), "g": (5, false), "h": (4, false),
        "i": (34, false), "j": (38, false), "k": (40, false), "l": (37, false),
        "m": (46, false), "n": (45, false), "o": (31, false), "p": (35, false),
        "q": (12, false), "r": (15, false), "s": (1, false), "t": (17, false),
        "u": (32, false), "v": (9, false), "w": (13, false), "x": (7, false),
        "y": (16, false), "z": (6, false),
        "A": (0, true), "B": (11, true), "C": (8, true), "D": (2, true),
        "E": (14, true), "F": (3, true), "G": (5, true), "H": (4, true),
        "I": (34, true), "J": (38, true), "K": (40, true), "L": (37, true),
        "M": (46, true), "N": (45, true), "O": (31, true), "P": (35, true),
        "Q": (12, true), "R": (15, true), "S": (1, true), "T": (17, true),
        "U": (32, true), "V": (9, true), "W": (13, true), "X": (7, true),
        "Y": (16, true), "Z": (6, true),
        "1": (18, false), "2": (19, false), "3": (20, false), "4": (21, false),
        "5": (23, false), "6": (22, false), "7": (26, false), "8": (28, false),
        "9": (25, false), "0": (29, false), " ": (49, false), "\n": (36, false),
        ".": (47, false), ",": (43, false), "/": (44, false), ";": (41, false),
        "'": (39, false), "[": (33, false), "]": (30, false), "\\": (42, false),
        "-": (27, false), "=": (24, false), "`": (50, false),
        "!": (18, true), "@": (19, true), "#": (20, true), "$": (21, true),
        "%": (23, true), "^": (22, true), "&": (26, true), "*": (28, true),
        "(": (25, true), ")": (29, true), "_": (27, true), "+": (24, true),
        ":": (41, true), "\"": (39, true), "<": (43, true), ">": (47, true),
        "?": (44, true)
    ]
}
