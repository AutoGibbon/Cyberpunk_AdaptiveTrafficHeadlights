module AdaptiveHeadlights

import RedLogger.*

public func ATHLog(msg: String) -> Void {
  RedLog.AppendLevel("AdaptiveHeadlights", "INFO", msg);
}

public func ATHLogWarn(msg: String) -> Void {
  RedLog.AppendLevel("AdaptiveHeadlights", "WARN", msg);
}
