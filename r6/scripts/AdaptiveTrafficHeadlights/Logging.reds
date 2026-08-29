module AdaptiveTrafficHeadlights

import RedLogger.*

public func ATHLog(msg: String) -> Void {
  RedLog.AppendLevel("AdaptiveTrafficHeadlights", "INFO", msg);
}

public func ATHLogWarn(msg: String) -> Void {
  RedLog.AppendLevel("AdaptiveTrafficHeadlights", "WARN", msg);
}
