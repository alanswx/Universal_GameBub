import chisel3._
import net.gamebub.framework.Core
import net.gamebub.framework.interface._

/** Lady Bug baseline; board logic is in rtl/universal, platform in rtl/gamebub. */
class Universal extends Module with Core {
  val io = IO(new Bundle {
    val clocks = new ClocksV0(
      clockSystemHz = (1_000_000_000.0 / 50.875).toInt,
      clockDisplayHz = (1_000_000_000.0 / 35).toInt,
      clockSpiHz = 200_000_000)
    val video = new VideoV0(videoWidth = 256, videoHeight = 192,
      colorDepthR = 3, colorDepthG = 3, colorDepthB = 3,
      framePeriod = 312.0 * 262 * 4 / (1_000_000_000.0 / 50.875))
    val videoTransform = new VideoTransformV0()
    val audio = new AudioV0()
    val host = new HostV0()
    val input = new InputV0()
  })
  bindExtModule("universal_gamebub", io, Map())
}
