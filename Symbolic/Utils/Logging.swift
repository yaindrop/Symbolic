import os

let logger = Logger(subsystem: "com.yourdomain.yourappname", category: "yourcategory")

func logInfo(_ message: String) {
    let size = 4096
    if message.count < size {
        logger.info("\(message)")
        return
    }
    let substrings = message.striding(size)
    for i in 0 ..< substrings.count {
        let tag = "(\(i + 1) of \(substrings.count)) "
        logger.info("\(tag)\(substrings[i])")
    }
}

func logWarning(_ message: String) {
    logger.warning("\(message)")
}

func logError(_ message: String) {
    logger.error("\(message)")
}
