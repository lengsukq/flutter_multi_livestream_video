//
//  MethodChannelResponse.swift
//  flutter_aws_chime
//
//  Created by Conan on 2023/9/9.
//

import Foundation

class MethodChannelResponse {
    let result: Bool
    let arguments: Any?
    let code: String?

    init(result res: Bool, arguments args: Any?, code: String? = nil) {
        self.result = res
        self.arguments = args
        self.code = code
    }

    func toFlutterCompatibleType() -> [String: Any] {
        return [
            "success": result,
            "code": result ? NSNull() : (code ?? "native_error"),
            "message": result ? NSNull() : (arguments.map { String(describing: $0) } ?? "Native operation failed."),
            "data": result ? (arguments ?? NSNull()) : NSNull(),
            "details": NSNull()
        ]
    }
}
