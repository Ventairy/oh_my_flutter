internal enum IOSDisintegrateError: Error {
  case invalidArguments(String)
  case unavailable(String)
  case outputBusy
}
