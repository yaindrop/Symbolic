import os

let logger = Logger(subsystem: "com.yourdomain.yourappname", category: "yourcategory")

func logInfo(_ message: String) {
    logger.info("\(message)")
}

func logWarning(_ message: String) {
    logger.warning("\(message)")
}

func logError(_ message: String) {
    logger.error("\(message)")
}
